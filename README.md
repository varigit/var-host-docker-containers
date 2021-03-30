# Summary

This repository provides a Docker container for building Variscite software releases. These configurations have been tested:

| Container Version | Variscite Release                     |
|--------------------|--------------------------------------|
| Ubuntu 20.04       | - Yocto Dunfell<br>- Debian Bullseye |

# Host Setup

From a brand new Ubuntu installation:

1. Install Docker `$ sudo apt update && sudo apt install docker.io`
2. Give permissions to run docker without sudo `$ sudo usermod -aG docker ${USER}`
3. Logout and Login again for permissions to take effect
4. Clone this repository

# Usage

Their are two different ways to use this container:

## 1. Interactive

In interactive mode, the container allows you to start a shell in the Docker container and run builds just like you would from your host computer. For example:

```
$ mkdir ~/var-fslc-yocto
$ ./run.sh -w ~/var-fslc-yocto
```
You're now running in a container with all build dependencies, and can build as normal:
```
vari@460e5ba862b1:/workdir$ repo init -u https://github.com/varigit/variscite-bsp-platform.git -b refs/tags/dunfell-fslc-5.4-2.1.x-mx8mn-v1.2 -m default.xml
vari@460e5ba862b1:/workdir$ repo sync -j4
vari@460e5ba862b1:/workdir$ MACHINE=imx8mn-var-som DISTRO=fslc-xwayland . setup-environment build_xwayland
vari@460e5ba862b1:/workdir$ bitbake fsl-image-gui
```

## 2. Build Scripts

The container includes build scripts for building Yocto and Debian (more to come in the future):

1. [./build_scripts/build-yocto.sh](./build_scripts/build-yocto.sh)
2. [./build_scripts/build-debian.sh](./build_scripts/build-debian.sh)

The build scripts are configured by passing variables through a Docker .env file. Several examples are available:

1. [./env/imx8mn-var-som-yocto.env](./env/imx8mn-var-som-yocto.env)
2. [./env/imx8mn-var-som-debian.env](./env/imx8mn-var-som-debian.env)
3. [./env/imx8mn-var-dart-yocto.env](./env/imx8mm-var-dart-yocto.env)
4. [./env/imx8mn-var-dart-debian.env](./env/imx8mm-var-dart-debian.env)

Outside tools like Jenkins can create .env files and pass them as an argument to the run script, as demonstrated below:

**Building Yocto Using Scripts**

The Yocto build script can be called by an outside tool, like Jenkins.

Example: Build yocto in ~/var-fslc-yocto directory
```
$ mkdir ~/bar-fslc-yocto
$ ./run.sh -n -w ~/var-fslc-yocto -e <path to .env file>
e.g.
$ ./run.sh -n -w ~/var-fslc-yocto -e imx8mn-var-som-yocto.env
```

Example: Build yocto in ~/var-fslc-yocto directory, using cached sstate and yocto downloads
```
$ mkdir ~/bar-fslc-yocto
$ sudo mkdir /opt/yocto_downloads_docker && sudo chmod 777 /opt/yocto_downloads_docker
$ sudo mkdir /opt/yocto_sstate_docker && sudo chmod 777 /opt/yocto_sstate_docker
$ ./run.sh -n -w ~/var-fslc-yocto -e imx8mn-var-som-yocto.env -v /opt/yocto_downloads_docker:/opt/yocto_downloads -v /opt/yocto_sstate_docker:/opt/yocto_sstate
```

**Building Debian Using Scripts**

Similiar to Yocto, Debian can be built using build scripts:

```
$ mkdir ~/var-debian
./run.sh -p -n -w ~/var-debian -e imx8mn-var-som-debian.env
```

Note the `-p`, which allows Docker to run with elevated permissions required for debootstrap

**Building Android Using Scripts**

TODO

**Building B2Qt Using Scripts**

TODO

# Rebuilding Docker Image

The Docker Image will be built automatically by ./run.sh the first time. Any commits to the GIT repository will cause the image to be rebuilt using cache (e.g. not the latest from Ubuntu)

To force the container to be rebuilt with the latest from Ubuntu each time, pass the `-f` argument:

```$ ./run.sh -f ...```

Currently for Yocto and Debian, the container takes approximately 2.5 minutes to rebuild and install all dependencies.
