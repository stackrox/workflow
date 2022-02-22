#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../lib/common.sh"
source "$(dirname "$SCRIPT")/../lib/shell_config.sh"
source "$(dirname "$SCRIPT")/../setup/packages.sh"

: ${SUDO:=sudo}

# dnf exits 0 if ANY provided package is present, so we need to spoon-feed it
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  case "${pkg}" in
  yq) # Not provided via dnf
    if ! ${pkg} --version > /dev/null 2>&1; then
      einfo "Package ${pkg} seems missing, installing it..."
      set -x
      "${SUDO}" wget https://github.com/mikefarah/yq/releases/download/v4.20.2/yq_linux_amd64 -O /usr/local/bin/yq
      "${SUDO}" chmod +x /usr/local/bin/yq
      set +x
    fi
    ;;
  *)
    if ! "${pkg}" --version >/dev/null 2>&1 && ! dnf list --installed "${pkg}" >/dev/null 2>&1; then
      einfo "Package ${pkg} seems missing, attempting to install it with dnf..."
      set -x
      "${SUDO}" dnf install "${pkg}"
      set +x
    fi
    ;;
  esac
done

check_env_installed

