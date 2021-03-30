#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

# Constants used by the script
readonly WORKDIR="/workdir"
readonly SCRIPT_TIMESTAMP="$(date '+%F-%H-%M-%S')"

dbg() {
    echo "${FILE_SCRIPT} ${1}"
}

# Verify a list of environment
check_required_vars() {
    dbg "Verifying Environment"

    for var_name in $REQUIRED_ENV; do
        var_val=${!var_name}
        if [ -z "${var_val}" ]; then
            dbg "Error: ${var_name} environment variable not set"
            exit -1
        else
            dbg "$var_name = $var_val"
        fi
    done
}

# Verify running inside docker container
if [ ! "$(pwd)" = "${WORKDIR}" ]; then
    dbg "Error: This script should be run from Docker"
    exit -1
fi

# Verify required environment variables are set
check_required_vars
