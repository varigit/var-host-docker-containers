#!/usr/bin/env bash
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

set -e

readonly FILE_SCRIPT="$(basename "$0")"
readonly DIR_SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${DIR_SCRIPT}"

readonly GIT_COMMIT="$(git log -1 --format=%H | cut -c1-8)"
readonly VARISCITE_REGISTRY="ghcr.io/varigit/var-host-docker-containers/yocto-env"

UBUNTU_VERSIONS_SUPPORTED=("22.04" "20.04" "18.04" "16.04" "14.04")
UBUNTU_VERSION="20.04"
WORKDIR="$(pwd)"
SCRIPT=""
INTERACTIVE="-it"
DOCKER_VOLUMES=""
PRIVLEGED=""
BUILD_CACHE=""
CPUS="0.000"
QUIRKS=""

# Flag indicating local image usage
LOCAL_FLAG=0

build_image() {
    DOCKERFILE="$1"
    if [ ! -f "${DIR_SCRIPT}/${DOCKERFILE}" ]; then
        echo "${DIR_SCRIPT}/${DOCKERFILE} not found"
        exit -1
    fi
    docker build ${BUILD_CACHE} -t "${IMAGE_REPO}:${DOCKER_IMAGE}" "${DIR_SCRIPT}" -f ${DOCKERFILE}
}

array_contains () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == "$seeking" ]]; then
            in=0
            break
        fi
    done
    return $in
}

help() {
    echo
    echo "Usage: \"${DIR_SCRIPT}\"/${FILE_SCRIPT} <options>"
    echo
    echo " optional:"
    echo " -u --ubuntu-version      Ubuntu Version: ${UBUNTU_VERSIONS_SUPPORTED[@]}"
    echo " -b --build               Build Docker Image, includes only changes made to Dockerfile"
    echo " -f --force-build         Build Docker Image with --no-cache, will include latest from Ubuntu"
    echo " -e --env                 Docker Environment File"
    echo " -n --non-interactive     Run container and exit without interactive shell"
    echo " -w --workdir             Docker Working Directory to Mount, default is \"${WORKDIR}\""
    echo " -v --volume              Docker Volumes to Mount, e.g. -v /opt/yocto_downloads_docker:/opt/yocto_downloads -v /opt/yocto_sstate_docker:/opt/yocto_sstate"
    echo " -p --privledged          Run docker in privledged mode, allowing access to all devices"
    echo " --host-network           Run container with host network mode"
    echo " -c --cpus                Limit the number of CPUs available to the container, default is ${CPUS}, which will use all available CPUs"
    echo " -h --help                Display this Help Message"
    echo " --command                Run a command inside the docker container, implies -n"
    echo " -l --local               Build and use a local Docker image (tagged with GIT_COMMIT) instead of pulling"
    echo
    echo "Example - Run Interactive Shell In Current Directory:"
    echo "./run.sh"
    echo
    echo "Example - Run Interactive Shell In Another Directory:"
    echo "./run.sh -w ~/var-fslc-yocto"
    echo
    echo "Example - Run Interactive Shell In Another Directory, mounting directories inside Docker container"
    echo "./run.sh -w ~/var-fslc-yocto -v /opt/yocto_downloads_docker:/opt/yocto_downloads -v /opt/yocto_sstate_docker:/opt/yocto_sstate"
    echo
    exit
}

# Add a flag to determine whether to build the image
BUILD_IMAGE_FLAG=0

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                help
            ;;
            --command)
                COMMAND="$2"
                INTERACTIVE=""
                shift
                shift
            ;;
            -u|--ubuntu-version)
                UBUNTU_VERSION="$2"
                # Verify Ubuntu Version is Supported
                array_contains "${UBUNTU_VERSION}" "${UBUNTU_VERSIONS_SUPPORTED[@]}" || ( echo "Error, Ubuntu '${UBUNTU_VERSION}' not supported, use one of: ${UBUNTU_VERSIONS_SUPPORTED[@]}"; exit 1);
                shift
                shift
            ;;
            -b|--build)
                # Set the flag to build the image later
                BUILD_IMAGE_FLAG=1
                shift
            ;;
            -f|--force-build)
                BUILD_CACHE="--no-cache"
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
                if [ ! -d "$WORKDIR" ]; then
                    echo "Error: \"${WORKDIR}\" doesn't exist"
                    echo "Please verify path and run:"
                    echo "mkdir -p \"${WORKDIR}\""
                    exit -1
                fi
                shift # past argument
                shift # past value
            ;;
            -v|--volume)
                NEW_VOL="$2"
                if [ "$NEW_VOL" = "" ]; then
                    help
                fi
                DOCKER_VOLUMES="${DOCKER_VOLUMES} -v ${NEW_VOL}"
                shift # past argument
                shift # past value
            ;;
            -e|--env)
                ENV_FILE=$2
                if [ ! -f "${ENV_FILE}" ]; then
                    echo "Error: ${ENV_FILE} Not Found"
                    echo "Error: \"${DIR_SCRIPT}\"/env/${ENV_FILE} Not Found either"
                    help
                fi
                ENV_FILE="--env-file=${ENV_FILE}"
                shift # past argument
                shift # past value
            ;;
            -p|--privledged)
                PRIVLEGED=" --privileged"
                shift
            ;;
            --host-network)
                DOCKER_HOST_NETWORK=" --network host"
                shift
            ;;
            -c|--cpus)
                CPUS="$2"
                if ! [[ "$CPUS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    echo "Error: CPU limit must be a valid number."
                    exit 1
                fi
                shift
                shift
            ;;
            -l|--local)
                LOCAL_FLAG=1
                shift
            ;;
            -a|--android)
                ANDROID_BUILD_VERSION="$2"
                shift
                shift
            ;;
            *)    # unknown option
                echo "Unknown option: $1"
                help
            ;;
        esac
    done
}

