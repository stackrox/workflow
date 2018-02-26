#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"

ROX_WORKFLOW_BIN="$(dirname "$SCRIPT")/bin"
ROX_WORKFLOW_BIN="$(cd "$ROX_WORKFLOW_BIN"; pwd)"

# Export select Go environment variables with the GOENV prefix.
while read set_expr; do
	eval "GOENV_${set_expr}"
done < <(go env | egrep '^(GOROOT|GOBIN|GOPATH)=')

[[ -n "$GOENV_GOROOT" ]] && PATH="$PATH:${GOENV_GOROOT}"
[[ -n "$GOENV_GOBIN" ]] && PATH="$PATH:${GOENV_GOBIN}"
PATH="$PATH:${ROX_WORKFLOW_BIN}"
export PATH

# As we change the pwd, this must be a function and can't be a standalone
# script.
function cdrox() {
	[[ -n "$GOENV_GOPATH" ]] || { echo >&2 "GOPATH could not be determined"; return 1; }
	cd "${GOENV_GOPATH}/src/bitbucket.org/stack-rox/stackrox"
}
