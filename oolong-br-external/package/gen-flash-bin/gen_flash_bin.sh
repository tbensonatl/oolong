#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
WORK_DIR=${SCRIPT_DIR}/workdir

cd ${WORK_DIR}

# The imx-mkimage soc.make file in iMX8M deletes the dtb file, so we need to
# make a copy to restore it to run the print_fit_hab target.
# The soc.make file assumes a dtb name of evk.dtb for the flash_spl_uboot
# target, so that is why we copied the dtb to evk.dtb.
cp iMX8M/evk.dtb iMX8M/evk-backup.dtb
make SOC=iMX8MM flash_spl_uboot 2>&1 | tee flash.log
cp iMX8M/evk-backup.dtb iMX8M/evk.dtb
make SOC=iMX8MM print_fit_hab 2>&1 | tee fit.log
cp iMX8M/evk-backup.dtb iMX8M/evk.dtb
grep -A 4 TEE_LOAD_ADDR fit.log | grep -v TEE_LOAD_ADDR > fit-addrs.log
