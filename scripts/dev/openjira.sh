#!/usr/bin/env bash

# Opens the web page corresponding to the JIRA ticket for the branch you're on.
# Will only work if either your branch name or your PR title has the JIRA ticket number mentioned in it,
# like SROX-10000 or SROX10001 (but case insensitive).
#
# Usage: openjira (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/git.sh"

function browse_ticket_number() {
  local project="$1"
  local ticket_number="$2"
  project="$(echo "${project}" | tr a-z A-Z)"
  browse "https://stack-rox.atlassian.net/browse/${project}-${ticket_number}"
}

branch="$(get_current_branch)"
[[ -n "${branch}" ]] || die "Couldn't get the current branch."

shopt -s nocasematch
regex="^.*(srox|ap|rox).?([[:digit:]]+).*$"

einfo "Looking in your branch name for the JIRA number..."
[[ "${branch}" =~ ${regex} ]]
project="${BASH_REMATCH[1]}"
ticket_number="${BASH_REMATCH[2]}"
[[ -n "${project}" &&  "${ticket_number}" ]] && { browse_ticket_number ${project} "${ticket_number}"; exit 0; }

einfo "Couldn't find the JIRA number in your branch name. Checking if you have it in your PR title..."

service="$(bitbucket_or_github)"
[[ $? -eq 0 ]] || die

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/${service}.sh"


title="$(get_pr_title)"
[[ -n "${title}" ]] || die "No luck finding your PR title, sorry!"
[[ "${title}" =~ ${regex} ]] || die "Couldn't find SROX-<ticket #> in your PR title \"${title}\""
project="${BASH_REMATCH[1]}"
ticket_number="${BASH_REMATCH[2]}"
[[ -n "${project}" &&  "${ticket_number}" ]] && { browse_ticket_number ${project} "${ticket_number}"; exit 0; }

die "Couldn't find the JIRA number in your title."
