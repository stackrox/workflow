#!/usr/bin/env bash

# Opens the web page corresponding to the Pull Request for the currently checked-out branch of the repo you're in.
# You WILL need to have your GitHub or Bitbucket creds checked in to ~/.stackrox/workflow-config.json for this to work.
# Usage: openpr (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

service="$(bitbucket_or_github)"
[[ $? -eq 0 ]] || die

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/${service}.sh"

pr_url="$(get_pr_url)"
[[ -n "${pr_url}" ]] || die "Error getting PR URL."
browse "${pr_url}"
