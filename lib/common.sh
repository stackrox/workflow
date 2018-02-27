#!/usr/bin/env bash

CONFIG_FILE="$HOME/.stackrox/workflow-config.json"

ROX_WORKFLOW_WORKDIR="$HOME/.roxworkflow-workdir"

bold="$(tput bold)"
reset="$(tput sgr0)"
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
red="$(tput setaf 1)"
black="$(tput setaf 0)"

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

# Gets the current branch.
function get_current_branch() {
  git branch | sed -n -e 's/^\* \(.*\)/\1/p'
}

function configq() {
  [[ -f "$CONFIG_FILE" ]] || return 1
  jsmin <"$CONFIG_FILE" | jq -r "$@"
}

function get_branch_from_pr() {
  [[ -n "$1" ]] || die "No PR number provided."
  [[ -f "$CONFIG_FILE" ]] || die "You need to add a config file for this to work."
  BITBUCKET_USERNAME="$(configq '.bitbucket.username // empty')"
  [[ -n "$BITBUCKET_USERNAME" ]] || die "Couldn't read bitbucket username from config file."
  BITBUCKET_PASSWORD="$(configq '.bitbucket.password // empty')"
  [[ -n "$BITBUCKET_PASSWORD" ]] || die "Couldn't read bitbucket password from config file."
  BITBUCKET_REPO="$(get_bitbucket_repo)"
  [[ -n "$BITBUCKET_REPO" ]] || die "Couldn't figure out which bitbucket repo we're in."

  QUERY_URL="https://api.bitbucket.org/2.0/repositories/"$BITBUCKET_REPO"/pullrequests/$1"
  BRANCH_NAME="$(curl -sS --user $BITBUCKET_USERNAME:$BITBUCKET_PASSWORD $QUERY_URL | jq '.source.branch.name // empty' -r)"
  [[ -n "$BRANCH_NAME" ]] || die "Couldn't get the branch corresponding to PR number $1"
  echo "$BRANCH_NAME"
}

function get_pr_number() {
  BRANCH="$(get_current_branch)"
  [[ -n "$BRANCH" ]] || die "Couldn't find current branch. Are you in a repository?"
  [[ -f "$CONFIG_FILE" ]] || die "You need to add a config file for this to work."
  BITBUCKET_USERNAME="$(configq '.bitbucket.username // empty')"
  [[ -n "$BITBUCKET_USERNAME" ]] || die "Couldn't read bitbucket username from config file."
  BITBUCKET_PASSWORD="$(configq '.bitbucket.password // empty')"
  [[ -n "$BITBUCKET_PASSWORD" ]] || die "Couldn't read bitbucket password from config file."
  BITBUCKET_REPO="$(get_bitbucket_repo)"

  QUERY_URL=https://api.bitbucket.org/2.0/repositories/"$BITBUCKET_REPO"/pullrequests
  JQ_GET_BRANCHES=".values | [.[] | {isbranch: ({id: .id, branch: .source.branch.name} | .branch == \"$BRANCH\") , prnumber: .id} ]"
  JQ_FILTER_BRACHES=".[] | select(.isbranch == true) | .prnumber"
  found=0
  while [[ -n "$QUERY_URL" ]]; do
    CURL_OUT=`curl -sS --user $BITBUCKET_USERNAME:$BITBUCKET_PASSWORD $QUERY_URL`
    JQ_OUT=`echo $CURL_OUT | jq ''"$JQ_GET_BRANCHES"'' |  jq ''"$JQ_FILTER_BRACHES"''`
    if [ -n "$JQ_OUT" ]; then
      echo $JQ_OUT
      found=1
      break
    fi
    QUERY_URL=`echo $CURL_OUT | jq -r '.next // empty'`
  done

  [[ found -eq 1 ]] || die "Couldn't find the PR number for the current repo. Have you created a PR?"
}

function get_bitbucket_repo() {
  REMOTE=`git config --get remote.origin.url`
  [[ -n "$REMOTE" ]] || die "Couldn't find the remote."

  if [[ "$REMOTE" = git* ]]; then
    REMOTE=`echo ${REMOTE#git@} | tr : /`
  fi

  if [[ "$REMOTE" = *.git ]]; then
    REMOTE=${REMOTE%%.git}
  fi

  [[ "$REMOTE" = bitbucket.org/* ]] || die "Remote $REMOTE is not on Bitbucket"
  REMOTE=${REMOTE#bitbucket.org/}
  [[ -n "$REMOTE" ]] || die "Couldn't find the remote."
  echo $REMOTE
}

function browse() {
  local platform="$(uname)"
  if [[ "$platform" == "Linux" ]]; then
    xdg-open "$@" >/dev/null
  elif [[ "$platform" == "Darwin" ]]; then
    open "$@"
  else
    eecho "Unsupported platform '$platform', please open $@ in a browser"
  fi
}

function clipboard_copy() {
  local platform="$(uname)"
  if [[ "$platform" == "Linux" ]]; then
    xclip -selection c
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
  einfo "$prompt"
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
