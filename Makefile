KDIR ?= linux-hi3798c
KCFG ?= sn1.config
CROSS_GCC ?= aarch64-linux-gnu-

DTB := hisilicon/hi3798cv200-imou-sn1.dtb
KVER = $(shell make -s kernel_version)

CUR_DIR := $(shell pwd)
STAGE_DIR := $(CUR_DIR)/stage
OUTPUT_DIR := $(CUR_DIR)/output

MAKE_ARCH := make -C $(KDIR) CROSS_COMPILE=$(CROSS_GCC) ARCH=arm64
J=$(shell grep ^processor /proc/cpuinfo | wc -l)

all: kernel modules
	mkdir -p $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/Image $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/dts/$(DTB) $(OUTPUT_DIR)
	tar --owner=root --group=root -cJf $(OUTPUT_DIR)/modules.tar.xz -C $(STAGE_DIR) lib

kernel-config:
	cp -f $(KCFG) $(KDIR)/.config
	$(MAKE_ARCH) olddefconfig

kernel_version: kernel-config
	$(MAKE_ARCH) kernelrelease

kernel: kernel-config
	@echo "Kernel source dir: $(KDIR)"
	$(MAKE_ARCH) -j$(J) Image dtbs

modules: kernel-config
	rm -rf $(STAGE_DIR)
	$(MAKE_ARCH) -j$(J) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE_DIR) modules_install
	rm -f $(STAGE_DIR)/lib/modules/$(KVER)/build $(STAGE_DIR)/lib/modules/$(KVER)/source

kernel_clean:
	$(MAKE_ARCH) distclean

clean: kernel_clean
	rm -rf $(STAGE_DIR)
	rm -rf $(OUTPUT_DIR)

