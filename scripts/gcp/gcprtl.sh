#!/usr/bin/env bash

# Brings up the portal of your Google Cloud Dev VM. Optionally pass the port as an argument (else, it defaults to 3000).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/gcp.sh"

check_gcp_dev_vm || die "No or incorrect GCP dev VM config found"

external_ip="$(gcloud compute instances describe "${GCP_DEV_VM_NAME}" --project stackrox-dev --zone "${GCP_DEV_VM_ZONE}" --format json | jq -r '.networkInterfaces[0].accessConfigs[0].natIP // empty')"
[[ -n "${external_ip}" ]] || die "Couldn't find the external IP of the GCP Dev VM. Is it running?"

port=$1
[[ -n "${port}" ]] || port=3000

browse "https://${external_ip}:${port}"

exit $?
