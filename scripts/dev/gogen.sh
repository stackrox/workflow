#!/usr/bin/env bash

# Runs go generate rooted at the current working directory (or a directory specified as the first
# argument, if any), but with the PATH expected for mockgen-wrapper to work.
# Usage: gogen [<directory>] (while inside the rox repo).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

gitroot="$(git rev-parse --show-toplevel)"

if [[ -f "${gitroot}/go.mod" ]]; then
  export GO111MODULE=on
fi

export PATH="$PATH:${gitroot}/tools/generate-helpers"

private_gogen() {
  target_dir=$1
  echo "Generating for ${target_dir}"
  ( cd "$target_dir" && go generate "./..." )
}

if [[ "$#" -eq 0 ]]; then
  # Default argument is current working directory.
  set -- .
fi

for dir in "$@"; do
  private_gogen "${dir}"
done
