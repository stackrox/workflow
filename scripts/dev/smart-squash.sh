#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

git diff-index --quiet HEAD || die "Current working directory must be clean before rebasing."

current_branch="$(get_current_branch)"

[[ -n "$current_branch" ]] || die "Failed to determine the current branch."

marker_commit="$(git log --grep="^X-Smart-Branch-Parent: " --format="%H" --max-count=1)"
[[ $? == 0 ]] || die "Could not inspect git logs."
if [[ -z "$marker_commit" ]]; then
	die 'Could not find a smart-branch commit. Please run `smart-rebase [<base-branch>]` first.'
fi

num_commits=$(($(git log --format='%H' HEAD...${marker_commit} | wc -l)))

if (( num_commits < 2 )); then
	einfo "Nothing to squash."
	exit 0
fi

commit_msg="$(mktemp)"
echo "Squashed $num_commits commits:" >"$commit_msg"
echo >>"$commit_msg"
git log --oneline "HEAD...${marker_commit}" >>"$commit_msg"

git reset --soft "$marker_commit"
git commit -F "$commit_msg"
rm -f "$commit_msg"

einfo "Squashed ${num_commits} onto ${marker_commit}."
