#!/usr/bin/env bash

# Get the last docker image which is available locally for a given service.
# By default it displays the main image.
# roxlatestimage <SERVICE_NAME>
#
# Display time since build:
# $ ./get-last-build.sh main --tag-only
# 3.0.52.x-119-gdc18408bd7-dirty

format_ref="{{.Repository}}:{{.Tag}}"
image="main"

for arg in "$@"; do
  case "$arg" in
  main|collector|docs|scanner|scanner-db|roxctl)
    image="$arg"
    shift
    ;;
  --tag-only)
    format_ref="{{.Tag}}"
    shift
    ;;
  *)
    echo >&2 "Invalid argument $arg"
    exit 1
  esac
done

result=$(docker images --filter="reference=stackrox/$image" --format "${format_ref}" | head -1)
if [[ -z "$result" ]]; then
  >&2 echo "either '${image}' is an invalid image name, or the image has never been built locally."
  exit 1
fi

echo "$result"
