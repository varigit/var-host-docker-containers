#!/bin/bash -e
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly GIT_COMMIT="$(git log -1 --format=%h)"
readonly DOCKER_IMAGE="yocto-20-${GIT_COMMIT}"

WORKDIR=$(pwd)
SCRIPT=""
INTERACTIVE="-it"

build_image() {
    docker build -t "variscite:${DOCKER_IMAGE}" ${DIR_SCRIPT}
}

help() {
    echo
    echo "Usage: ${DIR_SCRIPT}/${FILE_SCRIPT} <options>"
    echo
    echo " optional:"
    echo " -b --build               Build Docker Image"
    echo " -e --env                 Docker Environment File"
    echo " -n --non-interactive     Run container and exit without interactive shell"
    echo " -w --workdir             Docker Working Directory to Mount, default is ${WORKDIR}"
    echo " -h --help                Display this Help Message"
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
            -n|--non-interactive)
                INTERACTIVE=""
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
            -e|--env)
                ENV_FILE=$2
                if [ ! -f "${ENV_FILE}" ]; then
                    if [ ! -f "${DIR_SCRIPT}/env/${ENV_FILE}" ]; then
                        echo "Error: ${ENV_FILE} Not Found"
                        echo "Error: ${DIR_SCRIPT}/env/${ENV_FILE} Not Found either"
                        help
                    fi
                fi
                ENV_FILE="--env-file=${DIR_SCRIPT}/env/${ENV_FILE}"
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
    ${INTERACTIVE} \
    ${ENV_FILE} \
    variscite:${DOCKER_IMAGE}