set_quirks() {
    # Get Host OS Information
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    # If Host is Ubuntu 20.04 and Container is Ubuntu 22.04
    if [ "$UBUNTU_VERSION" = "22.04" ] && [ "$VERSION_ID" = "20.04" ] && [ "$ID" = "ubuntu" ]; then
        # https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1321924/j721excpxevm-yocto-build-always-gives-an-error-for-gdk-pixbuf_2-42-10-bb-do_compile
        QUIRKS="${QUIRKS} --security-opt seccomp=unconfined"
    fi
}

parse_args "$@"

# Build Docker image name with Android suffix if needed
if [ -n "$ANDROID_BUILD_VERSION" ]; then
    readonly DOCKER_IMAGE="${UBUNTU_VERSION}-${GIT_COMMIT}-android-${ANDROID_BUILD_VERSION}"
else
    readonly DOCKER_IMAGE="${UBUNTU_VERSION}-${GIT_COMMIT}"
 fi
readonly HOSTNAME=$( echo "$DOCKER_IMAGE" | sed 's/\./-/g')

# Build or pull the image
if [ $LOCAL_FLAG -eq 1 ]; then
    # Build local container if the image does not exist, the cache needs to be rebuilt, or the build flag is set
    readonly IMAGE_REPO="variscite"

    # Generic build image handling - DOCKER_IMAGE already includes Android suffix if needed
    if [ -n "$ANDROID_BUILD_VERSION" ]; then
        DOCKERFILE_NAME="Dockerfile_${UBUNTU_VERSION}_android_${ANDROID_BUILD_VERSION}"
    else
        DOCKERFILE_NAME="Dockerfile_${UBUNTU_VERSION}"
    fi

    if ! docker images | awk -v IMAGE_REPO=${IMAGE_REPO} '{ if ($1 == IMAGE_REPO) print $2}' | grep -q "${DOCKER_IMAGE}" \
        || [ -n "$BUILD_CACHE" ] \
        || [ $BUILD_IMAGE_FLAG -eq 1 ]; then
        echo "Building ${DOCKERFILE_NAME}"
        build_image "${DOCKERFILE_NAME}"
    fi
else
    # Pull the image if the image does not exist or the build flag is set
    readonly IMAGE_REPO="${VARISCITE_REGISTRY}"

    if ! docker images | awk -v IMAGE_REPO=${IMAGE_REPO} '{ if ($1 == IMAGE_REPO) print $2}' | grep -q "${DOCKER_IMAGE}" \
        || [ $BUILD_IMAGE_FLAG -eq 1 ]; then
        echo "Pulling ${IMAGE_REPO}:${DOCKER_IMAGE}"
        docker pull "${IMAGE_REPO}:${DOCKER_IMAGE}"
    fi
fi

uid=$(id -u ${USER})
gid=$(id -g ${USER})

# .gitconfig is required by repo and git
if [ ! -f ${HOME}/.gitconfig ]; then
    echo "Error: Please create ${HOME}/.gitconfig on your host computer:"
    echo '    $ git config --global user.email "you@example.com"'
    echo '    $ git config --global user.name "Your Name"'
    exit -1
fi

set_quirks

docker run ${EXTRA_ARGS} --rm -e HOST_USER_ID=$uid -e HOST_USER_GID=$gid \
	-v ~/.ssh:/home/vari/.ssh \
	-v "${WORKDIR}":/workdir \
	-v ~/.gitconfig:/tmp/host_gitconfig \
	-v /usr/src:/usr/src \
	-v /lib/modules:/lib/modules \
	-v /linux-kernel:/linux-kernel \
	--hostname ${HOSTNAME} \
	${DOCKER_VOLUMES} \
	${INTERACTIVE} \
	${ENV_FILE} \
	${PRIVLEGED} \
	${DOCKER_HOST_NETWORK} \
	--cpus=${CPUS} \
	${QUIRKS} \
	${IMAGE_REPO}:${DOCKER_IMAGE} "$COMMAND"
