#!/usr/bin/env bash
set -eo pipefail

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/lib/common.sh"

python_interpreter="$(which python3 || which python)"
einfo "Check pip installation, using ${python_interpreter}"
if ! "${python_interpreter}" -m pip --version > /dev/null; then
  einfo "Pip not found, installing pip"
  einfo "Root access required for installing pip"
  sudo -H "${python_interpreter}" -m ensurepip
fi

einfo "Installing python packages"
einfo "Root access is required to install pip requirements"
"${python_interpreter}" -m pip install -r requirements.txt

platform="$(uname)"

setup_script=""
if [[ "$platform" == "Darwin" ]]; then
  setup_script="osx.sh"
fi

if [[ "$platform" == "Linux" ]]; then
  if [[ -f /etc/lsb-release ]]; then
    distrib=$(env -i bash -c '. /etc/lsb-release && echo ${DISTRIB_ID}')
    if [[ -n "$distrib" ]]; then
      platform="$platform $distrib"
    fi
    if [[ "$distrib" == "Ubuntu" ]]; then
      setup_script="ubuntu.sh"
    fi
  fi
fi

einfo "Installing python packages"
python -m pip install requests

[[ -n "$setup_script" ]] || die "Unsupported platform: $platform"

exec "$(dirname "$SCRIPT")/setup/${setup_script}"
