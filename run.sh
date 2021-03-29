#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly GIT_COMMIT="$(git log -1 --format=%h)"
readonly DOCKER_IMAGE="yocto-20-${GIT_COMMIT}"

WORKDIR=$(pwd)
SCRIPT=""

build_image() {
    docker build -t "variscite:${DOCKER_IMAGE}" ${DIR_SCRIPT}
}

help() {
    echo
    echo "Usage: ${DIR_SCRIPT}/${FILE_SCRIPT} <options>"
    echo
    echo " optional:"
    echo " -b --build   Build Docker Image"
    echo " -w --workdir Docker Working Directory to Mount, default is ${WORKDIR}"
    echo " -h --help    display this Help message"
    echo
    exit
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                help
            ;;
            -b|--build)
                build_image
                shift
            ;;
            -w|--workdir)
                WORKDIR="$2"
                if [ "$WORKDIR" = "" ]; then
                    help
                fi
                shift # past argument
                shift # past value
            ;;
            *)    # unknown option
                echo "Unknown option: $1"
                help
            ;;
        esac
    done
}

parse_args "$@"

# Build container
if ! docker images | grep -q "${DOCKER_IMAGE}"; then
    build_image
fi

uid=$(id -u ${USER})
gid=$(id -g ${USER})

docker run --rm -e HOST_USER_ID=$uid -e HOST_USER_GID=$gid \
    -v ${DIR_SCRIPT}/build_scripts:/workdir/build_scripts \
    -v ~/.ssh:/home/vari/.ssh \
    -v ${WORKDIR}:/workdir \
    -v ~/.gitconfig:/home/vari/.gitconfig \
    -it \
    variscite:${DOCKER_IMAGE}
