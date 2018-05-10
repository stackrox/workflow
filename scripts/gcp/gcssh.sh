#!/usr/bin/env bash

# Establishes an SSH connection to the (running) GCP Dev VM instance.

# Usage:
#  gcssh                Enters a login shell on the dev VM. If the configuration
#                       is set up to use tmux, will enter a tmux session.
#  gcssh <command...>   Runs <command...> on the dev VM.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/gcp.sh"

check_gcp_dev_vm || die "No or incorrect GCP dev VM config found"

cmd=(gcloud compute ssh "${GCP_DEV_VM_NAME}" --project stackrox-dev --zone "${GCP_DEV_VM_ZONE}")

if [[ $# -eq 0 && "${GCP_DEV_VM_USE_TMUX}" == "true" ]]; then
	cmd+=("--" "-t" "tmux a || tmux new")
elif [[ $# -gt 0 ]]; then
	cmd+=("--" "-T" "$@")
fi

"${cmd[@]}"

exit $?
