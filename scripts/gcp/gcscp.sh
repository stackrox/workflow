#!/usr/bin/env bash

# Performs a copy via SSH connection to/from the (running) GCP dev VM.
# Files on the remote are referenced by prepending a colon (:) to their path,
# e.g., `gcscp :~/test.txt .`.
#
# Usage:
#  gcscp [:]<source1> [...] [:]<dest>

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/gcp.sh"

check_gcp_dev_vm || die "No or incorrect GCP dev VM config found"

args=("$@")

# Rewrite args, pre-pending the dev VM name to each argument starting with :
for idx in "${!args[@]}"; do
	arg="${args[$idx]}"
	if [[ "$arg" == :* ]]; then
		arg="${GCP_DEV_VM_NAME}$arg"
		args[$idx]="$arg"
	fi
done

gcloud compute scp --project stackrox-dev --zone "${GCP_DEV_VM_ZONE}" "${args[@]}"
