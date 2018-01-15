bits 32

; NEXT macro
%macro NEXT 0
lodsd
jmp [eax]
%endmacro

%macro PUSHRSP 1
lea ebp, [ebp-4]
mov [ebp], %1
%endmacro

%macro POPRSP 1
mov %1, [ebp]
lea ebp, [ebp+4]
%endmacro

%define F_IMMED 0x80
%define F_HIDDEN 0x20
%define F_LENMASK 0x1F

; Addr of last word defined
%define link 0

; defhead name, label, flags, codeword
%macro defhead 4
section .rodata
align 4
%2:
; Local label called %%link, which has the value of 'link'.
%%link dd link
; Redefine 'link' to point to local %%link
%define link %%link
; Put the length of the name into %%count
%strlen %%count %1
; write out length byte, add in any flags.
db %3 + %%count
db %1
align 4
.cfa:
dd %4
%endmacro

%macro defcode 2-3 0
; Call head, %3 will be 0 if not supplied. $+2 is the next statement, meaning it's the start of the actual code.
defhead %1, %2, %3,.code

section .text
align 4
.code:
%endmacro

%macro defvar 2-3 0
defhead %1, %2, 0, .code

section .text
align 4
.code:
push var_%2
NEXT

section .data
align 4
var_%2: dd %3
%endmacro

%macro defconst 3
defhead %1, %2, 0, .code
section .text
align 4
.code:
push %3
NEXT
%endmacro

%macro defword 2-3 0
defhead %1, %2, %3,DOCOL
%endmacro

%macro deffile 2
section .rodata
align 4
file_%2:
incbin %1
.end:

defcode '@%1', %2
    push file_%2
    push file_%2.end - file_%2
    NEXT
%endmacro

deffile 'core.fbin', CORE_FBIN

section .bss
align 16
stack:
    .bottom:
    resb 16384 ; 16 KiB
    .top:
rstack:
    .bottom:
    resb 16384 ; 16 KiB
    .top:

section .text
align 4

DOCOL:
    PUSHRSP esi
    add eax, 4
    mov esi, eax
    NEXT

global _main
_main:
    cld
    mov esp, stack.top
    mov ebp, rstack.top

    mov esi, .COLD_START
    NEXT
.COLD_START:
    dd CORE_FBIN.cfa
    dd SOURCE_LEN.cfa
    dd STORE.cfa
    dd SOURCE_ADDR.cfa
    dd STORE.cfa

    dd WRD.cfa
    dd INTERPRET.cfa
    dd BRANCH.cfa, -12

    dd BYE.cfa


; Drop first stack entry
defcode 'DROP', DROP
    pop eax
    NEXT

; Swap the first and second stack entries
defcode 'SWAP', SWAP
    pop eax
    pop ebx
    push eax
    push ebx
    NEXT

; Duplicate top stack entry
defcode 'DUP', DUP
    mov eax, [esp]
    push eax
    NEXT

; Duplicate second stack entry
defcode 'OVER', OVER
    mov eax, [esp+4]
    push eax
    NEXT

; Rotate stack entries (1,2,3->3,1,2->2,3,1)
defcode 'ROT', ROT
    pop eax
    pop ebx
    pop ecx
    push ebx
    push eax
    push ecx
    NEXT

; Reserve rotate stack entries (1,2,3->2,3,1)
defcode '-ROT', NROT
    pop eax
    pop ebx
    pop ecx
    push eax
    push ecx
    push ebx
    NEXT

; Drop top 2 items
defcode '2DROP', TWODROP
    pop eax
    pop ebx
    NEXT

; 2DUP (a b -- a b a b)
defcode '2DUP', TWODUP
    mov eax, [esp]
    mov ebx, [esp+4]
    push ebx
    push eax
    NEXT

; 2WAP (a b c d -- b a d c)
defcode '2SWAP', TWOSWAP
    pop eax
    pop ebx
    pop ecx
    pop edx
    push ebx
    push eax
    push edx
    push ecx
    NEXT

; Duplicate top entry if not null
defcode '?DUP', QDUP
    mov eax, [esp]
    test eax, eax
    jz .next
    push eax
    .next: NEXT

defcode '1+', INCR
    inc dword [esp]
    NEXT

defcode '1-', DECR
    dec dword [esp]
    NEXT

defcode '4+', INCR4
    add dword [esp], 4
    NEXT

