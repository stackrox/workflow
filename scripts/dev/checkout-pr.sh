#!/usr/bin/env bash

# Checks out the branch given the PR number.
# You WILL need to have your Github or Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: checkout-pr <pr #> (while inside the repo)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

service="$(bitbucket_or_github)"
[[ $? -eq 0 ]] || die

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/${service}.sh"

branch="$(get_branch_from_pr "$1")"

[[ -n "$branch" ]] || die "Failed to get the branch corresponding to the given PR number: $1"

git checkout "$branch"
