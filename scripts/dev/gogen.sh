#!/usr/bin/env bash

# Runs go generate rooted at the current working directory (or a directory specified as the first
# argument, if any), but with the PATH expected for mockgen-wrapper to work.
# Usage: gogen [<directory>] (while inside the rox repo).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

gitroot="$(git rev-parse --show-toplevel)"

target_dir="${1:-.}"

cd "$target_dir"
PATH="$PATH:${gitroot}/tools/generate-helpers" go generate "./..."
