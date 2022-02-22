#!/usr/bin/env bash

# [DEPRECATED] Alias for `kubectl config current-context`.
# This command is deprecated and will eventually be removed.
# Please just use `kubectl config current-context` (or your own alias for it) instead.


SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"

kubectl config current-context
