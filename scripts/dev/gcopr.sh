#!/usr/bin/env bash

# Checks out the branch given the bitbucket PR number.
# You WILL need to have your Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: gcopr <pr #> (while inside the repo)

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

BITBUCKET_REPO="$(get_bitbucket_repo)"
[[ -n "$BITBUCKET_REPO" ]] || die "Error getting PR info."

BRANCH="$(get_branch_from_pr $1)"

[[ -n "$BRANCH" ]] || die "Failed to get the branch corresponding to the given PR number: $1"

git checkout "$BRANCH"
