.PHONY : clean

SRC := boot.asm
OUT := boot.bin
IMG := boot.img
DSRC := disboot.asm
LOADER := loader.asm
LOADER_TRAGET := loader.bin

RM := rm -rf

rebuild :
	@$(MAKE) clean
	@$(MAKE) all
	@$(MAKE) run

all : $(OUT) $(LOADER_TRAGET) $(IMG)
	dd if=$(OUT) of=$(IMG) bs=512 count=1 conv=notrunc
	@echo "Success!"
	@${MAKE} mount

mount : $(IMG)
	@echo "复制文件至磁盘"; \
	message=`hdiutil mount boot.img`; \
	drive=`echo $${message} | cut -d ' ' -f 1`; \
	volume=`echo $${message} | cut -d ' ' -f 2,3 | sed 's/ /\\\\ /g' `; \
	eval "install $(LOADER_TRAGET) $${volume}/"; \
	eval "install $(LOADER_TRAGET) $${volume}/kernel.bin"; \
	hdiutil eject $${drive}; \
	echo "Copy Finish"

run : all
	bochs -f 'bochsrc'

$(IMG) :
	bximage -mode=create -q -fd=1.44M $@
    
$(OUT) : $(SRC)
	nasm $^ -o $@
	ndisasm -o 0x7c00 $(OUT) >> $(DSRC)

$(LOADER_TRAGET) : $(LOADER)
	nasm $^ -o $@

clean :
	$(RM) $(IMG) $(OUT) $(DSRC) $(LOADER_TRAGET)

