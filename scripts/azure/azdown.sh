#!/usr/bin/env bash

# Shuts down the Azure dev VM and deallocates it.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

az vm deallocate -n "$AZ_DEV_VM_NAME" -g "$AZ_DEV_VM_RG" "$@"
exit $?
