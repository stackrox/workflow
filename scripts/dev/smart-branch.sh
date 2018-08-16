#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

[[ $# > 0 && $# < 3 ]] || die "Usage: $0 <branch-name> [<parent-branch>]"

branch_name="$1"

[[ -n "$branch_name" ]] || die "'$branch_name' is not a valid branch name"

! branch_exists "$branch_name" || die "Branch $branch_name already exists. If you want to recreate this branch, you must first delete it"

parent_branch="$2"
if [[ -z "$parent_branch" ]]; then
	parent_branch="$(get_current_branch 2>/dev/null)"
fi
[[ -n "$parent_branch" ]] || die "You're not on a branch head and no explicit parent branch specified. Use $0 $1 <parent-branch> to create a branch off the current commit"
branch_exists "$parent_branch" || die "Parent branch $parent_branch does not exist"

if [[ "$(git merge-base HEAD "$parent_branch")" != "$(git rev-parse HEAD)" ]]; then
	ewarn "You've specified $parent_branch as the parent branch but the current HEAD doesn't seem to be part of this branch's history."
	ewarn "I will branch off the current commit and just mark $parent_branch as the parent, without rebasing."
	ewarn "Do you want to continue?"
	yes_no_prompt || die "Aborted."
fi
git checkout -b "$branch_name" || die "Could not create new branch '$branch_name'"

stashed=0

if ! git diff-index --quiet HEAD; then
	einfo "Stashing your current changes ..."
	git stash push
	stashed=1
fi

git commit --allow-empty -m "X-Smart-Branch-Parent: $parent_branch"

if (( stashed == 1 )); then
	einfo "Restoring stashed changes ..."
	git stash pop --index
fi
