#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/common.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  BITBUCKET_USERNAME="$(configq '.bitbucket.username // empty')"
  BITBUCKET_PASSWORD="$(configq '.bitbucket.password // empty')"
fi

# Gets the current branch.
function get_current_branch() {
  local ref
  ref="$(git symbolic-ref HEAD)"
  [[ "$ref" == refs/heads/* ]] || die "Current HEAD is not a branch head"
  echo "${ref#refs/heads/}"
}

function check_bitbucket_config() {
  [[ -f "${CONFIG_FILE}" ]] || { eerror "You need to add a config file for this to work."; return 1; }
  [[ -n "${BITBUCKET_USERNAME}" ]] || { eerror "Couldn't read bitbucket username from config file."; return 1; }
  [[ -n "${BITBUCKET_PASSWORD}" ]] || { error "Couldn't read bitbucket password from config file."; return 1; }
}

function get_branch_from_pr() {
  check_bitbucket_config || die "Please set/update your bitbucket configs."
  local pr_number="$1"
  [[ -n "${pr_number}" ]] || die "No PR number provided."

  local bitbucket_repo
  bitbucket_repo="$(get_bitbucket_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo we're in."
  local query_url="https://api.bitbucket.org/2.0/repositories/${bitbucket_repo}/pullrequests/$1"
  local branch_name
  branch_name="$(curl -sS --user "${BITBUCKET_USERNAME}:${BITBUCKET_PASSWORD}" "${query_url}" | jq '.source.branch.name // empty' -r)"
  [[ -n "${branch_name}" ]] || die "Couldn't get the branch corresponding to PR number ${pr_number}"
  echo "${branch_name}"
}

function get_pr_number() {
  check_bitbucket_config || die "Please set/update your bitbucket configs."
  local branch
  branch="$(get_current_branch)"
  [[ -n "${branch}" ]] || die "Couldn't find current branch. Are you in a repository?"

  local bitbucket_repo
  bitbucket_repo="$(get_bitbucket_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo the remote is."

  local query_url="https://api.bitbucket.org/2.0/repositories/${bitbucket_repo}/pullrequests"
  local jq_get_branches=".values | [.[] | {isbranch: ({id: .id, branch: .source.branch.name} | .branch == \"${branch}\") , prnumber: .id} ]"
  local jq_filter_branches=".[] | select(.isbranch == true) | .prnumber"
  while [[ -n "${query_url}" ]]; do
    local curl_out
    curl_out="$(curl -sS --user "${BITBUCKET_USERNAME}:${BITBUCKET_PASSWORD}" "${query_url}")"
    local jq_out
    jq_out="$(echo "${curl_out}" | jq ''"${jq_get_branches}"'' |  jq ''"${jq_filter_branches}"'')"
    [[ -n "${jq_out}" ]] && { echo "${jq_out}"; return; }
    query_url="$(echo "${curl_out}" | jq -r '.next // empty')"
  done

  die "Couldn't find the PR number for the current repo. Have you created a PR?"
}

function get_bitbucket_repo() {
  local remote
  remote="$(git config --get remote.origin.url)"
  [[ -n "${remote}" ]] || die "Couldn't find the remote."

  if [[ "${remote}" = git* ]]; then
    remote="$(echo "${remote#git@}" | tr : /)"
  fi

  if [[ "$remote" = *.git ]]; then
    remote="${remote%%.git}"
  fi

  [[ "${remote}" = bitbucket.org/* ]] || die "Remote ${remote} is not on Bitbucket"
  remote="${remote#bitbucket.org/}"
  [[ -n "${remote}" ]] || die "Couldn't find the remote."
  echo "${remote}"
}
