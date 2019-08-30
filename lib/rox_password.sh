#!/usr/bin/env bash

pushd >/dev/null "$(dirname "$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")")"
source "common.sh"
popd >/dev/null

unset _cache__rox_admin_password

rox_admin_password() {
	if [[ -z "${_cache__rox_admin_password:-}" ]]; then
		local pw
		pw="$(_get_rox_admin_password)"
		if [[ $? -ne 0 ]]; then
			return 1
		fi
		_cache__rox_admin_password="$pw"
	fi
	echo "${_cache__rox_admin_password}"
}

must_rox_admin_password() {
	if ! rox_admin_password ; then
		die "Failed to determine Rox admin password"
	fi
}

_get_rox_admin_password() {
	if [[ -n "${ROX_ADMIN_PASSWORD:-}" ]]; then
		echo "$ROX_ADMIN_PASSWORD"
		return
    fi

    local orch="${ROX_ORCHESTRATOR_PLATFORM-k8s}"

	if [[ "$orch" != k8s && "$orch" != openshift ]]; then
		eerror "Invalid value for environment variable ROX_ORCHESTRATOR_PLATFORM: ${ROX_ORCHESTRATOR_PLATFORM-}. Valid values are 'k8s' and 'openshift'."
    	return 2
    fi

    : ${ROX_DIR:=${GOPATH?${HOME}/go}/src/github.com/stackrox/rox}
	password_file="${ROX_DIR}/deploy/${orch}/central-deploy/password"

	if [[ ! -f "$password_file" ]]; then
		eerror "No password file found at ${password_file}, and no password specified via the ROX_ADMIN_PASSWORD environment variable."
		return 1
	fi

	cat "$password_file"
}
