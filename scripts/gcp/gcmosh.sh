#!/usr/bin/env bash

# Establishes an interactive session to the (running) GCP Dev VM instance via mosh

# Usage:
#  gcmosh               Enters a login shell on the dev VM using mosh.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/gcp.sh"

check_gcp_dev_vm || die "No or incorrect GCP dev VM config found"

GCP_DEV_VM_EXTIP=$(gcloud --verbosity=none --format='value(networkInterfaces[0].accessConfigs[0].natIP)' compute instances list --filter="name=('${GCP_DEV_VM_NAME}') zone:(${GCP_DEV_VM_ZONE})")

[[ -n "$GCP_DEV_VM_EXTIP" ]] || { eerror "GCP VM ${GCP_DEV_VM_NAME} does not have external IP."; exit 1; }

cmd=(mosh ${GCP_DEV_VM_EXTIP})

"${cmd[@]}"

exit $?
