#!/usr/bin/env bash

# Get the last docker image which is available locally for a given service.
# By default it displays the main image.
# roxlatestimage <SERVICE_NAME>
#
# Display time since build:
# $ ./get-last-build.sh main --since
# stackrox/main:3.0.52.x-119-gdc18408bd7-dirty 	 14 minutes ago
#
# Use custom formatting:
# $ ./get-last-build.sh roxctl "\t {{.CreatedAt}} \t {{.ID}}"
# stackrox/roxctl:3.0.52.x-91-g821f85d9b5 	 2020-12-07 11:49:54 +0100 CET 	 b4747e98e95c

image=$1
if [ -z "$1" ]; then
  image="main"
fi

format="{{.Repository}}:{{.Tag}} ${2}"
if [[ "$2" == "--since" ]]; then
  format="{{.Repository}}:{{.Tag}}\t {{.CreatedSince}}"
fi
if [[ "$2" == "--tag" ]]; then
  format="{{.Tag}}"
fi

result=$(docker images --filter="reference=stackrox/$image" --format "${format}" | head -1)
if [[ -z "$result" ]]; then
  >&2 echo "either '${image}' is an invalid image name, or the image has never been built locally."
  exit 1
fi

echo "$result"
