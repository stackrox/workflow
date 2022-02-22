#!/usr/bin/env bash

# Opens the web page corresponding to the currently checked-out branch of the repo you're in.
# Usage: openbranch (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

service="$(bitbucket_or_github)"
[[ $? -eq 0 ]] || die

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/${service}.sh"

branch_url="$(get_branch_url)"
[[ -n "${branch_url}" ]] || die "Error getting branch URL."
browse "${branch_url}"

