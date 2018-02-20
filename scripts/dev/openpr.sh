#!/usr/bin/env bash

# Opens the web page corresponding to the Pull Request for the currently checked-out branch of the repo you're in.
# NOTE: Currently supports Mac OS and Bitbucket only.
# You WILL need to have your Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: openpr (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

PR_NUMBER="$(get_pr_number)"
BITBUCKET_REPO="$(get_bitbucket_repo)"
[[ -n "$PR_NUMBER" && -n "$BITBUCKET_REPO" ]] || die "Error getting PR info."
open https://bitbucket.org/${BITBUCKET_REPO}/pull-requests/${PR_NUMBER}
