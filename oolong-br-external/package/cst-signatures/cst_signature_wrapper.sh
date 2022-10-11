#!/bin/bash

set -eu -o pipefail

CST_CRTS_PATH=${CST_CRTS_DIR:-}
if [ -z "$CST_CRTS_PATH" ] || [ ! -d $CST_CRTS_PATH ] ; then
    echo "No CST certificates path provided; not signing flash.bin"
    echo "Set CST_CRTS_DIR if a signature is needed"
    exit 0
fi

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

cd $SCRIPT_DIR &&
    CST_BIN=$SCRIPT_DIR/cst \
    SIGN_KEY=${CST_CRTS_PATH}/CSF1_1_sha256_4096_65537_v3_usr_crt.pem \
    IMG_KEY=${CST_CRTS_PATH}/IMG1_1_sha256_4096_65537_v3_usr_crt.pem \
    SRK_TABLE=${CST_CRTS_PATH}/SRK_1_2_3_4_table.bin \
        $SCRIPT_DIR/sign_hab_imx8m.sh
