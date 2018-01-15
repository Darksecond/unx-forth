LD?=ld

.PHONY: clean all

all: kernel.elf

core.fbin: core.f
	tr '[:cntrl:]' ' ' < core.f > core.fbin
forth.o: forth.S core.fbin
	nasm -felf32 -o forth.o forth.S
multiboot.o: multiboot.S
	nasm -felf32 -o multiboot.o multiboot.S
boot.o: boot.S
	nasm -felf32 -o boot.o boot.S

kernel.elf: boot.o multiboot.o forth.o kernel.lds
	$(LD) -n -T kernel.lds -o kernel.elf boot.o multiboot.o forth.o

clean:
	rm -f *.o kernel.elf *.fbin

run: kernel.elf
	qemu-system-i386 -kernel kernel.elf -curses
run2: kernel.elf
	qemu-system-i386 -kernel kernel.elf
