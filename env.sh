#!/usr/bin/env bash

# even though it says bash above, this file needs to be sourced, so it should be more friendly to
# other shells

# bash
SCRIPT="${BASH_SOURCE[0]}"

# zsh
if [[ -z "$SCRIPT" ]]; then
  # use zsh
  # (%) = path expand this value; %x = prompt string for current script file
  SCRIPT="${(%):-%x}"
fi

# something else? Please add support!
if [[ -z "$SCRIPT" ]]; then
  echo >&2 "$(tput bold)$(tput setaf 1)[FATAL] could not determine path of env.sh$(tput setaf 0)"
  return
fi

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$SCRIPT")"

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
