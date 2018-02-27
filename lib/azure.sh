#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/common.sh"

if [[ -f "$CONFIG_FILE" ]]; then
	AZ_DEV_VM_NAME="$(configq '.["dev-vm"].name // empty' 2>/dev/null)"
	AZ_DEV_VM_RG="$(configq '.["dev-vm"] | .["resource-group"] // .name + "-rg"' 2>/dev/null)"
	AZ_DEV_VM_USE_TMUX="$(configq '.["dev-vm"]["use-tmux"] // false' 2>/dev/null)"
	AZ_DEV_VM_ID_FILE="$(configq '.["dev-vm"]["id-file"] | select (. != null) | "'"$HOME"'/.ssh/" + .' 2>/dev/null)"
fi

function check_az() {
	[[ -x "$(command -v az)" ]] || { eerror "Azure CLI binary 'az' not found"; return 1; }
	local az_account_file="$(workfile azure/account.json 'az account show')"
	[[ "$(jq <"$az_account_file" -r '.state // empty' 2>/dev/null)" == "Enabled" ]] || { eerror "Not logged into an Azure account"; return 1; }
	return 0
}

function check_az_dev_vm() {
	check_az || return 1
	[[ -f "$CONFIG_FILE" ]] || { eerror "Config file ${CONFIG_FILE} not found"; return 1; }
	[[ -n "$AZ_DEV_VM_NAME" ]] || { eerror "Config file ${CONFIG_FILE} does not define a development VM name"; return 1; }
	local az_dev_vm_file="$(workfile azure/dev-vm-with-dns.json "az vm show -d -g '$AZ_DEV_VM_RG' -n '$AZ_DEV_VM_NAME'")"
	[[ $? -eq 0 && -n "$az_dev_vm_file" ]] || { eerror "Couldn't get information about Azure dev VM"; return 1; }
	AZ_DEV_VM_USER="$(jq -r <"${az_dev_vm_file}" '.osProfile.adminUsername // empty' 2>/dev/null)"
	AZ_DEV_VM_DNS="$(jq -r <"${az_dev_vm_file}" '.fqdns // empty' 2>/dev/null)"
	[[ -n "$AZ_DEV_VM_DNS" && -n "$AZ_DEV_VM_USER" ]] || { eerror "Dev VM '${AZ_DEV_VM_NAME}' in resource group '${AZ_DEV_VM_RG}' not found"; return 1; }
	return 0
}
