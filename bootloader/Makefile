.PHONY : clean

BOOT := boot.asm
BOOT_TARGET := boot.bin
DIS_BOOT := disboot.asm

BOOT_IMG := boot.img

LOADER := loader.asm
LOADER_TARGET := loader.bin

RM := -rm -rf

all : $(BOOT_TARGET) $(LOADER_TARGET) $(BOOT_IMG) mount_file
	@dd if=$(BOOT_TARGET) of=$(BOOT_IMG) bs=512 count=1 conv=notrunc

mount_file: $(BOOT_IMG)
	@echo "复制文件至内核"; \
	message=`hdiutil mount boot.img`; \
	drive=`echo $${message} | cut -d ' ' -f 1`; \
	volume=`echo $${message} | cut -d ' ' -f 2,3 | sed 's/ /\\\\ /g' `; \
	eval "install $(LOADER_TARGET) $${volume}/"; \
	eval "install $(LOADER_TARGET) $${volume}/kernel.bin"; \
	hdiutil eject $${drive}; 
	@echo "复制完毕"

run : all
	@bochs -f 'bochsrc'

$(BOOT_IMG) :
	@bximage -mode=create -q -fd=1.44M $@
    
$(BOOT_TARGET) : $(BOOT)
	nasm $^ -o $@

$(LOADER_TARGET) : $(LOADER)
	nasm $^ -o $@

clean :
	$(RM) $(BOOT_IMG) $(BOOT_TARGET) $(DIS_BOOT) $(LOADER_TARGET)
