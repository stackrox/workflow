#!/usr/bin/env bash

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

az vm deallocate -n "$AZ_DEV_VM_NAME" -g "$AZ_DEV_VM_RG" "$@"
exit $?
