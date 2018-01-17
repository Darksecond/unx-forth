: KEY >IN @ SOURCE-ADDR @ + C@ 1 >IN +! ;
: ( IMMEDIATE KEY 41 <> ' 0BRANCH , -16 ;


(
    We now have very basic comment support.
    No support yet for nesting comments.
)

( Basic TRUE/FALSE and NOT )
( Like jonesforth these are not standards compliant )
: TRUE  1 ;
: FALSE 0 ;
: NOT 0= ;

( Various bases )
: HEX 16 BASE ! ;
: BINARY 2 BASE ! ;
: OCTAL 8 BASE ! ;
: DECIMAL 10 BASE ! ;

( Compile immediate word instead of executing directly )
: [COMPILE] IMMEDIATE
    WORD
    FIND
    >CFA
    ,
;

: BEGIN IMMEDIATE
    HERE @
;

: UNTIL IMMEDIATE
    ' 0BRANCH ,
    HERE @ -
    ,
;

: IF IMMEDIATE
    ' 0BRANCH ,
    HERE @
    0 ,
;

: UNLESS IMMEDIATE
    ' NOT ,
    [COMPILE] IF ( Execute IF as part of unless )
;

: THEN IMMEDIATE
    DUP
    HERE @ SWAP -
    SWAP !
;

: ELSE IMMEDIATE
    ' BRANCH ,
    HERE @
    0 ,
    SWAP
    DUP
    HERE @ SWAP -
    SWAP !
;

: WHILE IMMEDIATE
    ' 0BRANCH ,
    HERE @
    0 ,
;

: REPEAT IMMEDIATE
    ' BRANCH ,
    SWAP
    HERE @ - ,
    DUP
    HERE @ SWAP -
    SWAP !
;

: AGAIN IMMEDIATE
    ' BRANCH ,
    HERE @ -
    ,
;

(
    There are used in various ways.

    IF
        ...
    ELSE
        ...
    THEN

    BEGIN
        ...
    0= UNTIL

    BEGIN
        ...
        0<>
    WHILE
        ...
    REPEAT

    BEGIN
        ...
    AGAIN
)

( Grab the first character of the next word )
: CHAR ( -- char )
    WORD DROP C@
;

( Compile the top of the stack as a literal like LIT <cell> )
: LITERAL IMMEDIATE
    ' LIT ,
    ,
;

(
    Define some literals for various characters used later on.
)
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;

(
    Here we build a better comment sytem.
    One which supports nesting, but this needs a bunch of conditional logic and loops.
)
: ( IMMEDIATE
    1
    BEGIN
        KEY
        DUP '(' = IF
            DROP
            1+
        ELSE
            ')' = IF
                1-
            THEN
        THEN
    DUP 0= UNTIL
    DROP
;

(
    That's all the setup we need to get comments with ( and ) working.
    It supports nesting multiple layers deep and it's an immediate word
    so it works in compile context as well
    It also shows IF, ELSE, THEN, BEGIN and UNTIL support.
    Which we implemented to make our lives a lot easier.
)

(
    Create a new constant
    You use it like 'B8000 CONSTANT VGA-BASE'.
    Which creates a word 'VGA-BASE' which puts the number 'B8000' on the stack.
)
: CONSTANT
    WORD     ( read name of constant )
    CREATE   ( create header for new constant)
    DOCOL ,  ( append DOCOL codefield)
    ' LIT ,  ( append LIT word)
    ,        ( append constant itself)
    ' EXIT , ( append exit word)
;

32 CONSTANT BL

(
    Now is a good time to explain word comments, like in ALLOT
    They show the stack before and after running the word.
    stack top is on the right.
    So: ( a b c <- TOP -- c b a <- TOP )
)

(
    Allocate X amount of bytes at HERE.
    It is a good idea to make sure n is aligned
)
: ALLOT ( n -- addr )
    HERE @ SWAP ( HERE n )
    HERE +! ( add n to HERE, leave old HERE on the stack )
;

: CELL ( -- n ) 4 ;
: CELLS ( n -- n ) CELL * ;

(
    A variable creates a word which leaves a pointer 
    to a memory location for said variable on the stack.
)
: VARIABLE
    CELL ALLOT
    WORD CREATE
    DOCOL ,
    ' LIT ,
    ,
    ' EXIT ,
;

( Store single byte at HERE )
: C, ( char -- )
    HERE @ C!
    1 HERE +!
;

: ALIGNED ( addr -- addr )
    3 + 3 INVERT AND
;

: ALIGN ( -- )
    HERE @ ALIGNED HERE !
;

: CELL- ( addr -- addr ) CELL - ;
: CELL+ ( addr -- addr ) CELL + ;

: >DFA ( addr -- addr )
    >CFA
    CELL+
;

(
    This uses HERE @ for temporary string storage in immediate mode.
    We could replace this with PAD or some other data section instead.

    In compiling mode it writes a LISTRING, length, string
    Length is a CELL long (4 bytes)
    LITSTRING then skips the length + string, leaving them on the stack
)
: S" IMMEDIATE ( -- addr len )
    STATE @ IF ( Compiling )
        ' LITSTRING ,
        HERE @ ( Save addr to length word )
        0 , ( Write undefined length )
        BEGIN
            KEY
        DUP '"' <> WHILE
            C, ( Write character )
        REPEAT
        DROP
        DUP
        HERE @ SWAP -
        CELL-
        SWAP !
        ALIGN
    ELSE ( Immediate )
        HERE @
        BEGIN
            KEY
        DUP '"' <> WHILE
            OVER C!
            1+
        REPEAT
        DROP
        HERE @ -
        HERE @
        SWAP
    THEN
;

( Some vga constants )
HEX B8000 CONSTANT VGA-BASE DECIMAL
80 CONSTANT VGA-WIDTH
25 CONSTANT VGA-HEIGHT
VGA-WIDTH VGA-HEIGHT * 2 * CONSTANT VGA-MEMSIZE

: VGA-OFFSET>CORDS ( offset -- row col ) VGA-WIDTH /MOD SWAP ;
: VGA-CORDS>OFFSET ( row col -- offset ) SWAP VGA-WIDTH * + ;
: VGA-OFFSET ( row col  -- offset ) VGA-CORDS>OFFSET 2 * VGA-BASE + ;
: VGA-GLYPH! ( glyph row col -- ) VGA-OFFSET C! ;
: VGA-ATTR! ( attr row col -- ) VGA-OFFSET 1+ C! ;

VARIABLE CURSOR-X 0 CURSOR-X !
VARIABLE CURSOR-Y 0 CURSOR-Y !
VARIABLE CURSOR-ATTR HEX 0F CURSOR-ATTR ! DECIMAL

: CURSOR@ ( -- row col )
    CURSOR-Y @
    CURSOR-X @
;

( At end of line )
: CURSOR-EOL? ( -- bool )
    CURSOR-X @ VGA-WIDTH =
;

( At last line )
: CURSOR-LAST-LINE? ( -- bool )
    CURSOR-Y @ VGA-HEIGHT =
;

: SCROLL-SINGLE-LINE
    1 0 VGA-OFFSET ( Source )
    0 0 VGA-OFFSET ( Destination )
    VGA-MEMSIZE VGA-WIDTH 2 * -
    CMOVE
;

: CLEAR-CHAR ( row col -- )
    0 -ROT VGA-GLYPH!
    2DUP 0 -ROT VGA-ATTR!
;

: CLEAR-LINE ( n -- )
    0
    BEGIN
        2DUP CLEAR-CHAR
        1+
    DUP VGA-WIDTH = UNTIL
    2DROP
;

: SCROLL-IF-REQUIRED
    CURSOR-LAST-LINE? IF
        CURSOR-X 0 !
        VGA-HEIGHT 1- CURSOR-Y !
        SCROLL-SINGLE-LINE
        VGA-HEIGHT 1- CLEAR-LINE
    THEN
;

: CR ( -- )
    0 CURSOR-X !
    1 CURSOR-Y +!
    SCROLL-IF-REQUIRED
;

( TODO Support '\n' )
: EMIT ( char -- )
    CURSOR@ VGA-GLYPH!
    CURSOR-ATTR @ CURSOR@ VGA-ATTR! ( Replace with proper variable )
    1 CURSOR-X +!
    CURSOR-EOL? IF CR THEN
;

: SPACE ( -- ) BL EMIT ;
: SPACES ( n -- )
    BEGIN
        SPACE
        1-
    ?DUP 0= UNTIL
;

: TYPE ( addr len -- )
    BEGIN
        SWAP DUP @ EMIT
        1+
        SWAP 1-
        ?DUP 0= UNTIL
    DROP
;

: ." IMMEDIATE ( -- )
    STATE @ IF ( Compiling )
            [COMPILE] S"
            ' TYPE ,
    ELSE ( Immediate )
        BEGIN
            KEY
            DUP '"' = IF
                DROP EXIT
            THEN
            EMIT
        AGAIN
    THEN
;

: PRINT_OK
    ." OK"
;

PRINT_OK
CR S" TEST" TYPE
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." H..."
CR ." Loading..."
CR ." Loading..."
CR ." Loading..."
CR ." H"
CR 12 SPACES ." TEST"

BYE
