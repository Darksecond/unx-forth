
: HEX 16 BASE ! ;
: DECIMAL 10 BASE ! ;

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

: CHAR WORD DROP C@ ;

: LITERAL IMMEDIATE
    ' LIT ,
    ,
;

: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;

: >IN++@
    >IN @
    DUP 1+ >IN !
;

: KEY
    >IN++@ SOURCE-ADDR @ +
    C@
;

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

(
    Start of VGA stuff, including EMIT
)
HEX ( Switch into immediate mode because numbers are compiled right now, not later )

B8000 CONSTANT VGA-BASE

( TODO Rewrite this to row + column )
VARIABLE VGA>IN 0 VGA>IN !

: VGA>CURRENT++
    VGA>IN @
    1 VGA>IN +!
    VGA-BASE +
;

: EMIT ( n -- )
    VGA>CURRENT++ C!
    2F VGA>CURRENT++ C!
;

( TODO TYPE )
( TODO CR )

DECIMAL
(
    End of VGA stuff
)

: PRINT_OK
    [ CHAR O ] LITERAL EMIT
    [ CHAR K ] LITERAL EMIT
;

CR
PRINT_OK
CR
PRINT_OK

BYE