defcode '4-', DECR4
    sub dword [esp], 4
    NEXT

defcode '+', ADD
    pop eax
    add [esp], eax
    NEXT

defcode '-', SUB
    pop eax
    sub [esp], eax
    NEXT

defcode '*', MUL
    pop eax
    pop ebx
    imul eax, ebx
    push eax
    NEXT

; /MOD (a b -- c d)
; divide a by b
; c is remainder and d is quotient
defcode '/MOD', DIVMOD
    xor edx, edx
    pop ebx
    pop eax
    idiv ebx
    push edx ;remainder
    push eax ;quotient
    NEXT

defcode '=', EQU
    pop eax
    pop ebx
    cmp eax, ebx
    sete al
    movzx eax, al
    push eax
    NEXT

defcode '<>', NEQU
    pop eax
    pop ebx
    cmp eax, ebx
    setne al
    movzx eax, al
    push eax
    NEXT

defcode '<', LT
    pop eax
    pop ebx
    cmp eax, ebx
    setl al
    movzx eax, al
    push eax
    NEXT

defcode '>', GT
    pop eax
    pop ebx
    cmp eax, ebx
    setg al
    movzx eax, al
    push eax
    NEXT

defcode '<=', LTE
    pop eax
    pop ebx
    cmp eax, ebx
    setle al
    movzx eax, al
    push eax
    NEXT

defcode '>=', GTE
    pop eax
    pop ebx
    cmp eax, ebx
    setge al
    movzx eax, al
    push eax
    NEXT

; top of stack == 0
defcode '0=', ZEQU
    pop eax
    test eax, eax
    setz al
    movzx eax, al
    push eax
    NEXT

; top of stack != 0
defcode '0<>', ZNEQU
    pop eax
    test eax, eax
    setnz al
    movzx eax, al
    push eax
    NEXT

; top of stack < 0
defcode '0<', ZLT
    pop eax
    test eax, eax
    setl al
    movzx eax, al
    push eax
    NEXT

; top of stack > 0
defcode '0>', ZGT
    pop eax
    test eax, eax
    setg al
    movzx eax, al
    push eax
    NEXT

; top of stack <= 0
defcode '0<=', ZLTE
    pop eax
    test eax, eax
    setle al
    movzx eax, al
    push eax
    NEXT

; top of stack >= 0
defcode '0>=', ZGTE
    pop eax
    test eax, eax
    setge al
    movzx eax, al
    push eax
    NEXT

defcode 'AND', AND
    pop eax
    and [esp], eax
    NEXT

defcode 'OR', OR
    pop eax
    or [esp], eax
    NEXT

defcode 'XOR', XOR
    pop eax
    xor [esp], eax
    NEXT

;BITWISE NOT
defcode 'INVERT', INVERT
    not dword [esp]
    NEXT

defcode 'EXIT', EXIT
    POPRSP esi
    NEXT

defcode 'LIT', LIT
    lodsd
    push eax
    NEXT

; ! ( x a-addr -- ) 
defcode '!', STORE
    pop ebx
    pop eax
    mov [ebx], eax
    NEXT

; @ ( a-addr -- x ) 
defcode '@', FETCH
    pop ebx
    mov eax, [ebx]
    push eax
    NEXT

defcode '+!', ADDSTORE
    pop ebx
    pop eax
    add [ebx], eax
    NEXT

defcode '-!', SUBSTORE
    pop ebx
    pop eax
    sub [ebx], eax
    NEXT

defcode 'C!', STOREBYTE
    pop ebx
    pop eax
    mov [ebx], al
    NEXT

defcode 'C@', FETCHBYTE
    pop ebx
    xor eax, eax
    mov al, [ebx]
    push eax
    NEXT

;TODO C@C!
;TODO CMOVE

defvar 'STATE', STATE
extern __end
defvar 'HERE', HERE, __end
defvar 'LATEST', LATEST, BYE
defvar 'BASE', BASE, 10
defvar '>IN', TIN
defvar 'SOURCE-ADDR', SOURCE_ADDR
defvar 'SOURCE-LEN', SOURCE_LEN

defconst 'R0', RZ, rstack.top
defconst 'DOCOL', __DOCOL, DOCOL

;TODO >R
;TODO R>
;TODO RSP@

defcode 'RSP!', RSPSTORE
    pop ebp
    NEXT

