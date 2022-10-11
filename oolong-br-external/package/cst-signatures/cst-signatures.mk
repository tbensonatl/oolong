CST_SIGNATURES_VERSION = 3.3.1
CST_SIGNATURES_SOURCE = cst-$(CST_SIGNATURES_VERSION).tgz
CST_SIGNATURES_SITE = $(BR2_EXTERNAL_OOLONG_PATH)/package/cst-signatures
CST_SIGNATURES_SITE_METHOD = file
CST_SIGNATURES_SUPPORTS_IN_SOURCE_BUILD = NO
CST_SIGNATURES_INSTALL_STAGING = NO
CST_SIGNATURES_INSTALL_TARGET = NO
CST_SIGNATURES_INSTALL_IMAGES = YES

CST_SIGNATURES_DEPENDENCIES += gen-flash-bin

define CST_SIGNATURES_BUILD_CMDS
    rm -rf $(@D)/workdir
    mkdir -p $(@D)/workdir
    $(INSTALL) -D -m 0644 $(GEN_FLASH_BIN_BUILDDIR)/workdir/fit-addrs.log $(@D)/workdir
    $(INSTALL) -D -m 0644 $(GEN_FLASH_BIN_BUILDDIR)/workdir/flash.log $(@D)/workdir
    $(INSTALL) -D -m 0644 $(GEN_FLASH_BIN_BUILDDIR)/workdir/iMX8M/flash.bin $(@D)/workdir
    $(INSTALL) -D -m 0644 $(CST_SIGNATURES_PKGDIR)/csf_fit.txt.tmpl $(@D)/workdir
    $(INSTALL) -D -m 0644 $(CST_SIGNATURES_PKGDIR)/csf_spl.txt.tmpl $(@D)/workdir
    $(INSTALL) -D -m 0755 $(CST_SIGNATURES_PKGDIR)/cst_signature_wrapper.sh $(@D)/workdir
    $(INSTALL) -D -m 0755 $(CST_SIGNATURES_PKGDIR)/sign_hab_imx8m.sh $(@D)/workdir
    $(INSTALL) -D -m 0755 $(@D)/linux64/bin/cst $(@D)/workdir
    $(@D)/workdir/cst_signature_wrapper.sh
endef

define CST_SIGNATURES_INSTALL_IMAGES_CMDS
    $(INSTALL) -D -m 0644 $(@D)/workdir/signed_flash.bin $(BINARIES_DIR)
endef

$(eval $(generic-package))
