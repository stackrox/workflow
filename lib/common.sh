#!/usr/bin/env bash

# Use CONFIG_HOME if it exists. Otherwise follow XDG base directory specification.
CONFIG_HOME="${HOME}/.stackrox/workflow-config.json"
if [ -f "${CONFIG_HOME}" ]; then
	CONFIG_FILE="${CONFIG_HOME}"
else
	XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
	CONFIG_FILE="${XDG_CONFIG_HOME}/stackrox/workflow-config.json"
fi

# Use WORKDIR_HOME if it exists. Otherwise follow XDG base directory specification.
WORKDIR_HOME="${HOME}/.roxworkflow-workdir"
if [ -d "${WORKDIR_HOME}" ]; then
	ROX_WORKFLOW_WORKDIR="${WORKDIR_HOME}"
else
	XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
	ROX_WORKFLOW_WORKDIR="${XDG_CACHE_HOME}/stackrox"
fi

PYTHON_INTERPRETER="$(which python3)"

bold="$(tput bold)"
reset="$(tput sgr0)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
red="$(tput setaf 1)"
black="$(tput setaf 0; tput setab 7)"

function eecho() {
	echo >&2 "$@"
}

function einfo() {
    eecho -en "${bold}${green}[INFO]${black} "
	eecho -n "$@"
	eecho -e "$reset"
}

function ewarn() {
	eecho -en "${bold}${yellow}[WARN]${black} "
	eecho -n "$@"
	eecho -e "$reset"
}

function eerror() {
  eecho -en "${bold}${red}[ERROR]${black} "
  eecho -n "$@"
  eecho -e "$reset"
}
function efatal() {
  eecho -en "${bold}${red}[FATAL]${black} "
  eecho -n "$@"
  eecho -e "$reset"
}

function die() {
	efatal "$@"
	exit 1
}

function workfile() {
  local relpath="$1"
  local cmd="$2"
  local fullpath="${ROX_WORKFLOW_WORKDIR}/${relpath}"
  if [[ ! -f "$fullpath" || $(ls -s "$fullpath" | awk '{print$1}') -eq 0 ]]; then
    mkdir -p "$(dirname "$fullpath")" 2>/dev/null
    rm -f "$fullpath" 2>/dev/null
    "$SHELL" -c "$cmd" >"$fullpath" || return 1
  fi
  echo "$fullpath"
}

function get_workfile_path_and_ensure_dir() {
  local relpath="$1"
  [[ -n "${relpath}" ]] || return 1
  local fullpath="${ROX_WORKFLOW_WORKDIR}/${relpath}"
  mkdir -p "$(dirname "${fullpath}")"
  echo "${fullpath}"
}

function strip_comments() {
  sed 's@//.*$@@'
}

function configq() {
  [[ -f "$CONFIG_FILE" ]] || return 1
  strip_comments <"$CONFIG_FILE" | jq -r "$@"
}

function browse() {
  local platform="$(uname)"
  if [[ "$platform" == "Linux" ]]; then
    xdg-open "$@" >/dev/null &
  elif [[ "$platform" == "Darwin" ]]; then
    open "$@" &
  else
    eecho "Unsupported platform '$platform', please open $@ in a browser"
  fi
}

function clipboard_copy() {
  local platform="$(uname)"
  if [[ "$platform" == "Linux" ]]; then
    xsel -i -pb
  elif [[ "$platform" == "Darwin" ]]; then
    pbcopy
  else
    eecho "Unsupported platform '$platform'"
  fi
}

# yes_no_prompt "<message>" displays the given message and prompts the user to
# input 'yes' or 'no'. The return value is 0 if the user has entered 'yes', 1
# if they answered 'no', and 2 if the read was aborted (^C/^D) or no valid
# answer was given after three tries.
function yes_no_prompt() {
  local prompt="$1"
  local tries=0
  [[ -z "$prompt" ]] || einfo "$prompt"
  local answer=""
  while (( tries < 3 )) && { echo -n "Type 'yes' or 'no': "; read answer; } ; do
    answer="$(echo "$answer" | tr '[:upper:]' '[:lower:]')"
    [[ "$answer" == "yes" ]] && return 0
    [[ "$answer" == "no" ]] && return 1
    tries=$((tries + 1))
  done
  echo "Aborted."
  return 2
}
