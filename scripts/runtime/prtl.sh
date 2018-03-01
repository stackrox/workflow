#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

[[ -n "$ROX_PORTAL_IP" ]] || die "ROX_PORTAL_IP is not set"

browse "https://${ROX_PORTAL_IP}/"
roxc auth export | clipboard_copy
