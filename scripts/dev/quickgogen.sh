#!/usr/bin/env bash

# Usage: Runs gogen for all Go files that have changed between the current code and master.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."

if [[ -f "${gitroot}/go.mod" ]]; then
	export GO111MODULE=on
fi

# Various code generation helpers are expected to be in the PATH when called by go generate.
export PATH="$PATH:${gitroot}/tools/generate-helpers"

main_branch="$(get_main_branch_or_die)"
diffbase="$(get_diffbase_or_die)"

generated_files="$(git -C "$gitroot" grep -l '^// Code generated by .* DO NOT EDIT\.' -- '*.go' | sed -e "s@^@${gitroot}/@")"

IFS=$'\n' read -d '' -r -a changed_files < <(
	{
		git diff "$diffbase" --name-status . |
		sed -n -E -e "s@^[AM][[:space:]]+|^R[^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+@${gitroot}/@p" ;
		echo "$generated_files" ; echo "$generated_files"
} | sort | uniq -u) || true

function private_gogen() {
	local status=0
	local changed_files=("$@")
	local gofiles

	IFS=$'\n' read -d '' -r -a gofiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep '\.go$'
	)
	[[ "${#gofiles[@]}" == 0 ]] && return 0

	IFS=$'\n' read -d '' -r -a godirs < <(
		for f in "${gofiles[@]}"; do dirname "$f"; done |
		sort | uniq)

	einfo "Running go generate..."
	for dir in "${godirs[@]}"; do
		einfo "...Generating for ${dir}"
		( cd "$dir" && go generate "./" ) && (( status == 0 ))
		status=$?
	done

	return "${status}"
}

[[ "${#changed_files[@]}" -eq 0 ]] && { ewarn "No relevant changes found in current directory."; exit 0; }
status=0

private_gogen "${changed_files[@]}" && (( status == 0 ))
status=$?

[[ "${status}" -eq 0 ]] && exit 0
efatal "An error occurred while generating files"
exit 1
