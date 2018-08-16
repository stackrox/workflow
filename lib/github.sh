#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/common.sh"
source "$(dirname "$SCRIPT")/git.sh"

if [[ -f "$CONFIG_FILE" ]]; then
  GITHUB_TOKEN="$(configq '.github_token // empty')"
fi

function check_github_config() {
  [[ -f "${CONFIG_FILE}" ]] || { eerror "You need to add a config file for this to work."; return 1; }
  [[ -n "${GITHUB_TOKEN}" ]] || { eerror "Couldn't read github token from config file."; return 1; }
}

function private_ghcurl() {
  check_github_config || die "Please set/update your GitHub config."


  local query_url=$1
  [[ -n "${query_url}" ]] || die "Empty query url provided"
  curl -sS -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/${query_url}"
}

function private_get_github_pr_info() {
  check_github_config || die "Please set/update your GitHub config."
  local branch
  branch="$(get_current_branch)"
  [[ -n "${branch}" ]] || die "Couldn't find current branch. Are you in a repository?"

  local github_repo
  github_repo="$(get_user_slash_repo)"
  [[ -n "${github_repo}" ]] || die "Couldn't figure out which github repo we're in."

  local query_url="repos/${github_repo}/pulls?head=${github_repo%/*}:${branch}"

  pr_info="$(private_ghcurl "${query_url}")"
  length="$(echo "${pr_info}" | jq 'length')"
  [[ "${length}" -eq 1 ]] || die "Did not find exactly one PR for current branch (found ${length} - ${pr_info})"
  echo ${pr_info} | jq '.[0]'
}

function get_branch_from_pr() {
  check_github_config || die "Please set/update your GitHub config."
  local pr_number="$1"
  [[ -n "${pr_number}" ]] || die "No PR number provided."

  local github_repo
  github_repo="$(get_user_slash_repo)"
  [[ -n "${github_repo}" ]] || die "Couldn't figure out which github repo we're in."
  local query_url="repos/${github_repo}/pulls/${pr_number}"
  local branch_name
  branch_name="$(private_ghcurl "${query_url}" | jq '.head.ref // empty' -r)"
  [[ -n "${branch_name}" ]] || die "Couldn't get the branch corresponding to PR number ${pr_number}"
  echo "${branch_name}"
}

function get_pr_title() {
  local pr_info
  pr_info="$(private_get_github_pr_info)"
  [[ -n "${pr_info}" ]] || die "Failed to get GitHub PR info for your current branch. Have you created a PR?"

  local title
  title="$(echo "${pr_info}" | jq '.title // empty' -r)"
  [[ -n "${title}" ]] || die "Couldn't get the PR title for your current branch. Have you created a PR?"

  echo "${title}"
}

function get_pr_number() {
  local pr_info
  pr_info="$(private_get_github_pr_info)"
  [[ -n "${pr_info}" ]] || die "Failed to get GitHub PR info for your current branch. Have you created a PR?"

  local number 
  number="$(echo "${pr_info}" | jq '.number // empty' -r)"
  [[ -n "${number}" ]] || die "Couldn't get the PR number for your current branch. Have you created a PR?"

  echo "${number}"
}

function get_pr_url() {
  local pr_info
  pr_info="$(private_get_github_pr_info)"
  [[ -n "${pr_info}" ]] || die "Failed to get GitHub PR info for your current branch. Have you created a PR?"

  local url
  url="$(echo "${pr_info}" | jq '.html_url // empty' -r)"
  [[ -n "${url}" ]] || die "Couldn't get the PR url for your current branch. Have you created a PR?"

  echo "${url}"
}

function get_branch_url() {
  local github_repo
  github_repo="$(get_user_slash_repo)"
  [[ -n "${github_repo}" ]] || die "Couldn't figure out which github repo we're in."

  local branch
  branch="$(get_current_branch)"
  [[ -n "${branch}" ]] || die "Couldn't find current branch. Are you in a repository?"

  local query_url="repos/${github_repo}/branches/${branch}"

  url="$(private_ghcurl "${query_url}" | jq '._links.html // empty' -r)"
  [[ -n "${url}" ]] || die "Couldn't get current branch info."
  echo "${url}"
}
