#!/usr/bin/env bash

# Runs style targets for all Go/JS files that have changed between the current code and master.
# Since it only targets the files that have changed, it is significantly faster.
# However, it is not guaranteed to be correct. (Although it should be 99% of the time.)
# Usage: quickstyle (while inside the rox repo)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../setup/packages.sh"

function newlinecheck() {
  local check_newlines
	check_newlines="$(
		git ls-files -- "${gitroot}" | egrep '\check-newlines\.sh$' | head -n 1
		)"
  [[ -x "${check_newlines}" ]] || return 0  # Silently exit
  einfo "Adding missing newlines..."
  "${check_newlines}" --fix "$@"
}

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
  local godirs
  godirs=("$@")
  local program="$(git ls-files -- "${gitroot}" | egrep "${filename_regex}" | head -n 1)"
  [[ -n "${program}" ]] || { ewarn "Couldn't find program ${filename_regex}"; return; }

  # Parse go dirs into array because go list expects an array
  local go_packages=()
  IFS=$'\n' read -d '' -r -a go_packages < <(go list "${godirs[@]}")
  go run "${program}" "${go_packages[@]}"
}

function gostyle() {
	local status=0
	local changed_files=("$@")
	local gofiles
	IFS=$'\n' read -d '' -r -a gofiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep '\.go$' |
		grep -v 'mocks/'
	)
	[[ "${#gofiles[@]}" == 0 ]] && return 0
	IFS=$'\n' read -d '' -r -a godirs < <(
		for f in "${gofiles[@]}"; do dirname "$f"; done |
		sort | uniq)

	einfo "Running go style checks..."
	if [[ -f "${gitroot}/.golangci.yml" ]]; then
		einfo "golangci-lint"
		if [[ -x "$(which golangci-lint)" ]]; then
			golangci-lint run "${godirs[@]}" --fix && (( status == 0 ))
			status=$?
		else
			ewarn "No golangci-lint binary found, but the repo has a config file. Skipping..."
		fi
	fi

	if ! golangci_linter_enabled 'goimports'; then
		einfo "imports"
		goimports -l -w "${gofiles[@]}" && (( status == 0 ))
		status=$?
	fi

	einfo "blanks"
	local blanks
	blanks="$({
		git ls-files -- "${gitroot}" | egrep '\bfix-blanks\.sh$'
		git ls-files -- "${gitroot}" | egrep '\bimport_validate\.py$'
	} | head -n 1)"
	if [[ -x "${blanks}" ]]; then
		"${blanks}" "${gofiles[@]}" && (( status == 0 ))
		status=$?
	else
	    ewarn "Couldn't find the script that implements make blanks. Is this repo supported by quickstyle?"
	fi

	if ! golangci_linter_enabled 'gofmt'; then
		einfo "fmt"
		gofmt -s -l -w "${gofiles[@]}" && (( status == 0 ))
		status=$?
	fi

	if ! golangci_linter_enabled 'golint'; then
		einfo "lint"
		local lint_script
		lint_script="$(git ls-files -- "${gitroot}" | egrep '\bgo-lint\.sh$' | head -n 1)"
		if [[ -x "${lint_script}" ]]; then
			"${lint_script}" "${gofiles[@]}" && (( status == 0 ))
			status=$?
		else
			for dir in "${godirs[@]}"; do
				golint -set_exit_status "${dir}" && (( status == 0 ))
				status=$?
			done
		fi
	fi
	if ! golangci_linter_enabled 'govet'; then
		einfo "vet"
		vet="$(git ls-files -- "${gitroot}" | egrep '\bgo-vet\.sh$' | head -n 1)"
		if [[ ! -x "${vet}" ]]; then
			vet=(go vet)
		fi
		"${vet[@]}" "${godirs[@]}" && (( status == 0 ))
		status=$?
	fi

	go_run_program "validateimports" '\b(crosspkg|validate)imports/verify\.go$' "${godirs[@]}" && (( status == 0 ))
	status=$?

	einfo "roxvet"
	local rox_vet="$(go env GOPATH)/bin/roxvet"
	if [[ ! -x "${rox_vet}" ]] && [[ -d "${gitroot}/tools/roxvet" ]]; then
	    go install "${gitroot}/tools/roxvet"
	fi
	if [[ -x "${rox_vet}" ]]; then
	    go vet -vettool "${rox_vet}" "${godirs[@]}" && (( status == 0 ))
	    status=$?
	else
	    ewarn "roxvet not found"
	fi

	einfo "staticcheck"
	local staticcheck_bin
	staticcheck_bin="$(git ls-files -- "${gitroot}" | egrep '\bstaticcheck-wrap.sh$')"
	if [[ -x "${staticcheck_bin}" ]]; then
		"${staticcheck_bin}" "${godirs[@]}" && (( status == 0 ))
		status=$?
	else
		ewarn "Skipping staticcheck, doesn't appear to be supported in the repo."
	fi

	return $status
}

