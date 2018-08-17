#!/usr/bin/env bash

# git prepare-commit-msg hook
# Adds the variables defined in the CITags file, if any, to the commit message template
# surrounding them with `CI[...]`.

set -e

commit_msg_file="$1"
branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
if [[ -z "$branch" ]]; then
	echo >&2 "Warning: not applying CITags, as this does not look like a local branch."
	exit 0
fi

git_dir="$(git rev-parse --absolute-git-dir)"

citags_file="${git_dir}/citags/${branch}"

[[ -f "$citags_file" ]] || exit 0

if grep -q '^CITags:$' "${commit_msg_file}"; then
	# Do not further modify a message that already contains tags (e.g., from git commit --amend).
	exit 0
fi

tmpfile="$(mktemp)"
cat >"$tmpfile" <<EOF

CITags:
EOF

while IFS='' read -r line || [[ -n "$line" ]]; do
	if [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]]; then
		continue
	fi

	if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*(=(.*))$ ]]; then
		if [[ "${#BASH_REMATCH[@]}" -ge 4 ]]; then
			echo >>"$tmpfile" "CI[${BASH_REMATCH[1]}=${BASH_REMATCH[3]}]"
		else
			echo >>"$tmpfile" "CI[${BASH_REMATCH[1]}]"
		fi
	else
		echo >&2 "Malformed line $line in CITags file"
	fi
done <"$citags_file"

message_source="$2"

if [[ "$message_source" == "message" ]]; then
	# If the source is a message, the commit message file is taken as-is, hence it must not
	# contain any comments.
	echo >>"$commit_msg_file"
	tail -n +3 "$tmpfile" >>"$commit_msg_file"
else
	# Otherwise, the existing commit message might contain some content, followed by the footer
	# (i.e., '# Please enter the commit message for your changes.'). Insert the CITags section
	# just before the footer.
	footer_begin="$(grep -n '^# Please enter the commit message for your changes.' -m 1 "$commit_msg_file" | cut -d':' -f 1)"
	if [[ -z "$footer_begin" ]]; then
		# no footer - append at bottom
		cat "$tmpfile" >>"$commit_msg_file"
	else
		tmpfile2="$(mktemp)"
		head -n "$((footer_begin - 1))" "$commit_msg_file" >"$tmpfile2"
		cat "$tmpfile" >>"$tmpfile2"
		echo >>"$tmpfile2"
		tail -n "+${footer_begin}" "$commit_msg_file" >>"$tmpfile2"
		mv "$tmpfile2" "$commit_msg_file"
	fi
fi
rm "$tmpfile"
