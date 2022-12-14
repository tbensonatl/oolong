# Overview

This project is a sandbox for exploring the cybersecurity features for a modern ARMv8 SoC, including the use of a Trusted Execution Environment (TEE). The development board is a Nitrogen8M Mini Rev 3.0 board from Boundary Devices with an NXP i.MX8M Mini SoC. Boundary Devices has excellent software support via branches of U-Boot (https://github.com/boundarydevices/u-boot), Linux (https://github.com/boundarydevices/linux), and ARM Trusted Firmware-A (ATF-A, https://github.com/boundarydevices/imx-atf). The upstream OP-TEE project is a branch from NXP (https://source.codeaurora.org/external/imx/imx-optee-os).

The build system is Buildroot (https://buildroot.org). Buildroot generates full system images versus a `deb` or `rpm` based distribution as can be generated by Yocto. For system updates, we aim to leverage `mender`, which supports A/B filesystem partitioning and rollback support in the case of a failed update.

This project is an early-stage work-in-progress. This README will be updated as new features are added. It may eventually be a full-fledged base image for the Nitrogen8M Mini, but at least for now it is missing some features that users may expect.

# License

The license for newly developed scripts, configuration files, and code unrelated to other projects in this repository is the MIT license. There are also several patches to existing projects (e.g. `buildroot`, a `u-boot` fork, `mender`, etc.) and these patches carry the license of the corresponding project. See the LICENSE file for the MIT license text. When appropriate, I will attempt to upstream patches or come up with a cleaner solution that does not require the patch.

# Building a System Image

On a recent Linux distribution with basic build support (gcc, make, etc.) and `curl` already installed, the following should be sufficient to build the project:

```
git clone https://github.com/tbensonatl/oolong
cd oolong
make
```

This will generate the following important files:

```
oolong-build/images/flash.bin
oolong-build/images/Image
oolong-build/images/oolong.dtb
```

where `flash.bin` is the unsigned bootloader, `Image` is the kernel and root filesystem stored as an initramfs into the kernel image, and `oolong.dtb` is the device tree blob. `flash.bin` includes several components, namely a U-Boot Secondary Program Loader (SPL), an ARM Trusted Firmware-A (ATF-A) image, OP-TEE (a Trusted Execution Environment), and the main U-Boot program.

The `flash.bin` bootloader is not signed. It will boot on open boards (the default if you have not taken action to close/secure the board), but if a board has been closed, then the `flash.bin` file must be signed in order to boot. See the section on signed bootloaders for more details on generating a signed image.

# Console / UART

The Nitrogen8M Mini offers a UART console via the header labeled SERIAL. Unlike many boards that have an integrated serial to USB converter chip and a microUSB port on the board, the Nitrogen8M Mini has a header and an included cable that breaks out the header to two DB9 serial cables, one of which is labeled CONSOLE. With a serial to USB converter cable, we can connect this cable to our host and then connect to the resulting device (e.g. `/dev/ttyUSB0`) with a terminal program (e.g. `minicom`) configured to 115200 8N1 and no hw/sw flow control.

# Loading Images via Serial Download Protocol (SDP)

For development, rather than flashing the eMMC or an SD card, I typically download the bootloader to the board over USB via SDP. For the Nitrogen8M Mini SBC, there is an ON/OFF switch labeled SW1 on the board that sets the boot ROM to use SDP when set to ON. With SW1 toggled ON and the board powered and connected via USB, running the following from the base directory of the checkout will download the bootloader to the board:

```
sudo ./oolong-build/host/bin/uuu -d ./oolong-build/images/flash.bin
```

`sudo` is required unless your `udev` rules are updated to allow user access to the USB devices presented by the SDP mode. `uuu` will download two bundles to the board: first the U-Boot SPL and then the rest of the image.

This is sufficient for bootloader development, but if the goal is to work on the Linux kernel or applications, then an image can be transferred via TFTP in the U-Boot console and launched. To do this, an Ethernet connection is needed as well as a TFTP server on your host with the `oolong-build/images/Image` and `oolong-build/images/oolong.dtb` files copied to the TFTP server's shared directory.

To run U-Boot commands, first press a key to interrupt the boot process (the U-Boot config in this project currently includes a 5 second boot delay to allow for interruption) and then execute something like the following:

```
setenv ipaddr 192.168.1.199
setenv serverip 192.168.1.2

setenv devicetree_load_address 0x60000000
setenv devicetree_image oolong.dtb
setenv kernel_load_address 0x40800000
setenv kernel_image Image

setenv bootargs console=ttymxc1,115200 earlyprintk uart_from_osc
setenv testboot "tftpboot ${devicetree_load_address} ${devicetree_image}; tftpboot ${kernel_load_address} ${kernel_image}; booti ${kernel_load_address} - ${devicetree_load_address}"
run testboot
```

where `192.168.1.199` is a valid IP on your network and `192.168.1.2` is the TFTP server's IP. The `devicetree_load_address` needs to be large enough so that loading `Image` does not overwrite it, so it needs to be increased in the case of a very large `Image`.

# Flashing the bootloader/eMMC

Although SDP/TFTP are useful during development, eventually you will want to flash images to the eMMC. There is a helper script in `oolong-br-external/board/nitrogen8mm_rev2/scripts/image_emmc.sh` that will partition the user partition of the eMMC as follows: (1) a boot partition, currently unused, (2) rootfs A, (3) rootfs B, and (4) a persistent storage partition. As discussed later, the bootloader supports `mender` for image upgrades. `mender` toggles between two root filesystems for each upgrade to allow for rollback in the case of a failed update. The persistent storage partition is for data that should persist across updates, such as logs. To run the image script, `scp` the `image_emmc.sh`, `Image`, and `oolong.dtb` files to a running system (likely booted via SDP/TFTP as described above) and run the `image_emmc.sh` script.

The bootloader is stored in the eMMC boot partition 0. This partition is set to read-only by default, so it needs to be set to writable first. Also, the boot ROM expects the image to be stored with a 33 KiB offset in the boot partition. Thus, after copying `flash.bin` to a running image, the following flashes the bootloader:

```
echo 0 >  /sys/block/mmcblk0boot0/force_ro
dd if=flash.bin of=/dev/mmcblk0boot0 bs=1K seek=33
```

This process can be simplified in the future, but during development it is often not necessary to flash an image. Once no further bootloader updates are expected, it makes sense to flash the bootloader and perform subsequent updates via `mender` artifacts.

# Mender Integration

Because the root filesystem is stored in the kernel image as an initramfs, the system image is just two files: `Image` and `oolong.dtb`. This makes the image update process straightforward: these files can just be replaced.

However, this simple approach would be missing several desirable features. Enabling over-the-air (OTA) updates would require some infrastructure to download, verify, and apply the updates. Furthermore, for device reliability, it is preferable to support A/B partitions such that updates can be applied to the non-active partition and the device rolled back to the last working release in the case of a failed update.

Mender (`https://mender.io`) supports these features (OTA updates, A/B partitioning, rollback). It is implemented as a client on the device and requires bootloader integration to handle rollback and active partition switching.

Mender provides a set of scripts to help with mender U-Boot integration for Yocto projects. Because we are using `buildroot`, we can not directly use the `mender` Yocto layer, but we manually integrated the U-Boot patches and created a set of `#define`s for the Nitrogen8M Mini in `oolong-br-external/board/nitrogen8mm_rev2/patches/uboot`. Mender requires some mechanism to communicate with the bootloader to update the root filesystem partition and to indicate that an upgrade has taken place so that the bootloader can employ fallback logic in the case of a failed upgrade. Typically, this is done by storing the U-Boot environment in some external persistent storage (e.g. SPI flash, the eMMC boot partitions, etc.) and mender updates this environment using userspace Linux tools. However, that approach requires that the U-Boot environment be writable, which presents its own risks. For example, the environment may be corrupted due to a failed write (e.g. a power outage while updating the environment). U-Boot supports redundant environment storage to mitigate this risk. Malicious U-Boot environment updates -- such as changing the `bootcmd` environment variable and thus the boot process -- is another risk. Signed bootloaders, as covered in the next question, do not eliminate the malicious update risk because the environment itself is not signed (it cannot be signed because it changes).

Thus, a common cybersecurity recommendation is to not store the U-Boot environment externally (i.e. to set `CONFIG_ENV_IS_NOWHERE=y` in the U-Boot configuration). This option embeds the environment into the bootloader and thus the environment will be covered by the bootloader signature. However, mender must have some mechanism of persisting data that the bootloader will use. We created a patch that adds support for a mender external environment to U-Boot where the mender external environment is stored in file(s) (two files if the redundant environment is enabled) on an ext4 filesystem on the eMMC. This acts as an overlay to the U-Boot default environment and only specific variables will be imported from that environment. Specifically, we import the following variables from (and export the following variables to) the external environment: `bootcount`, `mender_boot_part`, `mender_boot_part_hex`, `mender_check_saveenv_canary`, `mender_saveenv_canary`, `upgrade_available`. Other variables, such as `bootcmd`, will not be imported from the external environment even if they are inserted there.

# Signed Bootloader / HAB

The i.MX8M Mini supports cryptographically signing bootloaders and subsequent images to create and extend a chain of trust via the High Assurance Boot (HAB) feature. `oolong` supports signing the bootloader using NXP's Code Signing Tool (CST) by enabling the following entry in `oolong-br-external/configs/oolong_nitrogen8mm_rev2_defconfig`:

```
# Set to y to enable signatures
BR2_PACKAGE_CST_SIGNATURES=n
```

Prior to enabling this feature, you must download the Code Signing Tool from https://www.nxp.com/webapp/sps/download/license.jsp?colCode=IMX_CST_TOOL (it requires an NXP account and accepting a license agreement). Create a PKI using the CST, copy the CST `tgz` file to `oolong-br-external/package/cst-signatures`, and then build with

```
make CST_CRTS_DIR=/path/to/cst/crts
```

If the CST tool version differs from that in `cst-signatures.mk`, then update `CST_SIGNATURES_VERSION` in the `.mk` file and add the hash to `cst-signatures.hash`.
The build will generate `oolong-build/images/signed_flash.bin`. Using a signed bootloader, we see the following in U-Boot:

```
=> hab_status 

Secure boot disabled

HAB Configuration: 0xf0, HAB State: 0x66
No HAB Events Found!
```

The HAB configuration `0xf0` indicates that the board is open (i.e. non-secure). When the board is closed, this should change to `0xcc`. I have not yet closed my board as I only have one and they are currently out-of-stock, so I would not be able to replace the board if I were to get it into an unusable state during testing. There are certain security features that I will not be able to test on an open board, so eventually I will need to close it. The HAB State `0x66` also indicates that the board is in non-secure state, but the `No HAB Events Found!` message verifies that the Boot ROM successfully authenticated the signature. (Actually, there are two signatures, one for the SPL and another for the remainder of the image.)

Loading an unsigned bootloader on this board (which has had its super root key hash fuses written) produces the following warnings:

```
=> hab_status 

Secure boot disabled

HAB Configuration: 0xf0, HAB State: 0x66

--------- HAB Event 1 -----------------
event data:
        0xdb 0x00 0x08 0x43 0x33 0x11 0xcf 0x00

STS = HAB_FAILURE (0x33)
RSN = HAB_INV_CSF (0x11)
CTX = HAB_CTX_CSF (0xCF)
ENG = HAB_ENG_ANY (0x00)


--------- HAB Event 2 -----------------
event data:
        0xdb 0x00 0x14 0x43 0x33 0x0c 0xa0 0x00
        0x00 0x00 0x00 0x00 0x00 0x7e 0x0f 0xc0
        0x00 0x00 0x00 0x20

STS = HAB_FAILURE (0x33)
RSN = HAB_INV_ASSERTION (0x0C)
CTX = HAB_CTX_ASSERT (0xA0)
ENG = HAB_ENG_ANY (0x00)


--------- HAB Event 3 -----------------
event data:
        0xdb 0x00 0x14 0x43 0x33 0x0c 0xa0 0x00
        0x00 0x00 0x00 0x00 0x00 0x7e 0x0f 0xe0
        0x00 0x00 0x00 0x01

STS = HAB_FAILURE (0x33)
RSN = HAB_INV_ASSERTION (0x0C)
CTX = HAB_CTX_ASSERT (0xA0)
ENG = HAB_ENG_ANY (0x00)


--------- HAB Event 4 -----------------
event data:
        0xdb 0x00 0x14 0x43 0x33 0x0c 0xa0 0x00
        0x00 0x00 0x00 0x00 0x00 0x7e 0x10 0x00
        0x00 0x00 0x00 0x04

STS = HAB_FAILURE (0x33)
RSN = HAB_INV_ASSERTION (0x0C)
CTX = HAB_CTX_ASSERT (0xA0)
ENG = HAB_ENG_ANY (0x00)

=> 
```

So if this board were closed, the above bootloader would not be executed.

# To-Be-Done

This is an early work-in-progress and there are many things that have not yet been done. The goal is primarily to develop and test device security features, such as Trusted Execution Environment services, image/data encryption, secure storage, etc. Future directions may include extending the chain of trust from the bootloader to the `Image`/`dtb` files, securely storing encryption keys, etc.

There are also several missing features that would be needed to extend `oolong` to a more complete base image, such as versioning, better log handling, simplifying the imaging process, etc.

# Example Boot Log

The following is an example boot log loading the bootloader via SDP, verifying that there are no reported HAB events (i.e. that the bootloader signature was authenticated without error), loading the image/dtb via TFTP, booting Linux, and running a set of TEE regression tests.

```
U-Boot 2022.04 (Oct 09 2022 - 11:07:47 -0400)

CPU:   i.MX8MMQ rev1.0 at 1200 MHz
Reset cause: POR
Model: Boundary Devices i.MX8MMini Nitrogen8MM Rev2
Board: nitrogen8mm_rev2
       Watchdog enabled
DRAM:  2 GiB
Core:  136 devices, 21 uclasses, devicetree: separate
MMC:   FSL_SDHC: 0, FSL_SDHC: 1
Loading Environment from MMC...
OK
In:    serial
Out:   serial
Err:   serial
SEC0:  RNG instantiated

 BuildInfo:
  - ATF 

Display: mipi:tm070jdhg30-1 (1280x800)
Net:   AR8035 at 4
FEC [PRIME], usb_ether
*** Warning - !Started from usb, using default environment

Hit any key to stop autoboot:  0 
=> hab_status 

Secure boot disabled

HAB Configuration: 0xf0, HAB State: 0x66
No HAB Events Found!
=> setenv ipaddr 192.168.50.99
=> setenv serverip 192.168.50.3
=> 
=> setenv devicetree_load_address 0x60000000
=> setenv devicetree_image imx8mm-nitrogen8mm_rev2.dtb
=> setenv kernel_load_address 0x40800000
=> setenv kernel_image Image
=> 
=> setenv bootargs console=ttymxc1,115200 earlyprintk uart_from_osc
=> setenv testboot "tftpboot ${devicetree_load_address} ${devicetree_image}; tftpboot ${kernel_load_address} ${kernel_image}; booti ${kernel_load_address} - ${devicetree_load_address}"
=> run testboot
Using FEC device
TFTP from server 192.168.50.3; our IP address is 192.168.50.99
Filename 'imx8mm-nitrogen8mm_rev2.dtb'.
Load address: 0x60000000
Loading: #####
         414.1 KiB/s
done
Bytes transferred = 60770 (ed62 hex)
Using FEC device
TFTP from server 192.168.50.3; our IP address is 192.168.50.99
Filename 'Image'.
Load address: 0x40800000
Loading: #################################################################
#################################################################
...
#################################################################
#################################################################
         744.1 KiB/s
done
Bytes transferred = 46328320 (2c2ea00 hex)
## Flattened Device Tree blob at 60000000
   Booting using the fdt blob at 0x60000000
   Using Device Tree in place at 0000000060000000, end 0000000060011d61

Starting kernel ...

[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd034]
[    0.000000] Linux version 5.15.38 (tbenson@c500r) (aarch64-buildroot-linux-uclibc-gcc.br_real (Buildroot -g7db1dda) 11.3.0, GNU ld (GNU Binutils) 2.37) #4 SMP PREEMPT Sun Oct 9 19:25:59 EDT 2022
[    0.000000] Machine model: Boundary Devices i.MX8MMini Nitrogen8MM Rev2
[    0.000000] efi: UEFI not found.
[    0.000000] Reserved memory: created CMA memory pool at 0x0000000096000000, size 640 MiB
[    0.000000] OF: reserved mem: initialized node linux,cma, compatible id shared-dma-pool
[    0.000000] Zone ranges:
[    0.000000]   DMA      [mem 0x0000000040000000-0x00000000bdffffff]
[    0.000000]   DMA32    empty
[    0.000000]   Normal   empty
...
tarting syslogd: OK
Starting klogd: OK
Running sysctl: OK
Saving random seed: OK
Starting tee-supplicant: Using device /dev/teepriv0.
OK
Starting mender service: OK
Starting sshd: OK

Welcome to Buildroot
buildroot login: root
Password: 
# xtest 
Run test suite with level=0

TEE test application started over default TEE instance
######################################################
#
# regression
#
######################################################
 
* regression_1001 Core self tests
o regression_1001.1 Core self tests
  regression_1001.1 OK
o regression_1001.2 Core dt_driver self tests
  regression_1001.2 OK
  regression_1001 OK
 
* regression_1002 PTA parameters
  regression_1002 OK
 
* regression_1003 Core internal read/write mutex
    Number of parallel threads: 6 (2 writers and 4 readers)
    Max read concurrency: 2
    Max read waiters: 2
    Mean read concurrency: 1.4875
    Mean read waiting: 1.025
  regression_1003 OK
regression_8001 OK
regression_8002 OK
regression_8101 OK
regression_8102 OK
regression_8103 OK
+-----------------------------------------------------
26307 subtests of which 0 failed
95 test cases of which 0 failed
0 test cases were skipped
TEE test application done!
# 
```

Note that some of the TEE tests reported panics in the Trusted Applications (TAs). I have not yet investigated if that is expected (e.g. because the test is verifying that certain behaviors by the TAs are not allowed), but they were not reported by `xtest` as failures.
