#!/bin/sh

set -euf -o pipefail

EMMC_SYS_NODE=/sys/class/mmc_host/mmc0/mmc0\:0001
EMMC_BLK=mmcblk0
EMMC_DEV_BLK=/dev/${EMMC_BLK}

IMAGE_NAME=Image
DTB_NAME=oolong.dtb
SIGNED_BOOTLOADER=signed_flash.bin

function partition_emmc() {
    echo -n "Partitioning eMMC... "
    # https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
    # This is one of the later answers in the above link, not the accepted answer
    (
        echo o # clear the in memory partition table
        echo n # new partition
        echo p # primary partition
        echo 1 # partition number 1
        echo # default - start at beginning of disk 
        echo +1000M # first partition is currently unused, may be used for recovery image
        echo n # new partition
        echo p # primary partition
        echo 2 # partion number 2
        echo # default, start immediately after preceding partition
        echo +1000M  # rootfs partition A
        echo n # new partition
        echo p # primary partition
        echo 3 # partion number 3
        echo # default, start immediately after preceding partition
        echo +1000M  # rootfs partition B
        echo n # new partition
        echo p # primary partition
        echo 4 # partion number 4
        echo # default, start immediately after preceding partition
        echo # default, use remaining space
        echo p # print the in-memory partition table
        echo w # write changes
    ) | fdisk -b512 ${EMMC_DEV_BLK} > /dev/null
    echo "Done"
}

function image_partitions() {
    echo -n "Creating file system on ${EMMC_DEV_BLK}p1... "
    /sbin/mke2fs -L RECOVERY -F ${EMMC_DEV_BLK}p1 > /dev/null
    echo "Done"

    echo -n "Creating file system on ${EMMC_DEV_BLK}p2... "
    /sbin/mke2fs -L ROOTFS_A -F ${EMMC_DEV_BLK}p2 > /dev/null
    echo "Done"

    echo -n "Creating file system on ${EMMC_DEV_BLK}p3... "
    /sbin/mke2fs -L ROOTFS_B -F ${EMMC_DEV_BLK}p3 > /dev/null
    echo "Done"

    echo -n "Creating file system on ${EMMC_DEV_BLK}p4... "
    /sbin/mke2fs -L DATA -F ${EMMC_DEV_BLK}p4 > /dev/null
    echo "Done"

    mkdir -p recovery
    mount ${EMMC_DEV_BLK}p1 recovery
    # Need the mender directory before first boot so that U-Boot can write the
    # initial mender environment files
    mkdir -p recovery/mender
    umount ${EMMC_DEV_BLK}p1

    mkdir -p partA partB

    mount ${EMMC_DEV_BLK}p2 partA
    mkdir -p partA/boot
    cp ${IMAGE_NAME} partA/boot
    cp ${DTB_NAME} partA/boot
    umount ${EMMC_DEV_BLK}p2

    mount ${EMMC_DEV_BLK}p3 partB
    mkdir -p partB/boot
    cp ${IMAGE_NAME} partB/boot
    cp ${DTB_NAME} partB/boot
    umount ${EMMC_DEV_BLK}p3
}

if [ ! -f ${EMMC_SYS_NODE}/type ] ; then
    echo "Failed to find expected eMMC node ${EMMC_SYS_NODE}"
    exit 1
fi

if [ ! -d ${EMMC_SYS_NODE}/block/${EMMC_BLK} ] || [ ! -b ${EMMC_DEV_BLK} ] ; then
    echo "Failed to find expected eMMC block device ${EMMC_BLK}"
    exit 1
fi

NODE_TYPE=$(cat ${EMMC_SYS_NODE}/type)
if [ "${NODE_TYPE}" != "MMC" ] ; then
    echo "Unexpected node type ${NODE_TYPE} for ${EMMC_SYS_NODE}"
    exit 1
fi

if [ ! -f ${IMAGE_NAME} ] ; then
    echo "Missing ${IMAGE_NAME} (i.e. kernel and initramfs)"
    exit 1
fi

if [ ! -f ${DTB_NAME} ] ; then
    echo "Missing ${DTB_NAME} (i.e. device tree)"
    exit 1
fi

partition_emmc
sync
image_partitions

if [ -f ${SIGNED_BOOTLOADER} ] ; then
    echo -n "Flashing bootloader ${SIGNED_BOOTLOADER}..."
    echo 0 > /sys/block/mmcblk0boot0/force_ro
    dd if=${SIGNED_BOOTLOADER} of=/dev/mmcblk0boot0 bs=1K seek=33
    sync
    echo 1 > /sys/block/mmcblk0boot0/force_ro
    echo "Done"
fi
