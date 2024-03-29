#!/usr/bin/env bash

#Usage: smart-squash (squashes commits only until the first parent branch marker)

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
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

commit_msg_file="$(mktemp)"
effective_num_commits=0
for commit in $(git rev-list --reverse "${marker_commit}"..HEAD); do
  commit_message="$(git log --format=%B -n 1 "${commit}")"
  if [[ ${commit_message} =~ ^X-Smart-Squash:\ Squashed\ ([[:digit:]]+)\ commits ]]; then
    num_commits_squashed="${BASH_REMATCH[1]}"
    effective_num_commits="$((effective_num_commits+num_commits_squashed))"
    tail -n +3 <<<"${commit_message}" >> "${commit_msg_file}"
  else
    effective_num_commits="$((effective_num_commits+1))"
    git log --oneline -n 1 "${commit}" >>"${commit_msg_file}"
  fi
done
commit_msg_contents="$(cat "${commit_msg_file}")"
printf '%s\n\n%s\n' "X-Smart-Squash: Squashed ${effective_num_commits} commits:" "${commit_msg_contents}" >"${commit_msg_file}"

git reset --soft "$marker_commit"
git commit --no-verify -F "$commit_msg_file"
rm -f "$commit_msg_file"

einfo "Squashed ${num_commits} onto ${marker_commit}."
