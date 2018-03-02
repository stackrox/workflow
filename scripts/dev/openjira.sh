#!/usr/bin/env bash

# Opens the web page corresponding to the JIRA ticket for the branch you're on.
# Will only work if either your branch name or your PR title has the JIRA ticket number mentioned in it,
# like SROX-10000 or SROX10001 (but case insensitive).
#
# Usage: openjira (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/bitbucket.sh"

function browse_ticket_number() {
  local ticket_number="$1"
  browse "https://stack-rox.atlassian.net/browse/SROX-${ticket_number}"
}

branch="$(get_current_branch)"
[[ -n "${branch}" ]] || die "Couldn't get the current branch."

shopt -s nocasematch
regex="^.*srox.?([[:digit:]]+).*$"

einfo "Looking in your branch name for the JIRA number..."
[[ "${branch}" =~ ${regex} ]]
ticket_number="${BASH_REMATCH[1]}"
[[ -n "${ticket_number}" ]] && { browse_ticket_number "${ticket_number}"; exit 0; }

einfo "Couldn't find the JIRA number in your branch name. Checking if you have it in your PR title..."
title="$(get_pr_title)"
[[ -n "${title}" ]] || die "No luck finding your PR title, sorry!"
[[ "${title}" =~ ${regex} ]] || die "Couldn't find SROX-<ticket #> in your PR title \"${title}\""
ticket_number="${BASH_REMATCH[1]}"
[[ -n "${ticket_number}" ]] || die "Couldn't extract the ticket number from your PR title \"${title}\""
browse_ticket_number "${ticket_number}"
