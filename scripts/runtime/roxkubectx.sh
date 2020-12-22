#!/usr/bin/env bash

# A `kubectl config current-context` wrapper that is aware of setup names.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

curr_context="$(kubectl config current-context)"
[[ -n "${curr_context}" ]] || die "Couldn't determine current context"

workfile_for_context="$(get_workfile_path_and_ensure_dir kubectx)"
[[ -n "${workfile_for_context}" ]] || die "Coudn't get workfile"

if [[ -f "${workfile_for_context}" ]]; then
    cached_context="$(jq --arg context "${curr_context}" '.[$context] // empty' -r <"${workfile_for_context}")"
fi
if [[ -n "${cached_context}" ]]; then
    echo "${cached_context}"
    exit 0
fi

[[ -n "{PYTHON_INTERPRETER}" ]] || die "No Python interpreter found"
"${PYTHON_INTERPRETER}" "$(dirname "$SCRIPT")/setup_id_to_name.py" "${curr_context}" "${workfile_for_context}"
