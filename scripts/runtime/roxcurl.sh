#!/usr/bin/env bash

function die() {
	echo >&2 "$@"
	exit 1
}

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]]; then
	[[ -n "$ROX_DIRECTOR_IP" ]] || die "ROX_DIRECTOR_IP is not set"
	url="https://${ROX_DIRECTOR_IP}/${url#/}"
fi

curl -sSk -H "Authorization: $(roxc auth export)" "$url" "$@"
