#!/usr/bin/env bash

# Curls the StackRox director at the endpoint specified.
# Assumes that you have an authenticated roxc running, and that you have ROX_DIRECTOR_IP set.
# Example usage: roxcurl v1/ml/status

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]]; then
	[[ -n "$ROX_DIRECTOR_IP" ]] || die "ROX_DIRECTOR_IP is not set"
	url="https://${ROX_DIRECTOR_IP}/${url#/}"
fi

curl -sSk -H "Authorization: $(roxc auth export)" "$url" "$@"
