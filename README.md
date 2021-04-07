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
# Rebuilding Docker Image

The Docker Image will be built automatically by ./run.sh the first time. Any commits to the GIT repository will cause the image to be rebuilt using cache (e.g. not the latest from Ubuntu)

To force the container to be rebuilt with the latest from Ubuntu each time, pass the `-f` argument:

```$ ./run.sh -f ...```
