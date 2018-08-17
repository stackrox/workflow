#!/usr/bin/env bash

# git commit-msg hook for CITags
# Checks if the commit message is empty after removing CITags, and rejects it if this is the case.

commit_msg_file="$1"

if ! sed '/^CITags:$/q' <"$commit_msg_file" | grep -v '^#' | grep -v -E '^\s*$' >/dev/null ; then
	echo >&2 "Empty commit message (except for CITags), not creating commit."
	exit 1
fi
