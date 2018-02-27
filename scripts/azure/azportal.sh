#!/usr/bin/env bash

# Opens the StackRox portal running on the Azure dev VM in a browser.
# The authentication token will be copied to the clipboard in the background.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

ssh "${AZ_DEV_VM_USER}@${AZ_DEV_VM_DNS}" 'cat ~/.roxc/config' | jq -r .token | clipboard_copy
browse "https://${AZ_DEV_VM_DNS}:3000/auth/login"
exit $?
