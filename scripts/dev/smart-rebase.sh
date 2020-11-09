#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

target_branch="$1"

git diff-index --quiet HEAD || die "Current working directory must be clean before rebasing."

current_branch="$(get_current_branch)"

[[ -n "$current_branch" ]] || die "Failed to determine the current branch."

match="$(git log --grep="^X-Smart-Branch-Parent: " --format="%H %s" --max-count=1)"
[[ $? == 0 ]] || die "Could not inspect git logs."

if [[ -z "$match" ]]; then
	if [[ -z "$target_branch" ]]; then
		default_branch="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
		ewarn "No smart-branch parent found in logs and no base specified. Do you want to mark the default branch ($default_branch)"
		ewarn "as a parent of ${current_branch}?"
		yes_no_prompt || die "Aborted. Specify an explicit parent using $0 <parent-branch>"
		target_branch="$default_branch"
	fi
	merge_base="$(git merge-base $target_branch HEAD)"
	rebase_base="$merge_base"
	[[ $? == 0 && -n "$merge_base" ]] || die "Could not determine a merge-base for $current_branch and $target_branch."
	if [[ "$(git rev-parse "$current_branch")" == "$merge_base" ]]; then
		# Special case: the current branch head was branched off the target branch, but contains no commits yet. In this case we
		# can safely rebase on top of the target branch head.
		merge_base="$(git rev-parse "$target_branch")"
		rebase_base="$(git rev-parse "$current_branch")"
	elif [[ "$(git rev-parse "$target_branch")" != "$merge_base" ]]; then
		einfo "About to mark $target_branch as the branch parent of $current_branch by inserting a marker between the following commits:"
		einfo "Commit after which to branch off of $target_branch:"
		git log "$merge_base" --max-count=1 --format="  SHA: %H%n  %s%n    by %an at %ad"
		first_current_branch_commit="$(git rev-list --reverse "$merge_base".."$current_branch" | head -n 1)"
		einfo "First commit of $current_branch (after marker):"
		git log "$first_current_branch_commit" --max-count=1 --format="  SHA: %H%n  %s%n    by %an at %ad"
		yes_no_prompt "Continue?" || die "Aborted."
	fi
	git checkout --detach "$merge_base" || die "Failed to check out merge base $merge_base"
	git commit --no-verify --allow-empty -m "X-Smart-Branch-Parent: $target_branch" || die "Could not insert branch parent marker"
	marker="$(git rev-parse HEAD)"
	git checkout "$current_branch"
	git rebase --onto "$marker" "$rebase_base" "$current_branch" || die "Rebasing failed. This should not happen!"
	einfo "Marked $target_branch as the branch parent of $current_branch."
	if [[ "$merge_base" != "$(git rev-parse "$target_branch")" ]]; then
		ewarn "Marked $target_branch as parent of $current_branch, but did not perform an actual rebase."
		ewarn "Re-run this command without arguments to perform the rebase."
	fi
	exit 0
fi

regex='^([[:xdigit:]]+) X-Smart-Branch-Parent: ([[:alnum:][:punct:]]+)$'
if [[ $match =~ $regex ]]; then
	first_commit="${BASH_REMATCH[1]}"
	parent_branch="${BASH_REMATCH[2]}"
fi

[[ -n "$first_commit" ]] || die "Could not determine first commit in this branch. Did you create the branch using smart-branch?"

old_base="${first_commit}"
if [[ -n "$target_branch" && "$target_branch" != "$parent_branch" ]]; then
	einfo "Switching parent branch from $parent_branch to $target_branch ..."
	if [[ "$(git merge-base "$old_base" "$target_branch")" == "$old_base" ]]; then
		# Simple case: the old base is now part of the history of target branch.
		# Only mark branch as parent, but do not rebase.
		git checkout --detach "$old_base"
		git commit --no-verify --allow-empty -m "X-Smart-Branch-Parent: ${target_branch}"
		new_marker="$(git rev-parse HEAD)"
		git rebase --onto "$new_marker" "$first_commit" "$current_branch" || die "Rebase failed."
		einfo "Marked $target_branch as the branch parent of $current_branch."
		if [[ "$old_base" != "$(git rev-parse "$target_branch")" ]]; then
			ewarn "Marked $target_branch as parent of $current_branch, but did not perform an actual rebase."
			ewarn "Re-run this command without arguments to perform the rebase."
		fi
		exit 0
	fi

	ewarn "Branch $current_branch is currently based on $parent_branch, on top of this commit:"
	git log "$old_base" --max-count=1 --format="  SHA: %H%n  %s%n    by %an at %ad"
	ewarn "Its base will be changed to $target_branch, on top of this commit:"
	git log "$target_branch" --max-count=1 --format="  SHA: %H%n  %s%n    by %an at %ad"
	ewarn "This might result in conflicts. Do you want to continue?"
	yes_no_prompt || die "Aborted."
else
	target_branch="$parent_branch"
fi

if [[ "${target_branch}" == "${parent_branch}" && "$(git rev-parse "${target_branch}")" == "$(git rev-parse "${old_base}^")" ]]; then
	einfo "Branch is already based on top of up-to-date ${target_branch}"
	exit 0
fi

einfo "Rebasing $current_branch onto $target_branch ..."

git checkout --detach "$target_branch"
git commit --no-verify --allow-empty -m "X-Smart-Branch-Parent: ${target_branch}"

new_base="$(git rev-parse HEAD)"

git rebase --onto "$new_base" "$old_base" "$current_branch"
if [[ $? != 0 ]]; then
	eerror 'Rebasing failed. Abort the rebase with `git rebase --abort` or fix the conflicts'
	eerror 'and continue using `git rebase --continue`'
fi
