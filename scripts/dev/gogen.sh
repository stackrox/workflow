#!/usr/bin/env bash

# Runs go generate rooted at the current working directory, but with the PATH expected for mockgen-wrapper to work.
# Usage: gogen (while inside the rox repo).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

gitroot="$(git rev-parse --show-toplevel)"

PATH="$PATH:${gitroot}/tools/generate-helpers" go generate ./...
