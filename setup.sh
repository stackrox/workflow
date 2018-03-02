#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/lib/common.sh"

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

[[ -n "$setup_script" ]] || die "Unsupported platform: $platform"

exec "$(dirname "$SCRIPT")/setup/${setup_script}"
