#!/usr/bin/env bash
# Starts dlv debugging session in running pod.
# Run `roxdebug --help` to see its usage help.

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
  echo "This command attaches dlv debugger to StackRox pod. The pod image must be a debug build."
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
    usage
    ;;
  -p | --port)
    if [[ "${2:-undefined}" == "undefined" ]]; then
      usage "Missing value for $1 argument."
    fi
    port=${2}
    shift
    ;;
  *)
    positional+=("$1")
    ;;
  esac
  shift
done

if (("${#positional[@]}" > 1)); then
  usage "Too many [deployment] arguments."
fi

deployment=${positional[0]:-$DEFAULT_DEPLOYMENT}
port=${port:-$DEFAULT_PORT}

target_is_pod="false"
deployment_name=""

if [[ ! ($deployment =~ ^deploy/ || $deployment =~ ^deployment/) ]]; then
  deployment="pod/${deployment}"
  target_is_pod="true"
fi
deployment_name="$(kubectl -n stackrox get "${deployment}" -o "jsonpath={.metadata.labels.app}")"

container_name=""
case "${deployment_name}" in
  central)
    container_name="central"
    ;;
  sensor)
    container_name="sensor"
    ;;
  scanner)
    container_name="scanner"
    ;;
  scanner-v4-matcher)
    container_name="matcher"
    ;;
  scanner-v4-indexer)
    container_name="indexer"
    ;;
  *)
    echo >&2 "Unknown deployment '$deployment', cannot tell which container is to be debugged."
    exit 1
    ;;
esac

if [[ $target_is_pod == "true" ]]; then
  echo "Pod: ${deployment}"
else
  echo "Deployment: ${deployment}"
fi
echo "container: ${container_name}"
echo

# dlv seems to require a writable filesystem.
ensure_target_filesystem_is_writable() {
  local read_only_root_fs
  if [[ "${target_is_pod}" == "true" ]]; then
    read_only_root_fs="$(kubectl -n stackrox get "${deployment}" \
      -o=jsonpath="{.spec.containers[?(@.name=='${container_name}')].securityContext.readOnlyRootFilesystem}")"
    if [[ $read_only_root_fs == "true" ]]; then
      echo >&2 "Cannot debug ${deployment}: the pod uses a read-only root filesystem"
      exit 1
    fi
  else
    read_only_root_fs="$(kubectl -n stackrox get "${deployment}" -o=jsonpath="{.spec.template.spec.containers[?(@.name=='${container_name}')].securityContext.readOnlyRootFilesystem}")"
    if [[ "${read_only_root_fs}" == "true" ]]; then
      local patch_root_fs_ro="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${deployment_name}\",\"securityContext\":{\"readOnlyRootFilesystem\":true}}]}}}}"
      local patch_root_fs_rw="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${deployment_name}\",\"securityContext\":{\"readOnlyRootFilesystem\":false}}]}}}}"
      echo "Configuring root filesystem of container ${container_name} within ${deployment} to be read-write."
      echo "Remember to undo this change after debugging. For example, by executing:"
      echo "  $ kubectl -n stackrox patch '${deployment}' -p '${patch_root_fs_ro}'"
      echo
      kubectl -n stackrox patch "${deployment}" -p "${patch_root_fs_rw}"
      # Unfortunately kubectl wait cannot wait yet for creation of new resources (pods, in this case).
      # Hence, as a workaround to prevent a race here we need to wait a couple of seconds.
      sleep 5
      kubectl -n stackrox wait --for=condition=Ready pod -l app="${deployment_name}" --timeout=60s
    fi
  fi
}

function ensure_debugging_is_allowed() {
  ptrace_scope_file="/proc/sys/kernel/yama/ptrace_scope"
  # If /proc/sys/kernel/yama/ptrace_scope is present and it contains anything non-zero, the following error will appear
  # during `dlv attach` attempt:
  #    Could not attach to pid 1: this could be caused by a kernel security setting, try writing "0" to /proc/sys/kernel/yama/ptrace_scope
  # This is likely on MacOS Docker and in some cloud environments.

  # First, we check if anything needs adjustment. We read the current value by exec-ing into the existing deployment
  # because a) that's much faster than spinning up a new image, and b) we read the value from the same node where
  # the deployment is running.
  ptrace_scope_state=$(kubectl --namespace stackrox exec "${deployment}" -- /bin/sh -c "[ -e ${ptrace_scope_file} ] && cat ${ptrace_scope_file} || echo 0")
  if [[ "${ptrace_scope_state}" != "0" ]]; then
    echo "${ptrace_scope_file} is currently set to ${ptrace_scope_state}, trying to change it to 0"

    # Find out node where the pod is deployed.
    if [[ "${deployment}" =~ ^deploy/ ]]; then # $deployment is like "deploy/central"
      # We rely on `app` label (e.g. app=central).
      # In case this turns unreliable, something like this should be done https://github.com/kubernetes/kubernetes/issues/72794#issuecomment-483502617
      selector="--selector=app=${deployment/deploy\//}"
      jsonpath="{.items[0].spec.nodeName}"
    else # $deployment it is just a pod name e.g. "central-d5bffdf6-wlx5c"
      selector="${deployment}"
      jsonpath="{.spec.nodeName}"
    fi
    node_name=$(kubectl -n stackrox get pods "${selector}" --output jsonpath="${jsonpath}")

    # Run one-off privileged container on the target node. The container will write 0 to the file.
    # The file is mounted from the node and so the privileged container should be able to change it for all pods on the node.
    kubectl -n stackrox run -it --rm --restart=Never \
      --privileged \
      --overrides "{ \"spec\": { \"nodeName\": \"${node_name}\" } }" \
      --image=alpine debug-enabler -- /bin/sh -c "echo 0 > ${ptrace_scope_file}"
  fi
}

ensure_debugging_is_allowed
ensure_target_filesystem_is_writable

echo "Starting port forwarding and debugger for '${deployment}' on port '${port}'. Hit Control-C or Control-\ to stop..."

# Set a handler to interrupt port forwarding process (running as a background job) when this script exits.
trap 'echo Stopping port forward; jobs -pr | xargs -r kill -INT' EXIT

kubectl --namespace stackrox port-forward "${deployment}" "${port}":"${port}" &

# This command should be started in foreground and with -it options so that Control-C can stop debugger.
kubectl --namespace stackrox exec -it "${deployment}" -- /bin/sh -c "cd /tmp; /go/bin/dlv --headless --listen=:\"${port}\" --api-version=2 --accept-multiclient attach 1 --continue"
