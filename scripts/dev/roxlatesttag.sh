#!/usr/bin/env bash

# Get the last docker tag which is locally available.
# By default it displays the main image.
# roxlatesttag <SERVICE_NAME>

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
DIR="$(dirname "$SCRIPT")"

image=$1
if [ -z "$1" ]; then
  image="main"
fi

"${DIR}"/roxlatestimage.sh "$image" --tag

