#!/usr/bin/env bash

# Runs style targets for all Go/JS files that have changed between the current code and master.
# Since it only targets the files that have changed, it is significantly faster.
# However, it is not guaranteed to be correct. (Although it should be 99% of the time.)
# Usage: quickstyle (while inside the rox repo)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"


gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."

diffbase="$(git merge-base HEAD origin/master)"
[[ $? -eq 0 ]] || die "Failed to determine diffbase"

generated_files="$(git -C "$gitroot" grep -l '^// Code generated by .* DO NOT EDIT\.' -- '*.go' | sed -e "s@^@${gitroot}/@")"

IFS=$'\n' read -d '' -r -a changed_files < <(
	{
		git diff "$diffbase" --name-status . |
		egrep '(\.go|\.js)$' |
		sed -n -E -e "s@^[AM][[:space:]]+|^R[^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+@${gitroot}/@p" ;
		echo "$generated_files" ; echo "$generated_files"
	} | sort | uniq -u) || true

# Expected arguments:
# 1. Program name (for printing)
# 2. Filename regex.
# 3. Array of godirs
function go_run_program() {
  local program_name=$1
  einfo "${program_name}"
  shift
  local filename_regex=$1
  shift
  local godirs=("$@")
  local program="$(git ls-files -- "${gitroot}" | egrep "${filename_regex}" | head -n 1)"
  [[ -n "${program}" ]] || { ewarn "Couldn't find program ${filename_regex}"; return; }
  go run "${program}" $(go list "${godirs[@]}")
}

function gostyle() {
	local status
	local changed_files=("$@")
	local gofiles
	IFS=$'\n' read -d '' -r -a gofiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep '\.go$' |
		grep -v 'mocks/'
	)
	[[ "${#gofiles[@]}" == 0 ]] && return 0
	einfo "Running go style checks..."
	einfo "fmt"
	gofmt -s -l -w "${gofiles[@]}"
	status=$?
	einfo "imports"
	goimports -w "${gofiles[@]}" && (( status == 0 ))
	status=$?
	einfo "lint"
	IFS=$'\n' read -d '' -r -a godirs < <(
		for f in "${gofiles[@]}"; do dirname "$f"; done |
		sort | uniq)
	for dir in "${godirs[@]}"; do
		golint -set_exit_status "${dir}" && (( status == 0 ))
		status=$?
	done
	einfo "vet"
	local src_root="$(go env GOPATH)/src"
	local packages
	packages=($(printf '%s\n' "${godirs[@]}" | sed -e "s@^${src_root}/@@"))

	vet="$(git ls-files -- "${gitroot}" | egrep '\bgo-vet\.sh$' | head -n 1)"
	if [[ ! -x "${vet}" ]]; then
		vet=(go vet)
	fi
	"${vet[@]}" "${packages[@]}" && (( status == 0 ))
	status=$?
	einfo "blanks"
	local blanks
	blanks="$({
		git ls-files -- "${gitroot}" | egrep '\bfix-blanks\.sh$'
		git ls-files -- "${gitroot}" | egrep '\bimport_validate\.py$'
	} | head -n 1)"
	[[ -n "${blanks}" ]] || die "Couldn't find the script that implements make blanks. Is this repo supported by quickstyle?"
	"${blanks}" "${gofiles[@]}" && (( status == 0 ))
	status=$?

	go_run_program "validateimports" '\b(crosspkg|validate)imports/verify\.go$' "${godirs[@]}" && (( status == 0 ))
	status=$?

	einfo "roxvet"
	local rox_vet="$(go env GOPATH)/bin/roxvet"
	[[ -x "${rox_vet}" ]] || go install "${gitroot}/tools/roxvet"
	go vet -vettool "${rox_vet}" "${packages[@]}" && (( status == 0 ))
	status=$?

	return $status
}

function jsstyle() {
	local jsfiles
	local status
	IFS=$'\n' read -d '' -r -a jsfiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep "${gitroot}/ui/.*js$"
	)
	[[ "${#jsfiles[@]}" -eq 0 ]] && return 0
	einfo "Running JS style checks..."
	(cd "${gitroot}/ui" && yarn --silent eslint "${jsfiles[@]}" --fix)
	status=$?
	return "${status}"
}


[[ "${#changed_files[@]}" -eq 0 ]] && { ewarn "No changed Go/JS files found in current directory."; exit 0; }

gostyle "${changed_files[@]}"
gostatus=$?

jsstyle "${changed_files[@]}"
jsstatus=$?

[[ "${gostatus}" -eq 0 && "${jsstatus}" -eq 0 ]] && exit 0
efatal "Style errors were found"
exit 1
