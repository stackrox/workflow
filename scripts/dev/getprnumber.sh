#!/usr/bin/env bash

# Gets the PR number corresponding to the current checked out branch.
# NOTE: Currently supports Bitbucket only.
# You WILL need to have your Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: getprnumber (while inside the repo, with the branch you care about checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/bitbucket.sh"

pr_number="$(get_pr_number)"
[[ -n "$pr_number" ]] || die "Couldn't find the PR number."
echo "$pr_number"