;TODO RDROP

;TODO DSP@
;TODO DSP!

;TODO KEY
;TODO EMIT

;TODO Implement .data EOF
;TODO Read 'space' from stack instead of hardcoding 32
;TODO Skip '\n' as well
defcode 'WORD', WRD
    push esi
    mov esi, [var_SOURCE_ADDR]
    mov edx, [var_SOURCE_LEN]
    add edx, esi ; edx now contains the last addr possible
    add esi, [var_TIN]
    mov edi, .data
    xor ebx, ebx ; word length
.begin:
    cmp esi, edx
    je .end
    inc dword [var_TIN]
    lodsb
    cmp al, 32 ;space
    je .begin
.loop:
    stosb
    inc ebx
    
    cmp esi, edx
    je .end
    inc dword [var_TIN]
    lodsb
    cmp al, 32 ;space
    je .end
    jmp .loop
.end:
    pop esi
    push .data
    push ebx
    NEXT
section .bss
align 4
.data:
resb 80

defcode 'NUMBER', NUMBER
    pop ecx ; Length
    pop edi ; start of addr
    xor eax, eax
    xor ebx, ebx
    test ecx, ecx
    jz .done ; Skip empty strings
    mov edx, [var_BASE]
    mov bl, [edi] ; First character
    inc edi
    push eax ; push 0 on the stack
    cmp bl, '-'
    jnz .convert
    pop eax
    push ebx ; push not 0 on the stack
    dec ecx
    jnz .loop
    pop ebx ; string only has -, error state
    mov ecx, 1
    jmp .done
.loop:
    imul eax, edx ; number *= base
    mov bl, [edi] ; read next character
    inc edi
.convert:
    sub bl, '0' ; >= '0'
    jb .finalize ; below 0
    cmp bl, 10 ; <= '9'
    jb .correct
    sub bl, 17
    jb .finalize
    add bl, 10
.correct:
    cmp bl, dl
    jge .finalize ; >= base
    add eax, ebx
    dec ecx
    jnz .loop
.finalize:
    pop ebx
    test ebx, ebx
    jz .done
    neg eax
.done:
    push eax ; parsed number
    push ecx ; number of unparsed characters
    NEXT

defcode 'FIND', FIND
    pop ecx ; length
    pop edi ; address

    push esi
    mov edx, [var_LATEST]
.begin:
    test edx, edx
    jz .not_found

    ; compare length
    xor eax, eax
    mov al, [edx+4]
    and al, (F_HIDDEN|F_LENMASK)
    cmp al, cl ; Compare length, if hidden the length won't match
    jne .next

    ; compare string
    push ecx
    push edi
    lea esi, [edx+5]
    repe cmpsb ;compare strings
    pop edi
    pop ecx
    jne .next

    mov eax, edx
    jmp .end
.next:
    mov edx, [edx]
    jmp .begin
.not_found:
    xor eax, eax
.end:
    pop esi
    push eax ; address of entry or NULL
    NEXT

defcode '>CFA', TCFA
    pop edi
    xor eax, eax
    add edi, 4 ; Skip link cell
    mov al, [edi]
    inc edi ; Skip length field
    and al, F_LENMASK ; Remove flags
    add edi, eax ; skip name
    ; align 4 byte boundary
    add edi, 3
    and edi, ~3
    push edi
    NEXT

defword '>DFA', TDFA
    dd TCFA.cfa
    dd INCR4.cfa
    dd EXIT.cfa

defcode 'CREATE', CREATE
    pop ecx ; length
    pop ebx ; addr of name
    ; Link pointer
    mov edi, [var_HERE]
    mov eax, [var_LATEST]
    stosd
    ; Length and name
    mov al, cl
    stosb
    push esi
    mov esi, ebx
    rep movsb
    pop esi
    ; Align to 4 byte boundary
    add edi, 3
    and edi, ~3
    ; Update LATEST and HERE
    mov eax, [var_HERE]
    mov [var_LATEST], eax
    mov [var_HERE], edi
    NEXT

;TODO Double check this at runtime
; the [] might be wrong?
defcode ',', COMMA
    pop eax
    mov edi, [var_HERE]
    stosd
    mov [var_HERE], edi
    NEXT

defword '[', LBRAC, F_IMMED
    dd LIT.cfa, 0
    dd STATE.cfa
    dd STORE.cfa
    dd EXIT.cfa

