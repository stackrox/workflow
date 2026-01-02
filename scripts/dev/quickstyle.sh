#!/usr/bin/env bash

# Runs style targets for all Go/JS files that have changed between the current code and master.
# Since it only targets the files that have changed, it is significantly faster.
# However, it is not guaranteed to be correct. (Although it should be 99% of the time.)
# Usage: quickstyle (while inside the rox repo)

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"
source "$(dirname "$SCRIPT")/../../setup/packages.sh"

check_dependencies

# quickstyle_repo_key returns a stable, filesystem-safe key for the current git repo root.
# It is used for naming repo-scoped cache directories under the workflow workdir.
function quickstyle_repo_key() {
  echo "${gitroot}" | tr '/' '_'
}

# quickstyle_tools_cache_dir returns (and ensures) the directory where quickstyle may place
# repo-scoped helper binaries (e.g. goimports) managed by workflow, not by the target repo.
function quickstyle_tools_cache_dir() {
  local repo_key
  repo_key="$(quickstyle_repo_key)"
  local tools_dir="${ROX_WORKFLOW_WORKDIR}/quickstyle/tools/${repo_key}"
  mkdir -p "${tools_dir}"
  echo "${tools_dir}"
}

# Try to resolve a tool path via the repo's Makefile gotools support (make/gotools.mk).
# Many StackRox repos expose `which-<tool>` targets that print the tool's canonical binary; use those
# to avoid relying on whatever happens to be in PATH/GOPATH.
# Args:
# - $1: tool basename (e.g. "roxvet", "golangci-lint", "goimports")
# Output: prints an absolute path to stdout if found.
# Returns: 0 if resolved; non-zero otherwise.
function resolve_tool_via_make() {
  local tool="$1"
  [[ -n "${tool}" ]] || return 1
  [[ -f "${gitroot}/Makefile" ]] || return 1
  [[ -x "$(command -v make)" ]] || return 1
  local resolved
  resolved="$(make -C "${gitroot}" --quiet --no-print-directory "which-${tool}" 2>/dev/null)" || return 1
  [[ -n "${resolved}" ]] || return 1
  [[ -x "${resolved}" ]] || return 1
  printf '%s\n' "${resolved}"
}

# resolve_tool_path attempts to find an executable tool by:
# 1) repo-local Makefile ("make which-<tool>"), then
# 2) PATH lookup.
# Args:
# - $1: tool basename
# Output: prints resolved executable path to stdout.
# Returns: 0 if resolved; non-zero otherwise.
function resolve_tool_path() {
  local tool="$1"
  local resolved=""

  resolved="$(resolve_tool_via_make "${tool}")" && { printf '%s\n' "${resolved}"; return 0; }

  resolved="$(command -v "${tool}" 2>/dev/null)" || true
  [[ -n "${resolved}" && -x "${resolved}" ]] || return 1
  printf '%s\n' "${resolved}"
}

# go_major_minor extracts "<major>.<minor>" from a Go version string.
# Example: "go1.24.9" -> "1.24"
# Args:
# - $1: value like "$(go env GOVERSION)" or "go1.24.9"
# Output: prints "<major>.<minor>" to stdout.
function go_major_minor() {
  local goversion="$1"
  # Examples: go1.24.9 -> 1.24 ; go1.22.7 -> 1.22
  echo "${goversion}" | sed -E 's/^go([0-9]+\.[0-9]+).*/\1/'
}

# tool_built_with_go_major_minor returns the Go "<major>.<minor>" used to build a given binary.
# This uses `go version -m`, so it requires the binary to contain build info.
# Args:
# - $1: path to an executable binary
# Output: prints "<major>.<minor>" to stdout.
# Returns: 0 if build info is available; non-zero otherwise.
function tool_built_with_go_major_minor() {
  local tool_path="$1"
  [[ -n "${tool_path}" && -x "${tool_path}" ]] || return 1
  local first_line
  first_line="$(go version -m "${tool_path}" 2>/dev/null | head -n 1)" || return 1
  # Format: /path/to/tool: go1.22.7
  local tool_go_version
  tool_go_version="$(echo "${first_line}" | awk '{print $2}')"
  [[ -n "${tool_go_version}" ]] || return 1
  go_major_minor "${tool_go_version}"
}

# ensure_goimports resolves a usable goimports binary.
# Resolution order:
# 1) repo-local Makefile ("make which-goimports"), then
# 2) PATH, then
# 3) workflow-managed install into a repo-scoped cache dir under ${ROX_WORKFLOW_WORKDIR}.
# Notes:
# - When installing, we try to pin to the repo's `golang.org/x/tools` module version if present;
#   otherwise we fall back to @latest.
# Output: prints the goimports executable path to stdout.
# Returns: 0 if available; non-zero otherwise.
function ensure_goimports() {
  local goimports_bin
  goimports_bin="$(resolve_tool_path goimports)" && { printf '%s\n' "${goimports_bin}"; return 0; }

  local tools_dir
  tools_dir="$(quickstyle_tools_cache_dir)"
  goimports_bin="${tools_dir}/goimports"
  [[ -x "${goimports_bin}" ]] && { printf '%s\n' "${goimports_bin}"; return 0; }

  local x_tools_version
  x_tools_version="$(cd "${gitroot}" && go list -m -f '{{.Version}}' golang.org/x/tools 2>/dev/null)" || true
  local goimports_pkg="golang.org/x/tools/cmd/goimports@latest"
  if [[ -n "${x_tools_version}" ]]; then
    goimports_pkg="golang.org/x/tools/cmd/goimports@${x_tools_version}"
  fi

  einfo "goimports not found; installing ${goimports_pkg} into ${tools_dir}..."
  if ! env GOBIN="${tools_dir}" go install "${goimports_pkg}"; then
    efatal "Failed to install goimports (${goimports_pkg})."
    efatal "Either install goimports on PATH, or ensure the repo exposes a 'which-goimports' Make target."
    return 1
  fi

  [[ -x "${goimports_bin}" ]] || return 1
  printf '%s\n' "${goimports_bin}"
}

