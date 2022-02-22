#!/usr/bin/env bash

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/git.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  BITBUCKET_USERNAME="$(configq '.bitbucket.username // empty')"
  BITBUCKET_PASSWORD="$(configq '.bitbucket.password // empty')"
fi

function check_bitbucket_config() {
  [[ -f "${CONFIG_FILE}" ]] || { eerror "You need to add a config file for this to work."; return 1; }
  [[ -n "${BITBUCKET_USERNAME}" ]] || { eerror "Couldn't read bitbucket username from config file."; return 1; }
  [[ -n "${BITBUCKET_PASSWORD}" ]] || { error "Couldn't read bitbucket password from config file."; return 1; }
}

function private_get_bitbucket_branch_info() {
  check_bitbucket_config || die "Please set/update your bitbucket configs."
  local branch
  branch="$(get_current_branch)"
  [[ -n "${branch}" ]] || die "Couldn't find current branch. Are you in a repository?"

  local bitbucket_repo
  bitbucket_repo="$(get_user_slash_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo the remote is."

  local query_url="https://api.bitbucket.org/2.0/repositories/${bitbucket_repo}/pullrequests"
  local jq_extract_branch_info=".values | .[] | select(.source.branch.name == \"${branch}\") | {prnumber: .id, title: .title}"
  while [[ -n "${query_url}" ]]; do
    local curl_out
    curl_out="$(curl -sS --user "${BITBUCKET_USERNAME}:${BITBUCKET_PASSWORD}" "${query_url}")"
    local jq_out
    jq_out="$(echo "${curl_out}" | jq ''"${jq_extract_branch_info}"'')"
    [[ -n "${jq_out}" ]] && { echo "${jq_out}"; return 0; }
    query_url="$(echo "${curl_out}" | jq -r '.next // empty')"
  done
  return 1;
}


function get_branch_from_pr() {
  check_bitbucket_config || die "Please set/update your bitbucket configs."
  local pr_number="$1"
  [[ -n "${pr_number}" ]] || die "No PR number provided."

  local bitbucket_repo
  bitbucket_repo="$(get_user_slash_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo we're in."
  local query_url="https://api.bitbucket.org/2.0/repositories/${bitbucket_repo}/pullrequests/$1"
  local branch_name
  branch_name="$(curl -sS --user "${BITBUCKET_USERNAME}:${BITBUCKET_PASSWORD}" "${query_url}" | jq '.source.branch.name // empty' -r)"
  [[ -n "${branch_name}" ]] || die "Couldn't get the branch corresponding to PR number ${pr_number}"
  echo "${branch_name}"
}


function get_pr_title() {
  local bitbucket_branch_info
  bitbucket_branch_info="$(private_get_bitbucket_branch_info)"
  [[ -n "${bitbucket_branch_info}" ]] || die "Couldn't check the branch info from bitbucket for your current branch. Have you created a PR?"
  local title
  title="$(jq -r '.title' <<< "${bitbucket_branch_info}")"
  [[ -n "${title}" ]] || die "Couldn't get the PR title for your current branch. Have you created a PR?"
  echo "${title}"
}

function get_pr_number() {
  local bitbucket_branch_info
  bitbucket_branch_info="$(private_get_bitbucket_branch_info)"
  [[ -n "${bitbucket_branch_info}" ]] || die "Couldn't check the branch info from bitbucket for your current branch. Have you created a PR?"
  local pr_number
  pr_number="$(jq '.prnumber' <<< "${bitbucket_branch_info}")"
  [[ -n "${pr_number}" ]] ||  die "Couldn't find the PR number for the current repo. Have you created a PR?"
  echo "${pr_number}"
}

function get_pr_url() {
  local bitbucket_repo
  bitbucket_repo="$(get_user_slash_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo we're in."

  local pr_number
  pr_number="$(get_pr_number)"
  [[ -n "${pr_number}" ]] || die "Failed to get the PR number."

  echo "https://bitbucket.org/${bitbucket_repo}/pull-requests/${pr_number}"
}

function get_branch_url() {
  local bitbucket_repo
  bitbucket_repo="$(get_user_slash_repo)"
  [[ -n "${bitbucket_repo}" ]] || die "Couldn't figure out which bitbucket repo we're in."

  local branch
  branch="$(get_current_branch)"
  [[ -n "${branch}" ]] || die "Couldn't find current branch. Are you in a repository?"

  echo "https://bitbucket.org/${bitbucket_repo}/branch/${branch}"
}