defword ']', RBRAC
    dd LIT.cfa, 1
    dd STATE.cfa
    dd STORE.cfa
    dd EXIT.cfa

defword ':', COLON
    dd WRD.cfa ; Get name of new word
    dd CREATE.cfa ; Create header
    dd LIT.cfa, DOCOL, COMMA.cfa ; Append DOCOL
    dd LATEST.cfa, FETCH.cfa, HIDDEN.cfa ; Hide entry from itself
    dd RBRAC.cfa ; Compile mode
    dd EXIT.cfa ; Return

defword ';', SEMICOLON, F_IMMED
    dd LIT.cfa, EXIT.cfa, COMMA.cfa ; Append EXIT to word
    dd LATEST.cfa, FETCH.cfa, HIDDEN.cfa ; Unhide entry
    dd LBRAC.cfa ; Immediate mode
    dd EXIT.cfa ; Return

defcode 'IMMEDIATE', IMMEDIATE, F_IMMED
		mov edi, [var_LATEST]
		add edi, 4
    xor byte [edi], F_IMMED
    NEXT

defcode 'HIDDEN', HIDDEN
    pop edi
		add edi, 4
    xor byte [edi], F_HIDDEN
    NEXT

;TODO HIDE

defcode "'", TICK
    lodsd
    push eax
    NEXT

;TODO LITSTRING
;TODO TELL
;TODO QUIT

defcode '?IMMEDIATE', QIMMEDIATE
    pop edi
    xor eax, eax
    mov al, [edi+4]
    and al, F_IMMED
    jnz .notzero
    push 0
    jmp .done
.notzero:
    push 1
.done:
    NEXT

defword 'INTERPRET', INTERPRET
    dd TWODUP.cfa
    dd FIND.cfa
    dd QDUP.cfa, ZBRANCH.cfa, 80 ; Skip to number parsing ...
    dd ROT.cfa, ROT.cfa, TWODROP.cfa
    dd DUP.cfa, QIMMEDIATE.cfa, ZBRANCH.cfa, 16 ; If in immediate mode execute directly
    dd TCFA.cfa
    dd EXECUTE.cfa
    dd EXIT.cfa

    ;No immediate mode flag
    dd TCFA.cfa
    dd STATE.cfa, FETCH.cfa, ZBRANCH.cfa, 12
    ; Compile mode
    dd COMMA.cfa
    dd EXIT.cfa
    ; Immediate mode
    dd EXECUTE.cfa
    dd EXIT.cfa

    ; It's a number
    dd NUMBER.cfa
    dd ZBRANCH.cfa, 12 ; Skip over non numbers for now
    dd DROP.cfa, EXIT.cfa
    dd STATE.cfa, FETCH.cfa, ZBRANCH.cfa, 20
    ; Compile mode
    ; Something seems to be wrong here...
    ; But everything so far seems OK
    dd LIT.cfa, LIT.cfa, COMMA.cfa ; Push LIT
    dd COMMA.cfa ; Push number
    ; Immediate mode
    dd EXIT.cfa

;TODO CHAR

defcode 'EXECUTE', EXECUTE
    pop eax
    jmp [eax]
    NEXT

defcode 'BRANCH', BRANCH
    add esi, [esi]
    NEXT

defcode '0BRANCH', ZBRANCH
    pop eax
    test eax, eax
    jz BRANCH.code ; Perform BRANCH
    lodsd ; Skip the offset cell
    NEXT

; Prints ok
; TEMP
defword 'PRINT_OK', PRINT_OK
    dd LIT.cfa, 0x2f4b2f4f ; 'OK' with added color bytes
    dd LIT.cfa, 0xb8000 ; First 2 characters
    dd STORE.cfa
    dd EXIT.cfa
defword 'PRINT_OP', PRINT_OP
    dd LIT.cfa, 0x2f4b2f50 ; 'OP' with added color bytes
    dd LIT.cfa, 0xb8000 ; First 2 characters
    dd STORE.cfa
    dd EXIT.cfa

; Runs the 'hlt' instruction
defcode 'HALT', HALT
    hlt
    NEXT

; MUST BE LAST
; Doesn't need an EXIT because it will never get there
defword 'BYE', BYE
    dd HALT.cfa
    dd BRANCH.cfa, -8
