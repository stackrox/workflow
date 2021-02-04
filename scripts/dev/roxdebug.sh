#!/usr/bin/env bash

set -euo pipefail

DEFAULT_DEPLOYMENT="deploy/central"
DEFAULT_PORT=40000

function usage() {
  echo "Usage: $(basename "$0") [-p port] [deployment]"
  echo "  [deployment]         Pod or deployment that is to be debugged, e.g. deploy/sensor, central-d5bffdf6-wlx5c."
  echo "                       Default deployment: $DEFAULT_DEPLOYMENT"
  echo "  -p, --port number    Local and remote port number to open for debugger connection."
  echo "                       Default port: $DEFAULT_PORT."
  echo "  -h, --help           This message."
  echo ""
  echo "This command attaches dlv debugger to StackRox pod running debug build."
  echo "See https://github.com/stackrox/rox#debugging for complete instructions."
  if [[ -n "${1:-}" ]]; then
    echo ""
    echo >&2 "Error: $1"
    exit 2
  fi
  exit 0
}

positional=()

while (("$#")); do
  case "$1" in
  -h | --help)
    usage ;;
  -p | --port)
    if [[ "${2:-undefined}" == "undefined" ]]; then
      usage "Missing value for $1 argument."
    fi
    port=${2}
    shift ;;
  *)
    positional+=("$1") ;;
  esac
  shift
done

if (("${#positional[@]}" > 1)); then
  usage "Too many [deployment] arguments."
fi

deployment=${positional[0]:-$DEFAULT_DEPLOYMENT}
port=${port:-$DEFAULT_PORT}

echo "Starting port forwarding and debugger for '${deployment}' on port '${port}'. Hit Control-C or Control-\ to stop..."

# Set a handler to interrupt port forwarding process (running as a background job) when this script exits.
trap 'echo Stopping port forward; jobs -pr | xargs -r kill -INT' EXIT

kubectl --namespace stackrox port-forward "${deployment}" "${port}":"${port}" &

# This command should be started in foreground and with -it options so that Control-C can stop debugger.
kubectl --namespace stackrox exec -it "${deployment}" -- /go/bin/dlv --headless --listen=:"${port}" --api-version=2 --accept-multiclient attach 1 --continue
