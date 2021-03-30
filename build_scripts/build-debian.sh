#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

# Constants used by the script
readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# List of required environment variables for this script
readonly REQUIRED_ENV=" \
    ENV_MACHINE
    ENV_BSP_DIR
    ENV_GIT_REPO
    ENV_GIT_BRANCH
    "

source ${DIR_SCRIPT}/build-common.sh

# Clone repo if it doesn't exist
if [ ! -d ${ENV_BSP_DIR} ]; then
    git clone ${ENV_GIT_REPO} -b ${ENV_GIT_BRANCH} ${ENV_BSP_DIR}
fi

cd ${ENV_BSP_DIR}

# prepare environment for all commands
MACHINE=${ENV_MACHINE} ./var_make_debian.sh -c deploy

# build or rebuild kernel/bootloader/rootfs
echo ubuntu | sudo -S MACHINE=${ENV_MACHINE} ./var_make_debian.sh -c all |& tee build.log
