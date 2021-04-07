#!/bin/bash
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# Copyright 2021 Variscite Ltd.

# verify container user was set in dockerfile
if [ -z "${USER}" ]; then
  echo "Set user in Dockerfile";
  exit -1
fi

# verify host uid and gid passed in
if [ -z "${HOST_USER_ID}" -a -z "${HOST_USER_GID}" ]; then
    echo "Pass host uid and gid in docker run command" ;
    echo "e.g. -e HOST_USER_ID=$uid -e HOST_USER_GID=$gid" ;
    exit -2
fi

# replace uid and guid in /etc/passwd and /etc/group
sed -i -e "s/^${USER}:\([^:]*\):[0-9]*:[0-9]*/${USER}:\1:${HOST_USER_ID}:${HOST_USER_GID}/"  /etc/passwd
sed -i -e "s/^${USER}:\([^:]*\):[0-9]*/${USER}:\1:${HOST_USER_GID}/"  /etc/group

# allow user to run sudo
adduser ${USER} sudo

# Create Environment Whitelist for SU command
# Environment variables starting with ENV_ will be passed to ${USER} environment
function create_whitelist {
    local VARNAME
    echo -n "" > /tmp/env_whitelist
    compgen -v | grep "ENV_" | while read -r VARNAME; do
      echo -n "${VARNAME}," >> /tmp/env_whitelist
    done
}

create_whitelist
ENV_WHITELIST="$(cat /tmp/env_whitelist)"

#change to /workdir after login
echo "cd /workdir" > /home/${USER}/.bashrc

# If ENB_RUN_SCRIPT set in Docker Environment, run it after login
if [ ! ${ENV_RUN_SCRIPT} = "" ]; then
    echo "${ENV_RUN_SCRIPT}" >> /home/${USER}/.bashrc
fi

# switch to new user, whitelisting environment for Ubuntu >= 20.04
if lsb_release -a | grep "20.04"; then
    su -w "${ENV_WHITELIST}" - "${USER}"
else
    su - "${USER}"
fi
