PROJ_NAME=oolong

all: $(PROJ_NAME)

# Set by the caller to the Code Signing Tool crts/ subdirectory if image
# signing is needed for the target board. If not set, the resulting
# images are unsigned.
CST_CRTS_DIR ?= ""

BASE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
BUILDROOT_VERSION = $(shell cat $(BASE_DIR)/buildroot-version.txt)
BUILDROOT_DIR = $(BASE_DIR)/buildroot-$(BUILDROOT_VERSION)
BUILDROOT_PATCHED_STAMP = $(BUILDROOT_DIR)/.patched
BUILD_DIR = $(BASE_DIR)/$(PROJ_NAME)-build
BR_EXTERNAL_DIR = $(BASE_DIR)/$(PROJ_NAME)-br-external

.PHONY: bootstrap
bootstrap:
	cd $(BASE_DIR) && ./bootstrap.sh

$(BUILDROOT_PATCHED_STAMP): buildroot-patches/$(BUILDROOT_VERSION)/*.patch
	cd $(BUILDROOT_DIR) $(foreach file, $(wildcard buildroot-patches/$(BUILDROOT_VERSION)/*.patch), && patch -p1 < ../$(file) )
	@touch $(BUILDROOT_PATCHED_STAMP)

.PHONY: $(PROJ_NAME)
$(PROJ_NAME): bootstrap $(BUILDROOT_PATCHED_STAMP)
	make BR2_EXTERNAL=$(BR_EXTERNAL_DIR) -C $(BUILDROOT_DIR) O=$(BUILD_DIR) $(PROJ_NAME)_nitrogen8mm_rev2_defconfig
	cd $(BUILD_DIR) && make CST_CRTS_DIR=$(CST_CRTS_DIR)

clean:
	rm -rf $(BUILD_DIR)
