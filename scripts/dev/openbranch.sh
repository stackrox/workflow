#!/usr/bin/env bash

# Opens the web page corresponding to the currently checked-out branch of the repo you're in.
# NOTE: Currently supports Mac OS and Bitbucket only.
# Usage: openbranch (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

REPO="$(get_bitbucket_repo)"

[[ -n "$REPO" ]] || die "Couldn't get the bitbucket repo."

BRANCH="$(get_current_branch)"

[[ -n "$BRANCH" ]] || die "Couldn't get the current branch."

browse https://bitbucket.org/"${REPO}"/branch/"${BRANCH}"
