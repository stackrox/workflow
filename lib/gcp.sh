#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/common.sh"

if [[ -f "$CONFIG_FILE" ]]; then
	GCP_DEV_VM_NAME="$(configq '.["gcp-dev-vm"].name // empty' 2>/dev/null)"
	GCP_DEV_VM_ZONE="$(configq '.["gcp-dev-vm"].zone // empty' 2>/dev/null)"
	GCP_DEV_VM_USE_TMUX="$(configq '.["gcp-dev-vm"]["use-tmux"] // false' 2>/dev/null)"
fi

function check_gcp() {
	[[ -x "$(command -v gcloud)" ]] || { eerror "Google Cloud binary 'gcloud' not found"; return 1; }
	local tempfile="$(mktemp)"
	local account
	account="$(gcloud config get-value account 2>"${tempfile}")"
	[[ "$?" -eq 0 ]] || { eerror "Error getting gcloud info"; cat >&2 "${tempfile}"; rm "${tempfile}"; return 1; }
	rm "${tempfile}"
	[[ -n "${account}" ]] || { eerror "Please use gcloud auth login to log in to your StackRox account"; return 1; }
	[[ $account =~ ^.*@stackrox.com$ ]] || { eerror "Google Cloud account was ${account} which is not @stackrox.com"; return 1; }
	return 0
}

function check_gcp_dev_vm() {
	check_gcp || return 1
	[[ -f "$CONFIG_FILE" ]] || { eerror "Config file ${CONFIG_FILE} not found"; return 1; }
	[[ -n "$GCP_DEV_VM_NAME" ]] || { eerror "Config file ${CONFIG_FILE} does not define a development VM name"; return 1; }
	[[ -n "$GCP_DEV_VM_ZONE" ]] || { eerror "Config file ${CONFIG_FILE} does not define a zone for the development VM"; return 1; }
	return 0
}
