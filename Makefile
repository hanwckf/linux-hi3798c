KDIR ?= linux-5.10
KCFG ?= sn1-5.10.config
CROSS_GCC ?= aarch64-linux-gnu-

DTB := hisilicon/hi3798cv200-imou-sn1.dtb
KVER = $(shell make -s kernel_version)

CUR_DIR := $(shell pwd)
STAGE_DIR := $(CUR_DIR)/stage
OUTPUT_DIR := $(CUR_DIR)/output

GIT_VER = $(shell git rev-parse --short=7 HEAD 2>/dev/null)
ifneq ($(GIT_VER),)
LOCALVERSION="-$(GIT_VER)"
endif

MAKE_ARCH = make -C $(KDIR) CROSS_COMPILE=$(CROSS_GCC) ARCH=arm64 LOCALVERSION=$(LOCALVERSION)
J=$(shell nproc)

all: kernel modules
	mkdir -p $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/Image $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/dts/$(DTB) $(OUTPUT_DIR)
	tar --owner=root --group=root -cJf $(OUTPUT_DIR)/modules.tar.xz -C $(STAGE_DIR) lib

$(KDIR)/.config: $(KCFG)
	cp -f $(KCFG) $(KDIR)/.config
	$(MAKE_ARCH) olddefconfig

kernel_version: $(KDIR)/.config
	$(MAKE_ARCH) kernelrelease

kernel: $(KDIR)/.config
	@echo "Kernel source dir: $(KDIR)"
	$(MAKE_ARCH) -j$(J) Image dtbs

modules: $(KDIR)/.config
	rm -rf $(STAGE_DIR)
	$(MAKE_ARCH) -j$(J) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE_DIR) modules_install
	rm -f $(STAGE_DIR)/lib/modules/$(KVER)/build $(STAGE_DIR)/lib/modules/$(KVER)/source

kernel_clean:
	$(MAKE_ARCH) distclean

clean: kernel_clean
	rm -rf $(STAGE_DIR)
	rm -rf $(OUTPUT_DIR)

