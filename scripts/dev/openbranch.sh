#!/usr/bin/env bash

# Opens the web page corresponding to the currently checked-out branch of the repo you're in.
# NOTE: Currently supports Mac OS and Bitbucket only.
# Usage: openbranch (while inside the repo, with the branch you want to open checked out.)

SCRIPT="$(python -c "import os; print(os.path.realpath('$0'))")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

REMOTE=`git config --get remote.origin.url`
if [ -z "$REMOTE" ]; then
  die "Couldn't find the remote."
fi

if [[ "$REMOTE" = git* ]]; then
  REMOTE=https://`echo ${REMOTE#git@} | tr : /`
fi

if [[ "$REMOTE" = *.git ]]; then
  REMOTE=${REMOTE%%.git}
fi

CURR_BRANCH=`get_current_branch`
if [ -z "$CURR_BRANCH" ]; then
  die "Coudn't find the current branch."
fi

open ${REMOTE}/branch/`get_current_branch`
