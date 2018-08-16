#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/common.sh"

# Gets the current branch.
function get_current_branch() {
  local ref
  ref="$(git symbolic-ref HEAD)"
  [[ "$ref" == refs/heads/* ]] || die "Current HEAD is not a branch head"
  echo "${ref#refs/heads/}"
}

function get_remote() {
  local remote
  remote="$(git config --get remote.origin.url)"
  [[ -n "${remote}" ]] || die "git config didn't return a remote."

  if [[ "${remote}" = git* ]]; then
    remote="$(echo "${remote#git@}" | tr : /)"
  fi

  if [[ "$remote" = *.git ]]; then
    remote="${remote%%.git}"
  fi
  echo "${remote}"
}

function bitbucket_or_github() {
  local remote
  remote="$(get_remote)"
  [[ -n "${remote}" ]] || die "Couldn't find the remote."

  if [[ "${remote}" = bitbucket.org/* ]]; then
    echo "bitbucket"
    return 0
  fi
  if [[ "${remote}" = github.com/* ]]; then
    echo "github"
    return 0
  fi
  die "Couldn't figure out if the remote is from bitbucket or Github"
}

# returns "stackrox/rox" from "github.com/stackrox/rox"
function get_user_slash_repo() {
  local remote
  remote="$(get_remote)"
  
  local service="$(bitbucket_or_github)"
  [[ -n "${service}" ]] || die "Only Bitbucket and GitHub are supported"

  if [[ "${service}" == "bitbucket" ]]; then
    echo "${remote#bitbucket.org/}"
    return 0
  fi
  if [[ "${service}" == "github" ]]; then
    echo "${remote#github.com/}"
    return 0
  fi

  die "Unsupported service ${service}"
}

function branch_exists() {
	[[ $# == 1 ]] || return 1
	local branch="$1"
	git show-ref --verify --quiet "refs/heads/$branch"
}
