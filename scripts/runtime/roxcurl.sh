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

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

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
    if [[ -n "${ROX_ADMIN_PASSWORD:-}" ]]; then
        auth=(-u "admin:${ROX_ADMIN_PASSWORD}")
    else
        : ${ROX_DIR:=${GOPATH?${HOME}/go}/src/github.com/stackrox/rox}
        
        password_file="${ROX_DIR}/deploy/${ROX_ORCHESTRATOR_PLATFORM-k8s}/central-deploy/password"
        
        if [[ "${ROX_ORCHESTRATOR_PLATFORM-k8s}" != k8s && "${ROX_ORCHESTRATOR_PLATFORM-k8s}" != openshift ]]; then
        	echo "Invalid value for environment variable ROX_ORCHESTRATOR_PLATFORM: ${ROX_ORCHESTRATOR_PLATFORM-}. Valid values are 'k8s' and 'openshift'." >&2
    	exit 2
        fi
      
        if [[ -f "${password_file}" ]]; then
    	auth=(-u "admin:$(cat "${password_file}")")
        fi
    fi
else
    auth=(-H "Authorization: Bearer ${token}")
fi

curl -sSk "${auth[@]}" "$url" "$@"
