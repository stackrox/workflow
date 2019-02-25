#!/usr/bin/env bash

# Curls the StackRox director at the endpoint specified.
# Assumes that you have an authenticated roxc running, and that you have ROX_DIRECTOR_IP set.
# Example usage: roxcurl v1/ml/status

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

: ${rox_url:=https://localhost:8000}

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]]; then
	url="${rox_url%/}/${url#/}"
fi

auth=()
if [[ -z "${rox_token}" ]]; then
    : ${rox_dir:=${GOPATH?${HOME}/go}/src/github.com/stackrox/rox}
    password_file="${rox_dir}/deploy/k8s/central-deploy/password"
    if [[ -f "${password_file}" ]]; then
	auth=(-u "admin:$(cat "${password_file}")")
    fi
else
    auth=(-H "Authorization: Bearer ${rox_token}")
fi

curl -sSk "${auth[@]}" "$url" "$@"
