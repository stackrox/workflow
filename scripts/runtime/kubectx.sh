#!/usr/bin/env bash

# A `kubectl config current-context` wrapper that is aware of setup names.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

curr_context="$(kubectl config current-context)"
[[ -n "${curr_context}" ]] || die "Couldn't determine current context"
workfile_for_context="$(get_or_create_workfile kubectx)"
[[ -n "${workfile_for_context}" ]] || die "Coudn't get workfile"

"$(dirname "$SCRIPT")/setup_id_to_name.py" "${curr_context}" "${workfile_for_context}"
