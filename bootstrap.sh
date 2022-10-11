#!/bin/bash

set -euf -o pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

BUILDROOT_RELEASE=$(cat ${SCRIPT_DIR}/buildroot-version.txt)
BUILDROOT_TARBALL_NAME=buildroot-${BUILDROOT_RELEASE}.tar.gz
BUILDROOT_URL=https://buildroot.org/downloads/${BUILDROOT_TARBALL_NAME}
BUILDROOT_DIR=${SCRIPT_DIR}/buildroot-${BUILDROOT_RELEASE}
BUILDROOT_SHA256_FILE=${SCRIPT_DIR}/buildroot.sha256

if [ ! -d ${BUILDROOT_DIR} ] ; then
    cd ${SCRIPT_DIR}
    curl -o ${BUILDROOT_TARBALL_NAME} ${BUILDROOT_URL}
    sha256sum -c ${BUILDROOT_SHA256_FILE}
    tar zxvf ${BUILDROOT_TARBALL_NAME}
fi
