#!/usr/bin/env bash

# Opens the web page corresponding to the Pull Request for the currently checked-out branch of the repo you're in.
# NOTE: Currently supports Bitbucket only.
# You WILL need to have your Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: openpr (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/bitbucket.sh"

pr_number="$(get_pr_number)"
bitbucket_repo="$(get_bitbucket_repo)"
[[ -n "$pr_number" && -n "$bitbucket_repo" ]] || die "Error getting PR info."
browse "https://bitbucket.org/${bitbucket_repo}/pull-requests/${pr_number}"
