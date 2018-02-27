#!/usr/bin/env bash

# Opens the web page corresponding to the currently checked-out branch of the repo you're in.
# NOTE: Currently supports Bitbucket only.
# Usage: openbranch (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/bitbucket.sh"

repo="$(get_bitbucket_repo)"

[[ -n "$repo" ]] || die "Couldn't get the bitbucket repo."

branch="$(get_current_branch)"

[[ -n "$branch" ]] || die "Couldn't get the current branch."

browse https://bitbucket.org/"${repo}"/branch/"${branch}"
