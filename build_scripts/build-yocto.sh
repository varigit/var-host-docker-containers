#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

# Constants used by the script
readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly DIR_DOWNLOADS="/opt/yocto_downloads"
readonly DIR_SSTATE="/opt/yocto_sstate"
# List of required environment variables for this script
readonly REQUIRED_ENV=" \
        ENV_MACHINE
        ENV_DISTRO
        ENV_BUILD_DIR
        ENV_IMAGE
        ENV_SETUP_SCRIPT
        ENV_REPO_MANIFEST_BRANCH
        ENV_REPO_MANIFEST_FILE
        ENV_REPO_MANIFEST_GIT
        ENV_META_VARISCITE_NAME
        ENV_META_VARISCITE_GIT
        ENV_BSP_DIR
    "

source ${DIR_SCRIPT}/build-common.sh

# Use repo to get source code
mkdir -p ${WORKDIR}/${ENV_BSP_DIR} && cd ${WORKDIR}/${ENV_BSP_DIR}
repo init -u ${ENV_REPO_MANIFEST_GIT} -b ${ENV_REPO_MANIFEST_BRANCH} -m ${ENV_REPO_MANIFEST_FILE} && repo sync -j4

# Fetch custom version of meta variscite if ENV_META_VARISCITE_REF is set
if [ -n "${ENV_META_VARISCITE_REF}" ]; then
    # Create unique remote name for this build
    readonly META_REMOTE="${ENV_META_VARISCITE_NAME}-${ENV_META_VARISCITE_REF}-${SCRIPT_TIMESTAMP}"
    dbg "Changing ${ENV_META_VARISCITE_NAME} to ${ENV_META_VARISCITE_GIT} ${ENV_META_VARISCITE_REF}"
    cd ${WORKDIR}/${ENV_BSP_DIR}/sources/${ENV_META_VARISCITE_NAME}
    git remote add ${META_REMOTE} ${ENV_META_VARISCITE_GIT}
    git fetch --all
    git checkout ${META_REMOTE}/${ENV_META_VARISCITE_REF} || git checkout ${ENV_META_VARISCITE_REF}
fi

# Setup Build Environment
cd ${WORKDIR}/${ENV_BSP_DIR}
EULA=1 MACHINE=${ENV_MACHINE} DISTRO=${ENV_DISTRO} source ./${ENV_SETUP_SCRIPT} ${ENV_BUILD_DIR}

# Setup Downloads and SSTATE Directories if they don't exist
mkdir -p ${DIR_DOWNLOADS}
mkdir -p ${DIR_SSTATE}

# Setup downloads and sstate directories in local.conf
if [ -d ${DIR_DOWNLOADS} ]; then
    grep -q '^DL_DIR' conf/local.conf && sed -i '/DL_DIR/d' conf/local.conf
    echo "DL_DIR ?= \"${DIR_DOWNLOADS}\"" >> conf/local.conf
fi
if [ -d ${DIR_SSTATE} ]; then
    grep -q '^SSTATE_DIR' conf/local.conf && sed -i '/SSTATE_DIR/d' conf/local.conf
    echo "SSTATE_DIR ?= \"${DIR_SSTATE}\"" >> conf/local.conf
fi

# Build
BB_CMD="bitbake ${ENV_IMAGE}"
dbg "Running \"${BB_CMD}\""
${BB_CMD} | tee build.log > /dev/null
