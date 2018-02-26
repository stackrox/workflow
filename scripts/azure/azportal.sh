#!/usr/bin/env bash

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

ssh "${AZ_DEV_VM_USER}@${AZ_DEV_VM_NAME}.${AZ_DEV_VM_ZONE}.cloudapp.azure.com" 'cat ~/.roxc/config | jq -r .token' | clipboard_copy
browse "https://${AZ_DEV_VM_NAME}.${AZ_DEV_VM_ZONE}.cloudapp.azure.com:3000/auth/login"
exit $?
