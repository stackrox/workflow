#!/usr/bin/env bash
set -eo pipefail

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/lib/common.sh"

einfo "Check pip installation, using ${PYTHON_INTERPRETER}"
if ! "${PYTHON_INTERPRETER}" -m pip --version &> /dev/null; then
  einfo "Pip not found, installing pip"
  "${PYTHON_INTERPRETER}" -m ensurepip
fi

einfo "Installing python packages"
"${PYTHON_INTERPRETER}" -m pip install --user -r "$(dirname "${SCRIPT}")/requirements.txt"

platform="$(uname)"

setup_script=""
if [[ "$platform" == "Darwin" ]]; then
  setup_script="osx.sh"
fi

if [[ "$platform" == "Linux" ]]; then
  distrib="$(lsb_release --id --short)"
  if [[ -n "$distrib" ]]; then
    platform="$platform $distrib"
  fi
  case "$distrib" in
  Ubuntu)
    setup_script="ubuntu.sh"
    ;;
  RedHatEnterprise)
    setup_script="rhel.sh"
    ;;
  Fedora)
    setup_script="rhel.sh"
    ;;
  esac
fi

[[ -n "$setup_script" ]] || die "Unsupported platform: $platform"

exec "$(dirname "$SCRIPT")/setup/${setup_script}"
