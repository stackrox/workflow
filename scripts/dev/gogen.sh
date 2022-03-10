#!/usr/bin/env bash

# Runs go generate rooted at the current working directory (or a directory specified as the first
# argument, if any), but with the PATH expected for our custom binaries to work.
# You can also pass a -run parameter if you want, which will be passed through to go generate to filter
# which commands are run.
# Usage: gogen [-run "pattern"] [<directory>] (while inside the stackrox repo).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

gitroot="$(git rev-parse --show-toplevel)"

if [[ -f "${gitroot}/go.mod" ]]; then
  export GO111MODULE=on
fi

export PATH="$PATH:${gitroot}/tools/generate-helpers"

positional_args=()
run=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -run)
      run=(-run "$2")
      shift # past argument
      shift # past value
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

private_gogen() {
  target_dir=$1
  echo "Generating for ${target_dir}"
  ( cd "$target_dir" && go generate "${run[@]}" "./..." )
}


set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

set -x

if [[ "$#" -eq 0 ]]; then
  # Default argument is current working directory.
  set -- .
fi

for dir in "$@"; do
  private_gogen "${dir}"
done
