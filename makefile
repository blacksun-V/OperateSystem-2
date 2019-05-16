.PHONY : clean

SUBDIR = bootloader

run : all
	$(MAKE) run -C bootloader

all:
	@for i in $(SUBDIR); do\
		$(MAKE) -C $$i MAKEFLAGS=-w; \
	done


CLEAN_SUBDIR = bootloader kernel

clean:
	@for i in $(CLEAN_SUBDIR); do\
		$(MAKE) clean -C $$i MAKEFLAGS=-w; \
	done