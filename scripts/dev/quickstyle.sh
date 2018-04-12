#!/usr/bin/env bash

# Runs style targets for all Go/Java files that have changed between the current code and develop.
# Since it only targets the files that have changed, it is significantly faster.
# However, it is not guaranteed to be correct. (Although it should be 99% of the time.)
# Usage: quickstyle (while inside the stackrox repo)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"


gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."

IFS=$'\n' read -d '' -r -a changed_files < <(
	git diff origin/develop --name-status . |
	egrep '(\.go|\.java)$' |
	sed -n -E -e "s@^[AM][[:space:]]+@${gitroot}/@p") || true

function gostyle() {
	local status
	local changed_files=("$@")
	local gofiles
	IFS=$'\n' read -d '' -r -a gofiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep '\.go$'
	)
	[[ "${#gofiles[@]}" == 0 ]] && return 0
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
	local vet=("${gitroot}/build/scripts/go-vet.sh")
	if [[ ! -x "${vet}" ]]; then
		vet=(go vet)
	fi
	"${vet[@]}" "${packages[@]}" && (( status == 0 ))
	status=$?
	einfo "blanks"
	"${gitroot}/scripts/import_validate.py" "${gofiles[@]}" && (( status == 0 ))
	status=$?
	return $status
}

function javastyle() {
	local javafiles
	IFS=$'\n' read -d '' -r -a javafiles < <(
		printf '%s\n' "${changed_files[@]}" |
		grep "${gitroot}/ml/.*java$"
	)
	[[ "${#javafiles[@]}" -eq 0 ]] && return 0
	java -jar "${gitroot}/ml/checkstyle-8.5-all.jar" -c "${gitroot}/ml/stackrox_checks.xml" "${javafiles[@]}" > /tmp/lint.log
	local num_error_lines="$(grep -e 'WARN' /tmp/lint.log | wc -l)"
	local status=0
	[[ "${num_error_lines}" -eq 0 ]] || { grep -e 'WARN' /tmp/lint.log; status=1;}
	rm /tmp/lint.log
	return "${status}"
}

[[ "${#changed_files[@]}" -eq 0 ]] && { ewarn "No changed Go or Java files found in current directory."; exit 0; }

einfo "Running go style checks..."
gostyle "${changed_files[@]}"
gostatus=$?

einfo "Running Java style checks..."
javastyle "${changed_files[@]}"
javastatus=$?

[[ "${gostatus}" -eq 0 && "${javastatus}" -eq 0 ]] && exit 0
efatal "Style errors were found"
exit 1
