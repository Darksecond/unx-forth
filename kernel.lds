OUTPUT_ARCH(i386)
OUTPUT_FORMAT("elf32-i386")
ENTRY(_start)
SECTIONS
{
    . = 0x00100000;

    .text BLOCK(4K) : ALIGN(4K)
	{
		*(.multiboot)
		*(.text)
	}

    .rodata BLOCK(4K) : ALIGN(4K)
	{
		*(.rodata)
	}

    .data BLOCK(4K) : ALIGN(4K)
	{
		*(.data)
	}

    .bss BLOCK(4K) : ALIGN(4K)
	{
		*(COMMON)
		*(.bss)
	}

	end = .; _end = .; __end = .;
}
