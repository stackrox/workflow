#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../lib/common.sh"
source "$(dirname "$SCRIPT")/../lib/shell_config.sh"
source "$(dirname "$SCRIPT")/../setup/packages.sh"

: ${SUDO:=sudo}

echo Checking for snap
if [[ ! -x "$(command -v snap)" ]]; then
  set -x
  echo Installing snap
  "${SUDO}" yum install snapd -y
  "${SUDO}" systemctl enable --now snapd.socket
  "${SUDO}" ln -s /var/lib/snapd/snap /snap
  set +x
fi

echo Installing required packages
for pkg in "${REQUIRED_PACKAGES[@]}"
do
  set -x
  "${SUDO}" snap install "${pkg}"
  set +x
done

check_env_installed
