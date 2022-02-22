#!/usr/bin/env bash

# Cycles through recently checked out branches.
#
# The script accepts an optional positional argument <num>, which specifies the
# number of branches to cycle through (and print). The default is 1.
# When invoked with the -c or --checkout flag, this script attempts to check out
# the respective branch; otherwise it just prints the last <num> branches.
#
# Example usages:
#   cycle-branch         Prints the branch that was checked out before the
#                        current one.
#   cycle-branch 3       Prints the last three branches that were checked out
#                        before the current one, highlighting the third-last.
#   cycle-branch -c 2    Checks out the second-last branch that was checked out
#                        previously.

pushd >/dev/null "$(dirname "$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")")"
source "../../lib/common.sh"
source "../../lib/git.sh"
popd >/dev/null

gitroot="$(git rev-parse --show-toplevel)"

[[ -n "$gitroot" ]] || die "Could not determine git root directory"

is_local_branch() {
	local branch_name="$1"
	git rev-parse "refs/heads/${branch_name}" &>/dev/null
}

checkout_regex='^checkout: moving from ([^[:space:]]+) to ([^[:space:]]+)$'

get_last_branches() {
	n=$(($1 + 1))

	# This gets initialized with ("") if the current HEAD is not a branch, which is okay.
	last_branches=("$(get_current_branch 2>/dev/null)")

	while [[ "${#last_branches[@]}" -lt "$n" ]] && IFS= read -r line; do
		if [[ "$line" =~ $checkout_regex ]]; then
			target_ref="${BASH_REMATCH[1]}"
			if is_local_branch "$target_ref" && ! grep -qx "$target_ref" < <(printf '%s\n' "${last_branches[@]}"); then
				last_branches+=("$target_ref")
			fi
		fi
	done < <(git log -g --grep-reflog '^checkout: moving from ' --format='%gs' -- "$gitroot")

	printf '%s\n' "${last_branches[@]:1}"
}

print_highlighted() {
	last_branches=("$@")
	num="${#last_branches[@]}"
	num_width="${#num}"
	for idx in ${!last_branches[@]}; do
		last_branches[$idx]="$(printf "[%${num_width}d] %s" $((idx + 1)) "${last_branches[$idx]}")"
	done
	if [[ "${#last_branches[@]}" -gt 1 ]]; then
		printf '%s\n' "${last_branches[@]::${#last_branches[@]}-1}"
	fi
	echo -ne "$bold"
	echo "${last_branches[${#last_branches[@]}-1]}"
	echo -ne "$reset"
}

checkout=0
pos_args=()

for arg in "$@"; do
	case "$arg" in
	-c|--checkout)
		checkout=1
		;;
	-*)
		die "Invalid option $arg"
		;;
	*)
		pos_args+=("$arg")
		;;
	esac
done

set -- "${pos_args}"
if [[ $# -gt 1 ]]; then
	die "Usage: $0 [-n] [<index>]"
fi

num="${1:-1}"
read -d '' -r -a branches < <(get_last_branches "$num")

if (( checkout )); then
	target_branch="${branches[${#branches[@]}-1]}"
	git checkout "$target_branch" && exit 0
	eerror "Could not check out ${target_branch}, possibly because of conflicting changes. Only listing branches."
fi

print_highlighted "${branches[@]}"
exit "$checkout"
