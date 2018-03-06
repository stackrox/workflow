#!/usr/bin/env bash

# Performs a copy via SSH connection to/from the (running) Azure dev VM.
# If your id file is NOT stored in the default location,
# you will need to specify it in your config file.
# Files on the remote are referenced by prepending a colon (:) to their path,
# e.g., `azscp :~/test.txt .`.
#
# Usage:
#  azscp [:]<source1> [...] [:]<dest>

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

base_cmd=(scp)
[[ -n "${AZ_DEV_VM_ID_FILE}" ]] && base_cmd+=(-i "${AZ_DEV_VM_ID_FILE}")

args=("$@")

# Rewrite args, appending the remote user@host to each argument starting with :
for idx in "${!args[@]}"; do
	arg="${args[$idx]}"
	if [[ "$arg" == :* ]]; then
		arg="${AZ_DEV_VM_USER}@${AZ_DEV_VM_DNS}$arg"
		args[$idx]="$arg"
	fi
done

"${base_cmd[@]}" "${args[@]}"
