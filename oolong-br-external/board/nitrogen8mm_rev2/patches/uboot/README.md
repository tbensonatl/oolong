The following mender patches came from https://github.com/mendersoftware/meta-mender/tree/master/meta-mender-core/recipes-bsp/u-boot/patches
(with some modifications):

    0002-Generic-boot-code-for-Mender.patch
    0003-Integration-of-Mender-boot-code-into-U-Boot.patch
    0004-Disable-CONFIG_BOOTCOMMAND-and-enable-CONFIG_MENDER_.patch

The following was manually adapted from https://github.com/mendersoftware/meta-mender/blob/master/meta-mender-core/recipes-bsp/u-boot/u-boot-mender.inc:

    0005-add-mender-defines.patch

The following adjusts the RAM top address to support loading OP-TEE:

    0010-account-for-optee-loadaddr.patch

The following adds support for storing the mender-relevant environment variables
in an external environment on an ext4 filesystem:

    0020-add-mender-external-env.patch
