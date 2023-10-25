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

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$SCRIPT")"

ROX_WORKFLOW_BIN="$(dirname "$SCRIPT")/bin"
ROX_WORKFLOW_BIN="$(cd "$ROX_WORKFLOW_BIN"; pwd)"

# Export select Go environment variables with the GOENV prefix.
while read set_expr; do
	eval "GOENV_${set_expr}"
done < <(go env | grep -E '^(GOROOT|GOBIN|GOPATH)=')

[[ -n "$GOENV_GOROOT" ]] && PATH="$PATH:${GOENV_GOROOT}"
[[ -n "$GOENV_GOBIN" ]] && PATH="$PATH:${GOENV_GOBIN}"
PATH="$PATH:${ROX_WORKFLOW_BIN}"
export PATH

# As we change the pwd, this must be a function and can't be a standalone
# script.
function cdrox() {
	[[ -n "$GOENV_GOPATH" ]] || { echo >&2 "GOPATH could not be determined"; return 1; }
	# if an arg is provided, attempt to cd into that directory,
	# defaulting to stackrox.
	repo="${1:-stackrox}"
	cd "${GOENV_GOPATH}/src/github.com/stackrox/${repo}"
}

# This is a completion function for the stackrox directory, giving any repository
# directories within to complete the cdrox function
function _cdrox_comp() {
	[[ -n "$GOENV_GOPATH" ]] || return
	[[ -d "${GOENV_GOPATH}/src/github.com/stackrox/" ]] || return
	COMPREPLY=($(cd "${GOENV_GOPATH}/src/github.com/stackrox/" && compgen -d))
}

# registers the completion function with the cdrox function we wish to complete
complete -F _cdrox_comp cdrox

# The following modify the KUBECONFIG environment variable, so they need to be functions, not scrips.

# Save the active kubernetes configuration in a named file (named either after the first argument, or, if empty,
# after the setup name) and make it sticky for the current session.
function save-kubecfg() {
	local cfgname="$1"
	local src_config="$HOME/.kube/config"
	[[ -f "$src_config" ]] || { echo >&2 "Config file $src_config not found."; return 1; }
	if [[ -z "$cfgname" ]]; then
		cfgname="$(echo "$ROX_SETUP_NAME" | sed -E 's/[[:space:]]*:[^:]+:[[:space:]]*//g')"
	fi
	[[ -n "$cfgname" ]] || {
		echo >&2 "Could not determine name under which to save config. Use '$0 <config-name>' or set the ROX_SETUP_NAME variable"
		return 1
	}
	local configs_dir="$HOME/.kube/saved-configs"
	mkdir -p "$configs_dir" || { echo >&2 "Failed to create $configs_dir directory."; return 1; }
	local target_config="$configs_dir/$cfgname"
	cp "$src_config" "$target_config" || { echo >&2 "Failed to save config as $target_config."; return 1; }
	export KUBECONFIG="$target_config"
	echo "Saved current kubernetes config as $cfgname and persisted in session."
	return 0
}

# Load a named kubernetes configuration and make it sticky for the current session.
function load-kubecfg() {
	local cfgname="$1"
	[[ -n "$cfgname" ]] || { echo >&2 "Usage: $0 <config-name>"; return 1; }
	local src_config="$HOME/.kube/saved-configs/$cfgname"
	[[ -f "$src_config" ]] || { echo >&2 "Configuration $cfgname not found."; return 1; }
	export KUBECONFIG="$src_config"
	echo "Restored kubernetes config $cfgname and persisted in session."
	return 0
}