# ensure_roxvet resolves a usable roxvet binary.
# Resolution order:
# 1) repo-local Makefile ("make which-roxvet"), then
# 2) GOPATH/bin/roxvet.
# If GOPATH/bin/roxvet exists but was built with a different Go major/minor than the current toolchain,
# we attempt to rebuild it from ${gitroot}/tools/roxvet (when present) to avoid export-data panics.
# Output: prints the roxvet executable path to stdout.
# Returns: 0 if available; non-zero otherwise.
function ensure_roxvet() {
  local roxvet_bin=""
  roxvet_bin="$(resolve_tool_via_make roxvet)" && { printf '%s\n' "${roxvet_bin}"; return 0; }

  roxvet_bin="$(go env GOPATH)/bin/roxvet"

  if [[ -x "${roxvet_bin}" ]]; then
    local tool_go_mm
    tool_go_mm="$(tool_built_with_go_major_minor "${roxvet_bin}")" || tool_go_mm=""
    local cur_go_mm
    cur_go_mm="$(go_major_minor "$(go env GOVERSION)")"

    # If roxvet is stale (built with different Go major.minor), it can panic on newer export data.
    if [[ -n "${tool_go_mm}" && "${tool_go_mm}" != "${cur_go_mm}" ]]; then
      ewarn "roxvet (${roxvet_bin}) was built with Go ${tool_go_mm}, but current Go is ${cur_go_mm}; rebuilding..."
      if [[ -d "${gitroot}/tools/roxvet" ]]; then
        if ! (cd "${gitroot}" && env GOBIN="$(dirname "${roxvet_bin}")" go install ./tools/roxvet); then
          ewarn "Failed to rebuild roxvet; continuing with existing binary (may fail)."
        fi
      fi
    fi
  fi

  [[ -x "${roxvet_bin}" ]] || return 1
  printf '%s\n' "${roxvet_bin}"
}

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
		local golangci_lint_bin
		golangci_lint_bin="$(resolve_tool_path golangci-lint)" || golangci_lint_bin=""
		if [[ -n "${golangci_lint_bin}" && -x "${golangci_lint_bin}" ]]; then
			"${golangci_lint_bin}" run --allow-parallel-runners "${godirs[@]}" --fix && (( status == 0 ))
			status=$?
		else
			ewarn "No golangci-lint binary found, but the repo has a config file. Skipping..."
		fi
	fi

	if ! golangci_linter_enabled 'goimports'; then
		einfo "imports"
		local goimports_bin
		goimports_bin="$(ensure_goimports)" || { status=1; return "${status}"; }
		"${goimports_bin}" -l -w "${gofiles[@]}" && (( status == 0 ))
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

	if ! golangci_linter_enabled 'golint' && ! golangci_linter_enabled 'revive'; then
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

	roxvet_includes_validateimports=0

	einfo "roxvet"
	local rox_vet
	rox_vet="$(ensure_roxvet)" || rox_vet=""
	if [[ -n "${rox_vet}" && -x "${rox_vet}" ]]; then
		go vet -vettool "${rox_vet}" "${godirs[@]}" && (( status == 0 ))
		status=$?
		if "${rox_vet}" help | grep -q validateimports; then
			roxvet_includes_validateimports=1
		fi
	else
		ewarn "roxvet not found"
	fi

	if (( roxvet_includes_validateimports == 0 )); then
		go_run_program "validateimports" '\b(crosspkg|validate)imports/verify\.go$' "${godirs[@]}" && (( status == 0 ))
		status=$?
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
  local linter
  local enabled_linters
  linter="${1}"

  # yq 4 introduced breaking syntax changes
  if check_min_required_yq_version "4.12.0"; then
    yaml_to_json=(yq eval -o=json)
  elif check_min_required_yq_version "4.0.0"; then
    yaml_to_json=(yq eval --tojson)
  else
    yaml_to_json=(yq r -j)
  fi
  enabled_linters="$("${yaml_to_json[@]}" "${gitroot}/.golangci.yml" | jq -r '.linters.enable[]')"

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
			einfo "Validating CircleCI CLI tool..."
			if ! circleci diagnostic; then
				ewarn "CircleCI config has changed but the CircleCI CLI tool is not operational."
				ewarn "set CIRCLECI_CLI_TOKEN or run circleci setup."
			else
				einfo "Validating CircleCI config..."
				circleci config validate --org-slug=gh/stackrox "${gitroot}/.circleci/config.yml" --skip-update-check
				status=$?
			fi
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

gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."

if [[ -f "${gitroot}/go.mod" ]]; then
	export GO111MODULE=on
fi

# https://stackoverflow.com/a/44750379
main_branch="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
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
