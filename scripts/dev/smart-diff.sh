#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

marker_commit="$(git log --grep="^X-Smart-Branch-Parent: " --format="%H" --max-count=1)"
[[ $? == 0 ]] || die "Could not inspect git logs."
if [[ -z "$marker_commit" ]]; then
	die 'Could not find a smart-branch commit. Please run `smart-rebase [<base-branch>]` first.'
fi

git diff "$marker_commit" -- "$@"
