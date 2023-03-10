kernel := build/kernel.bin
kernel_stripped := build/kernel_stripped.bin
iso := build/os.iso

CC := gcc
CC += -Wall -Wextra -Werror -march=x86-64
CC += -fno-strict-aliasing  # prevent ub!
CC += -mno-red-zone
CC += -U_FORTIFY_SOURCE

CXX := g++
CXX += -std=c++14
CXX += -Wall -Wextra -Werror -march=x86-64
CXX += -fno-strict-aliasing  # prevent ub!
CXX += -mno-red-zone
CXX += -U_FORTIFY_SOURCE
CXX += -I .
CXX += -I ducknet/inc/

linker_script := boot/linker.ld
grub_cfg := boot/grub.cfg
assembly_source_files := $(wildcard boot/*.asm)
assembly_object_files := $(patsubst boot/%.asm, \
		build/boot/%.o, $(assembly_source_files))

kern_asm_source_files := $(wildcard kern/*.S)
kern_asm_object_files := $(patsubst kern/%.S, \
		build/kern/%.o, $(kern_asm_source_files))

header_files := $(wildcard inc/*.h) $(wildcard inc/*.hpp) $(wildcard ducknet/inc/*.h)
LIB_PREFIX := ../duck-binaries/duck64/lib/
LIBC_PREFIX := $(LIB_PREFIX)musl/
libstdcxx_files := $(LIB_PREFIX)libstdc++.a
libc_files := -L $(LIBC_PREFIX) -L $(LIB_PREFIX) -lc -lgcc -lgcc_eh -lc
libc_crt_start := $(LIBC_PREFIX)crt1.o $(LIBC_PREFIX)crti.o
libc_crt_end := $(LIBC_PREFIX)crtn.o

i386_LIB_PREFIX := ../duck-binaries/duck32/lib/
i386_LIBC_PREFIX := $(i386_LIB_PREFIX)musl/
i386_libstdcxx_files := $(i386_LIB_PREFIX)libstdc++.a
i386_libc_files := -L $(i386_LIBC_PREFIX) -L $(i386_LIB_PREFIX) -lc -lgcc -lgcc_eh -lc
i386_libc_crt_start := $(i386_LIBC_PREFIX)crt1.o $(i386_LIBC_PREFIX)crti.o
i386_libc_crt_end := $(i386_LIBC_PREFIX)crtn.o

LWIPDIR := thirdparty/lwip-2.1.3/src
include $(LWIPDIR)/Filelists.mk
lwip_include := -I $(LWIPDIR)/include -I lwip_config/
lwip_source_files := $(COREFILES) $(CORE4FILES)
lwip_source_files += $(LWIPDIR)/netif/ethernet.c
lwip_object_files := $(patsubst $(LWIPDIR)/%.c, build/lwip/%.o, $(lwip_source_files))

all: $(kernel) $(kernel_stripped)

include kern/Makefile
include lib/Makefile
include user_lib/Makefile
include user/Makefile
include user32/Makefile
include user_lib32/Makefile
include ducknet/lib/Makefile


LWIP_CC := $(CC) -O2 $(lwip_include)

build/lwip/%.o: $(LWIPDIR)/%.c
	@echo + cc $@
	@mkdir -p $(shell dirname $@)
	@$(LWIP_CC) -c $< -o $@

build/lwip/lwip.a: $(lwip_object_files)
	@echo + ar $@
	@mkdir -p $(shell dirname $@)
	@ar r $@ $(lwip_object_files)

lwip_lib := build/lwip/lwip.a


.PHONY: all clean run iso

clean:
	@rm -r build/*

DEFAULT_QEMUOPTS := -m 4096M -serial mon:stdio -no-reboot
# DEFAULT_QEMUOPTS += -netdev type=tap,script=./ifup.sh,id=net0
DEFAULT_QEMUOPTS += -netdev type=user,id=net0
DEFAULT_QEMUOPTS += -device virtio-net-pci,netdev=net0
# DEFAULT_QEMUOPTS += -device e1000,netdev=net0

QEMUOPTS ?= $(DEFAULT_QEMUOPTS)

run: $(iso)
	@qemu-system-x86_64 -cdrom $(iso) -cpu Skylake-Client $(QEMUOPTS)

run-nox: $(iso)
	@qemu-system-x86_64 -nographic -cdrom $(iso) -cpu Skylake-Client $(QEMUOPTS)

run-lowlatency: $(iso)
	@qemu-system-x86_64 -nographic -cdrom $(iso) -cpu Skylake-Server-v3 $(QEMUOPTS)

asm: $(kernel)
	@objdump -d $(kernel) | c++filt | less

asm_no_filter: $(kernel)
	@objdump -d $(kernel) | less

iso: $(iso)

$(iso): $(kernel) $(grub_cfg)
	@mkdir -p build/isofiles/boot/grub
	@cp $(kernel) build/isofiles/boot/kernel.bin
	@cp $(grub_cfg) build/isofiles/boot/grub
	@grub-mkrescue -o $(iso) build/isofiles -d /usr/lib/grub/i386-pc 2> /dev/null
	@rm -r build/isofiles

$(kernel): $(assembly_object_files) $(kern_object_files) $(lib_object_files) $(linker_script) \
	$(lwip_lib) \
	$(libc_duck64) $(kern_asm_object_files) $(libducknet) $(user_obj_files) $(user32_obj_files) $(libducknet)
	@echo + ld $(kernel)
	@ld -n -T $(linker_script) -o $(kernel) \
		$(libc_crt_start) $(assembly_object_files) $(kern_asm_object_files) \
		--start-group \
		$(kern_object_files) $(lib_object_files) \
		$(lwip_lib) \
		$(libducknet) $(libstdcxx_files) $(libc_files) \
		--end-group \
		$(libc_crt_end) \
		$(user_obj_files) $(user32_obj_files)

$(kernel_stripped): $(kernel)
	@echo + strip $(kernel_stripped)
	@cp $(kernel) $(kernel_stripped)
	@strip --strip-all $(kernel_stripped)

build/boot/%.o: boot/%.asm
	@echo + nasm $@
	@mkdir -p $(shell dirname $@)
	@nasm -felf64 $< -o $@

build/kern/%.o: kern/%.S
	@echo + as $@
	@mkdir -p $(shell dirname $@)
	@$(CXX) -c $< -o $@
