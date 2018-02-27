#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/lib/common.sh"

platform="$(uname)"

setup_script=""
if [[ "$platform" == "Darwin" ]]; then
  setup_script="$(dirname "$SCRIPT")/setup/osx.sh"
fi

[[ -n "$setup_script" ]] || die "Unsupported platform: $platform"

exec "$setup_script"
