#!/usr/bin/env bash

# Edits a file with CI environment variables associated with the current branch.
# Thos variable definitions will automatically be added to every commit message in this branch.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

git_dir="$(git rev-parse --absolute-git-dir)"

[[ -d "$git_dir" ]] || die "Could not determine .git directory"

branch_name="$(git symbolic-ref --short HEAD 2>/dev/null)"

[[ -n "$branch_name" ]] || die "Could not determine the current branch name."

citags_root="${git_dir}/citags"
citags_file="${citags_root}/${branch_name}"

function create_backup() {
	local file="$1"
	backup="${file}.bak"
    i=0
    while [[ -f "$backup" ]]; do
      i=$((i + 1))
      backup="${file}.bak.$i"
    done
    ewarn "There already is a $(basename "$file") file that is not related to CITags. It will be backed up as ${backup}"
    mv "$file" "$backup"
}

function cleanup() {
	[[ -d "$citags_root" ]] || return 0
	while IFS='' read -r branch; do
		branch="${branch#./}"
		einfo "Removing obsolete CITags file for deleted branch ${branch} ..."
		rm "${citags_root}/${branch}"
	done < <(comm -13 <(git for-each-ref --format='./%(refname:short)' refs/heads/ | sort) <(cd "${citags_root}"; find . -type f | sort))
	find "${citags_root}/" -type d -empty -delete
}

function edit_citags() {
	if [[ ! -f "$citags_file" ]]; then
	  mkdir -p "$(dirname "$citags_file")"
	  cat >"$citags_file" <<EOF

# CI tags for branch ${branch_name}
#
# Enter environment variables for use in CI in the form VAR=value, one per line.
# Lines starting with "#" will be ignored.
# Note: do *not* use quotes on the right-hand side.
EOF
	fi

	local editor="${GIT_EDITOR}"
	[[ -n "$editor" ]] || editor="$EDITOR"
	[[ -n "$editor" ]] || editor="vim"

	$editor "$citags_file"
}

function setup_hooks() {
	local prepare_hook="${git_dir}/hooks/prepare-commit-msg"
	local msg_hook="${git_dir}/hooks/commit-msg"

	local citags_prepare_hook="$(dirname "$SCRIPT")/citags-prepare-commit-msg.sh"
	local citags_msg_hook="$(dirname "$SCRIPT")/citags-commit-msg.sh"

	if [[ ! -f "$prepare_hook" || ! -f "$msg_hook" || "$(readlink "$prepare_hook")" != "$citags_prepare_hook" || "$(readlink "$msg_hook")" != "$citags_msg_hook" ]]; then
	  einfo "CITags hook is not set up. Do you want to set it up now?"
	  yes_no_prompt || return 0
	fi


	if [[ -f "$prepare_hook" && "$(readlink "$prepare_hook")" != "$citags_prepare_hook" ]]; then
	  create_backup "$prepare_hook"
	fi

	if [[ -f "$msg_hook" && "$(readlink "$msg_hook")" != "$citags_msg_hook" ]]; then
		create_backup "$msg_hook"
	fi

	mkdir -p "$(dirname "${prepare_hook}")"

	ln -sf "$citags_prepare_hook" "$prepare_hook"
	ln -sf "$citags_msg_hook" "$msg_hook"
}

cleanup
edit_citags || die "file edit was aborted, or there was an error launching the editor."
setup_hooks

