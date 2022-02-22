#!/usr/bin/env bash

# Curls StackRox central at the endpoint specified. If you
# don't supply a fully qualified URL, assumes that central is
# port-forwarded to localhost:8000 or that ROX_BASE_URL is set.
#
# Uses ROX_API_TOKEN for authentication. If not set,
# it reads the default admin password from standard deploy.sh
# in either deploy/openshift/central-deploy/password, if 
# ROX_ORCHESTRATOR_PLATFORM is openshift or deploy/k8s/central-deploy/password
# if unset or set of k8s
#
# For historical reasons, will consider ROX_AUTH_TOKEN if ROX_API_TOKEN is not set.
# The latter is compatible with roxctl and preferred.
#
# Example usage: roxcurl v1/imageIntegrations

set -eu

pushd >/dev/null "$(dirname "$(python3 -c "import os; print(os.path.realpath('$0'))")")"
source "../../lib/common.sh"
source "../../lib/rox_password.sh"
popd >/dev/null

: ${ROX_BASE_URL:=https://localhost:8000}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 url [curl options...]"
    exit 2
fi

url="$1"
shift

if [[ ! "$url" =~ ^https?:// ]]; then
	url="${ROX_BASE_URL%/}/${url#/}"
fi

auth=()
token="${ROX_API_TOKEN:-${ROX_AUTH_TOKEN:-}}"
if [[ -z "${token}" ]]; then
	auth=(-u "admin:$(must_rox_admin_password)")
else
    auth=(-H "Authorization: Bearer ${token}")
fi

curl -sSk "${auth[@]}" "$url" "$@"
