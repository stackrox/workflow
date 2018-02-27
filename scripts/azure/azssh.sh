#!/usr/bin/env bash

# Establishes an SSH connection to the (running) Azure dev VM.
# If your id file is NOT stored in the default ~/.ssh/id_rsa location,
# you will need to specify it in your config file.
#
# Usage:
#  azssh                Enters a login shell on the dev VM. If the configuration
#                       is set up to use tmux, will enter a tmux session.
#  azssh <command...>   Runs <command...> on the dev VM.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/azure.sh"

check_az_dev_vm || die "No or incorrect Azure dev VM config found"

cmd=(ssh -i "${AZ_DEV_VM_ID_FILE}" "${AZ_DEV_VM_USER}@${AZ_DEV_VM_DNS}")

if [[ $# == 0 && "$AZ_DEV_VM_USE_TMUX" == "true" ]]; then
	cmd+=("-t" "tmux a || tmux new")
else
	cmd+=("$@")
fi

"${cmd[@]}"
exit $?
