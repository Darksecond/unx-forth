bits 32

section .data
gdtr:
dw .table_end - .table -1
dd .table
.table:
    ;   NULL: {.base=0, .limit=0, .type=0};
    dd 0
    dd 0
    ;   CODE: {.base=0, .limit=0xffff, .type=0x9A};
    dw 0xFFFF
    dw 0
    db 0
    db 0x9A
    db 0xCF
    db 0
    ;   DATA: {.base=0, .limit=0xffff, .type=0x92};
    dw 0xFFFF
    dw 0
    db 0
    db 0x92
    db 0xCF
    db 0
.table_end:

section .text
flush_gdt:
    lgdt [gdtr]
    mov ax, 0x10,
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:.flush
.flush:
    ret

section .text
align 4
extern _main
global _start
_start:
    cli
    call flush_gdt
    jmp _main