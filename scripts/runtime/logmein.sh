#!/usr/bin/env bash

# Opens a browser, logging you in as the same user that `roxcurl` uses.
# If an argument is given, this will be used as the Central endpoint to connect
# to. The scheme prefix is optional, defaulting to `https://`. If no argument is
# given, the endpoint derived from ROX_BASE_URL is used, with a default value
# of `https://localhost:8000`.
# If ROX_AUTH_TOKEN is set, this auth token is used as the identity for logging
# in the user. Otherwise, ROX_ADMIN_PASSWORD is used as the local administrator
# password. If neither is set, this script will attempt to extract the password
# from the current deployment in the same way as roxcurl.
#
# Example usages:
#   logmein
#   logmein prevent.stackrox.com
#   logmein http://localhost:8001/

set -euo pipefail

pushd >/dev/null "$(dirname "$(python -c "import os; print(os.path.realpath('$0'))")")"
source "../../lib/common.sh"
source "../../lib/rox_password.sh"
popd >/dev/null

: ${ROX_BASE_URL:=https://localhost:8000}

if [[ $# -eq 1 ]]; then
	ROX_BASE_URL="$1"
	if ! [[ "$ROX_BASE_URL" =~ ^https?:// ]]; then
		ROX_BASE_URL="https://${ROX_BASE_URL}"
	fi
elif [[ $# -ne 0 ]]; then
	die "Must specify at most one argument"
fi

ROX_BASE_URL="${ROX_BASE_URL%/}"

[[ "$ROX_BASE_URL" =~ ^https?://[a-zA-Z0-9_:\.-]+$ ]] || die "Malformed base URL: ${ROX_BASE_URL}"

target_url=""

if [[ -n "${ROX_AUTH_TOKEN:-}" ]]; then
	ROX_AUTH_TOKEN="${ROX_AUTH_TOKEN#Bearer }"
	curl -sSkf "${ROX_BASE_URL}/v1/auth/status" -H "Authorization: Bearer ${ROX_AUTH_TOKEN}" -o /dev/null || {
		die "Token in ROX_AUTH_TOKEN appears to be invalid for StackRox instance running at ${ROX_BASE_URL}"
	}

	target_url="${ROX_BASE_URL}/auth/response/generic#token=${ROX_AUTH_TOKEN}"
else
	password="$(must_rox_admin_password)"

	curl_status=0
	target_url="$(curl -sSkf -u "admin:${password}" -o /dev/null -w '%{redirect_url}' "${ROX_BASE_URL}/sso/providers/basic/4df1b98c-24ed-4073-a9ad-356aec6bb62d/challenge?micro_ts=0")" || curl_status=$?
	[[ "$curl_status" -eq 0 && -n "$target_url" ]] || die "Could not determine login URL for basic auth user"
fi

[[ -n "$target_url" ]] || die "UNEXPECTED: Could not determine target URL"
auth_error="$(sed -E '/^.*#error=([^&]+)(&.*)?$/!d;s//\1/' <<<"$target_url" | tr '+' ' ')"
[[ -z "$auth_error" ]] || die "Authentication error: ${auth_error}"

einfo "Logging you in via ${target_url} ..."
browse "$target_url"
