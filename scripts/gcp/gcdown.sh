#!/usr/bin/env bash

# Brings down the GCP dev VM.

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/gcp.sh"

check_gcp_dev_vm || die "No or incorrect GCP dev VM config found"

gcloud compute instances stop "${GCP_DEV_VM_NAME}" --project stackrox-dev --zone "${GCP_DEV_VM_ZONE}"
exit $?
