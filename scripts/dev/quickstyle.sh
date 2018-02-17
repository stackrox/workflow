#!/usr/bin/env bash

# Runs style targets for all Go files that have changed between the current code
# and develop. Since it only targets the files that have changed, it is significantly faster.
# However, it is not guaranteed to be correct. (Although it should be 99% of the time.)
# Usage: quickstyle (while inside the stackrox repo)

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"


gitroot="$(git rev-parse --show-toplevel)"
[[ $? -eq 0 ]] || die "Current directory is not a git repository."
IFS=$'\n' read -d '' -r -a gofiles < <(
	git diff origin/develop --name-status . |
	grep '.go$' |
	sed -n -E -e "s@^[AM][[:space:]]+@${gitroot}/@p") || true

if [[ "${#gofiles[@]}" == 0 ]]; then
	ewarn "No Go files found in current directory."
	exit 0
fi
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
src_root="$(go env GOPATH)/src"
packages=($(printf '%s\n' "${godirs[@]}" | sed -e "s@^${src_root}/@@"))
vet=("${gitroot}/build/scripts/go-vet.sh")
if [[ ! -x "${vet}" ]]; then
	vet=(go vet)
fi
"${vet[@]}" "${packages[@]}" && (( status == 0 ))
status=$?
einfo "blanks"
"${gitroot}/scripts/import_validate.py" "${gofiles[@]}" && (( status == 0 ))
status=$?
if (( status != 0 )); then
	efatal "Style errors were found"
fi
exit $status
