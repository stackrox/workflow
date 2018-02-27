#!/usr/bin/env bash

# Merge the PR to the target branch (develop, in the case of the stackrox repo), after checking that you've rebased and squashed.
# Usage: shipit (with your branch checked out, after rebasing and squashing).

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/bitbucket.sh"

check_bitbucket_config || die "Please set/update your bitbucket configs."

git diff-index --quiet HEAD || die "Current working tree is not clean. Aborting..."

bitbucket_repo="$(get_bitbucket_repo)"
[[ -n "$bitbucket_repo" ]] || die "Couldn't get the bitbucket repo."

pr_number="$(get_pr_number)"
[[ -n "$pr_number" ]] || die "Couldn't get the current PR number."

pr_curl_out="$(curl -sS --user "${BITBUCKET_USERNAME}:${BITBUCKET_PASSWORD}" "https://api.bitbucket.org/2.0/repositories/${bitbucket_repo}/pullrequests/${pr_number}")"
target_branch="$(jq -r '.destination.branch.name' <<< "${pr_curl_out}")"
[[ -n "${target_branch}" ]] || die "Couldn't determine the target branch."

author="$(jq -r '.author.username' <<< "${pr_curl_out}")"
[[ -n "${author}" ]] || die "Couldn't determine the author of the PR."
if [[ "${author}" != "${BITBUCKET_USERNAME}" ]]; then
  yes_no_prompt "The PR's author is ${author}, but you are ${BITBUCKET_USERNAME}. Are you sure you want to continue?" || die "Aborting, like you asked me to."
fi

if [[ "${target_branch}" != "develop" ]]; then
  yes_no_prompt "Your PR's target branch is ${target_branch}, NOT develop. Are you sure you want to continue?" || die "Aborting, like you asked me to."
fi

feature_branch="$(get_current_branch)"
[[ -n "$feature_branch" ]] || die "Coudn't find the current branch."

IFS=$'\n' read -a approvers -d '' < <(jq -r '.participants | .[] | select(.approved == true) | .user.display_name' <<< "${pr_curl_out}")
[[ "${#approvers[@]}" -gt 0 ]] || die "Noone has approved the PR! Aborting..."

all_approved="$(jq -r '[.participants | .[] | select(.role == "REVIEWER") | .approved] | all' <<< "${pr_curl_out}")"
if [[ "${all_approved}" != "true" ]]; then
  yes_no_prompt "Your PR has NOT been approved by all the reviewers tagged. Are you sure you want to continue?" || die "Aborting, like you asked me to."
fi
einfo "Approved by:"
for approver in "${approvers[@]}"; do echo "  $approver"; done

git fetch || die "git fetch failed"

[[ "$(git rev-parse "${feature_branch}")" == "$(git rev-parse "origin/${feature_branch}")" ]] || die "Please update the remote of your branch before shipping."

git checkout "${target_branch}" || die "Couldn't checkout ${target_branch}"
git pull || { git checkout "${feature_branch}"; die "Couldn't pull ${target_branch}. Aborting..."; }

[[ "$(git rev-parse "${feature_branch}^")" == "$(git rev-parse HEAD)" ]] || { git checkout "${feature_branch}"; die "Please squash your commits! Aborting..."; }


git merge --ff-only "${feature_branch}" || { git checkout "${feature_branch}"; die "Something went wrong. Have you rebased? Aborting..."; }
git push origin ${target_branch} || { git checkout "${feature_branch}"; die "Something went wrong. Aborting. You may want to check your local ${target_branch}..."; }

einfo "PR merged successfully, now deleting the remote branch. (Your local copy will be left intact.)"
git push -d origin "${feature_branch}"
