#!/usr/bin/env bash

# killpf <port> kills a kubectl port-forward running on the passed port, if there is one.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

port="$1"
[[ -n "${port}" ]] || die "Usage: $0 <port>"

pid="$(lsof -n -i tcp:"${port}" | grep kubectl | awk '{print $2}' | uniq)"
[[ -n "${pid}" ]] || { einfo "No port-forward is running on port ${port}."; exit 0; }

kill "${pid}" || die "Kill failed"

total_time=0
TIMEOUT=10
while kill -0 "${pid}" >/dev/null 2>&1; do 
  total_time=$((total_time + 1))
  (( total_time < TIMEOUT )) || die "Process is still alive after ${TIMEOUT} seconds. Something is wrong..."
  sleep 1
done
