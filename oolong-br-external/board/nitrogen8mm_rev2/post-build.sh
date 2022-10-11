#!/bin/bash

set -eu -o pipefail

cp ${BINARIES_DIR}/imx8mm-nitrogen8mm_rev2.dtb ${BINARIES_DIR}/oolong.dtb

EXT4_IMAGE_NAME=${BINARIES_DIR}/oolong.ext4

rm -rf ${BINARIES_DIR}/oolong-fs
rm -f ${EXT4_IMAGE_NAME}
mkdir -p ${BINARIES_DIR}/oolong-fs/boot
cp ${BINARIES_DIR}/Image ${BINARIES_DIR}/oolong-fs/boot
cp ${BINARIES_DIR}/oolong.dtb ${BINARIES_DIR}/oolong-fs/boot
echo "Generating ${EXT4_IMAGE_NAME}"

dd if=/dev/zero of=${BINARIES_DIR}/oolong-fs/boot/Image bs=1M count=20
${HOST_DIR}/sbin/mkfs.ext4 -d ${BINARIES_DIR}/oolong-fs -r 1 -N 0 -m 5 -L "rootfs" -O 64bit ${EXT4_IMAGE_NAME} "100M"
rm -rf ${BINARIES_DIR}/oolong-fs
${HOST_DIR}/bin/mender-artifact write rootfs-image -t oolong-nitrogen8mm_rev2 -n dev-release -f ${EXT4_IMAGE_NAME} -o ${BINARIES_DIR}/oolong.mender
