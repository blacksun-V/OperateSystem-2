.PHONY : clean

SUBDIR = bootloader

run : all
	$(MAKE) run -C bootloader

all:
	@for i in $(SUBDIR); do\
		$(MAKE) -C $$i MAKEFLAGS=-w; \
	done

clean:
	@for i in $(SUBDIR); do\
		$(MAKE) clean -C $$i MAKEFLAGS=-w; \
	done