.PHONY : clean

SUBDIR = bootloader

all:
	@for i in $(SUBDIR); do\
		$(MAKE) -C $$i MAKEFLAGS=-w; \
	done

run : all
	$(MAKE) run -C bootloader

CLEAN_SUBDIR = bootloader kernel

clean:
	@for i in $(CLEAN_SUBDIR); do\
		$(MAKE) clean -C $$i MAKEFLAGS=-w; \
	done