function golangci_linter_enabled() {
  if [[ ! -x "$(command -v "golangci-lint")" ]]; then
    return 1
  fi

  local linter
  local enabled_linters
  linter="${1}"
  local requiredver="4.0.0"  # yq 4 introduced breaking syntax changes
  if [ "$(printf '%s\n' "$requiredver" "$YQ_SYSTEM_VERSION" | sort -V | head -n1)" = "$requiredver" ]; then 
    enabled_linters="$(yq eval '.linters.enable | ... comments=""' "${gitroot}"/.golangci.yml | sed "s/- //g")"
  else
    einfo "You are using yq < 4.0.0, consider upgrading"
    enabled_linters="$(yq r --stripComments "${gitroot}"/.golangci.yml linters.enable | sed "s/- //g")"

  fi
  printf '%s\n' "${enabled_linters[@]}" | grep -qx "^${linter}$"
}

function jsstyle() {
  local changed_files=("$@")
	local jsfiles
	local status
	IFS=$'\n' read -d '' -r -a jsfiles < <(
		printf '%s\n' "${changed_files[@]}" |
		egrep "${gitroot}/ui/.*(js|tsx|ts)$"
	)
	[[ "${#jsfiles[@]}" -eq 0 ]] && return 0
	einfo "Running JS style checks..."
	(cd "${gitroot}/ui" && yarn --silent eslint "${jsfiles[@]}" --fix --quiet)
	status=$?
	return "${status}"
}

function circlecistyle() {
	local status=0
	local changed_files=("$@")
	if printf '%s\n' "${changed_files[@]}" | grep -qx "${gitroot}/.circleci/config.yml"; then
		if [[ -x "$(command -v circleci)" ]]; then
			einfo "Validating Circle config..."
			circleci config validate "${gitroot}/.circleci/config.yml" --skip-update-check
			status=$?
		else
			ewarn "CircleCI config changed, but no local CircleCI CLI detected. Consider installing it to run validation."
		fi
	fi
	return "${status}"
}

# get_files_and_hashes returns one line for each filename
# passed to it, where each line contains the file name and its hash separated by a tab.
function get_files_and_hashes() {
  local changed_files=("$@")
  for changed_file in "${changed_files[@]}"; do
    hash="$(git hash-object "${changed_file}")"
    if [[ -n "${hash}" ]]; then
      printf '%s\t%s\n' "${changed_file}" "${hash}"
    fi
  done
}


check_dependencies

gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."

if [[ -f "${gitroot}/go.mod" ]]; then
	export GO111MODULE=on
fi

# From https://stackoverflow.com/questions/28666357/git-how-to-get-default-branch#comment92366240_50056710
main_branch="$(git remote show origin | grep "HEAD branch" | sed 's/.*: //')"
[[ -n "${main_branch}" ]] || die "Failed to get main branch"

diffbase="$(git merge-base HEAD "origin/${main_branch}")"
[[ $? -eq 0 ]] || die "Failed to determine diffbase"

generated_files="$(git -C "$gitroot" grep -l '^// Code generated by .* DO NOT EDIT\.' -- '*.go' | sed -e "s@^@${gitroot}/@")"

IFS=$'\n' read -d '' -r -a all_changed_files < <(
	{
		git diff "$diffbase" --name-status . |
		sed -n -E -e "s@^[AM][[:space:]]+|^R[^[:space:]]*[[:space:]]+[^[:space:]]+[[:space:]]+@${gitroot}/@p" ;
		echo "$generated_files" ; echo "$generated_files"
	} | sort | uniq -u) || true


[[ "${#all_changed_files[@]}" -eq 0 ]] && { ewarn "No relevant changes found in current directory."; exit 0; }

cache_file_rel_dir="quickstyle/$(echo "${gitroot}" | tr '/' '_')"  # The workfile is specific to the current repo
cache_path="$(get_workfile_path_and_ensure_dir "${cache_file_rel_dir}")"
[[ -n "${cache_path}" ]] || die "Couldn't set up cache file"

# If the cache path is empty, just create an empty file so the below code
# can handle it correctly.
[[ -f "${cache_path}" ]] || echo > "${cache_path}"

filtered_changed_files=()

IFS=$'\n' read -d '' -r -a filtered_changed_files < <(
  comm -13 <(sort <"${cache_path}") <(get_files_and_hashes "${all_changed_files[@]}" | sort) | awk -F'\t' '{print$1}')

einfo "${#all_changed_files[@]} files changed from ${main_branch}, ${#filtered_changed_files[@]} changed since the last successful quickstyle run."
[[ "${#filtered_changed_files[@]}" -eq 0 ]] && { einfo "Exiting since all changed files have already been checked."; exit 0; }

status=0

for check_cmd in newlinecheck gostyle jsstyle circlecistyle; do
  "${check_cmd}" "${filtered_changed_files[@]}" && (( status == 0 ))
  status=$?
done

if [[ "${status}" -ne 0 ]]; then
  efatal "Style errors were found"
  exit 1
fi

# We know that these current files have passed vetting
# with quickstyle, so record them in the cache.
# Note that we need to recompute the hashes before writing to the cache
# because some of the files may have been rewritten by quickstyle.
get_files_and_hashes "${all_changed_files[@]}" > "${cache_path}"
exit 0
