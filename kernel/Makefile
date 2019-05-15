.PHONY : clean

HEAD_TARGET := head.o
HEAD := head.S
HEAD_TEMP := headbin.s

PRINTK_TARGET := printk.o
PRINTK := printk.c

MAIN := main.c
MAIN_TARGET := main.o

LIB := lib.h

SYSTEM := system

TARGET := kernel.bin

RM := -rm -rf


all : $(SYSTEM)
	objcopy -I elf64-x86-64 -S -R ".eh_frame" -R ".comment" -O binary $(SYSTEM) $(TARGET)

$(HEAD_TARGET): $(HEAD)
	gcc -E $(HEAD) > $(HEAD_TEMP)
	as --64 -o $(HEAD_TARGET) $(HEAD_TEMP)

$(SYSTEM):	$(HEAD_TARGET) $(MAIN_TARGET) $(PRINTK_TARGET)
	ld -b elf64-x86-64 -z muldefs -o $(SYSTEM) $(HEAD_TARGET) $(MAIN_TARGET) $(PRINTK_TARGET) -T Kernel.lds 

$(MAIN_TARGET): $(MAIN) $(LIB)
	gcc -static  -mcmodel=large -fno-builtin -m64 -c $(MAIN)  -fno-stack-protector

$(PRINTK_TARGET) : $(PRINTK) $(LIB)
	gcc -static  -mcmodel=large -fno-builtin -m64 -c $(PRINTK) -fno-stack-protector

clean:
	$(RM) $(HEAD_TARGET) $(HEAD_TEMP) $(MAIN_TARGET) $(SYSTEM) $(TARGET)
