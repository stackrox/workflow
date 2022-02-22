#!/usr/bin/env bash

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../lib/common.sh"
source "$(dirname "$SCRIPT")/../lib/shell_config.sh"
source "$(dirname "$SCRIPT")/../setup/packages.sh"

: ${SUDO:=sudo}

dpkg -s "${REQUIRED_PACKAGES[@]}" > /dev/null

if [[ "$?" -ne 0 ]] ; then
  echo Installing missing packages
  set -x
  "${SUDO}" apt install "${REQUIRED_PACKAGES[@]}"
  set +x
fi

check_env_installed

