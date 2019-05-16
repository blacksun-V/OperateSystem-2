.PHONY : clean

HEAD_TARGET := head.o
HEAD := head.S
HEAD_TEMP := headbin.s

ENTRY_TARGET := entry.o
ENTRY := entry.S
ENTRY_TEMP := entrybin.s


PRINTK_TARGET := printk.o
PRINTK := printk.c

MAIN := main.c
MAIN_TARGET := main.o

TRAP := trap.c
TRAP_TARGET := trap.o

LIB := lib.h

SYSTEM := system

TARGET := kernel.bin

RM := -rm -rf


all : $(SYSTEM)
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary $(SYSTEM) $(TARGET)

$(SYSTEM):	$(HEAD_TARGET) $(ENTRY_TARGET) $(MAIN_TARGET) $(PRINTK_TARGET) $(TRAP_TARGET)
	ld -b elf64-x86-64 -z muldefs -o $(SYSTEM) $(HEAD_TARGET) $(ENTRY_TARGET) $(MAIN_TARGET) $(PRINTK_TARGET) $(TRAP_TARGET) -T Kernel.lds 

$(HEAD_TARGET): $(HEAD)
	gcc -E $(HEAD) > $(HEAD_TEMP)
	as --64 -o $(HEAD_TARGET) $(HEAD_TEMP)

$(ENTRY_TARGET): $(ENTRY)
	gcc -E  $(ENTRY) > $(ENTRY_TEMP)
	as --64 -o $(ENTRY_TARGET) $(ENTRY_TEMP)

$(MAIN_TARGET): $(MAIN)
	gcc -static  -mcmodel=large -fno-builtin -m64 -c $(MAIN)  -fno-stack-protector

$(PRINTK_TARGET) : $(PRINTK)
	gcc -static  -mcmodel=large -fno-builtin -m64 -c $(PRINTK) -fno-stack-protector

$(TRAP_TARGET) : $(TRAP)
	gcc  -mcmodel=large -fno-builtin -m64 -c $(TRAP)

clean:
	$(RM) *.o $(ENTRY_TEMP) $(HEAD_TEMP) $(TARGET) $(SYSTEM)
