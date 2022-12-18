GEN_FLASH_BIN_VERSION = 1.0.0
GEN_FLASH_BIN_SITE = $(BR2_EXTERNAL_OOLONG_PATH)/package/gen-flash-bin
GEN_FLASH_BIN_SITE_METHOD = local
GEN_FLASH_BIN_SUPPORTS_IN_SOURCE_BUILD = NO
GEN_FLASH_BIN_INSTALL_STAGING = NO
GEN_FLASH_BIN_INSTALL_TARGET = NO
GEN_FLASH_BIN_INSTALL_IMAGES = YES

GEN_FLASH_BIN_DEPENDENCIES += uboot arm-trusted-firmware firmware-imx optee-os host-imx-mkimage host-dtc

define GEN_FLASH_BIN_BUILD_CMDS
    rm -rf $(@D)/workdir
    cp -r $(HOST_IMX_MKIMAGE_BUILDDIR) $(@D)/workdir
    $(INSTALL) -D -m 0644 $(ARM_TRUSTED_FIRMWARE_BUILDDIR)/build/imx8mm/release/bl31.bin $(@D)/workdir/iMX8M
    $(INSTALL) -D -m 0644 $(OPTEE_OS_BUILDDIR)/out/core/tee-raw.bin $(@D)/workdir/iMX8M/tee.bin
    $(INSTALL) -D -m 0644 $(FIRMWARE_IMX_BUILDDIR)/firmware/ddr/synopsys/lpddr4_pmu_train_*.bin -t $(@D)/workdir/iMX8M
    $(INSTALL) -D -m 0644 $(UBOOT_BUILDDIR)/u-boot-nodtb.bin $(@D)/workdir/iMX8M
    $(INSTALL) -D -m 0644 $(UBOOT_BUILDDIR)/spl/u-boot-spl.bin $(@D)/workdir/iMX8M
    $(INSTALL) -D -m 0644 $(UBOOT_BUILDDIR)/arch/arm/dts/imx8mm-nitrogen8mm_rev2.dtb $(@D)/workdir/iMX8M/evk.dtb
    $(INSTALL) -D -m 0755 $(UBOOT_BUILDDIR)/tools/mkimage $(@D)/workdir/iMX8M/mkimage_uboot
    $(@D)/gen_flash_bin.sh
endef

define GEN_FLASH_BIN_INSTALL_IMAGES_CMDS
    $(INSTALL) -D -m 0644 $(@D)/workdir/iMX8M/flash.bin $(BINARIES_DIR)
endef

$(eval $(generic-package))
