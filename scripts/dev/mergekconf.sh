#!/usr/bin/env bash

set -euo pipefail
set +x

DEFAULT_BASE_KUBECONFIG="$HOME/.kube/config"

function usage() {
  echo "Usage: $(basename "$0") [-k base kubeconfig file] [-b] [-r new context and user name] [file to merge] "
  echo "  [file to merge]  Path to new kubeconfig file to merge"
  echo "  -k path          Location of base kubeconfig file. This will be overriden."
  echo "                   Default location: $DEFAULT_BASE_KUBECONFIG."
  echo "  -b               Create backup of the base file before merge."
  echo "  -r name          Rename context _and_ user to chosen name. NOTE: ONLY WORKS IF CONFIG HAS EXACTLY ONE CONTEXT & USER"
  echo "  -h               This message."
  echo ""
  echo "This command merges the provided kubeconfig file into the base one used by kubectl."
  if [[ -n "${1:-}" ]]; then
    echo ""
    echo >&2 "Error: $1"
    exit 2
  fi
  exit 0
}

file=()
create_backup=false
rename=""

while (("$#")); do
  case "$1" in
  -h)
    usage
    ;;
  -b)
    create_backup=true
    ;;
  -r)
    if [[ "${2:-undefined}" == "undefined" ]]; then
      usage "Missing value for $1 argument."
    fi
    rename=${2}
    shift
    ;;
  -k)
    if [[ "${2:-undefined}" == "undefined" ]]; then
      usage "Missing value for $1 argument."
    fi
    base_kubeconfig=${2}
    shift
    ;;
  *)
    file+=("$1")
    ;;
  esac
  shift
done

if (("${#file[@]}" != 1)); then
  usage "Need exactly one [file to merge] argument."
fi

# Set default values if necessary
base_kubeconfig=${base_kubeconfig:-$DEFAULT_BASE_KUBECONFIG}

# Create a backup if necessary
if ($create_backup); then
	backup_file=$(mktemp "/tmp/kconfig.bak.XXXXX")
	cp "${base_kubeconfig[@]}" ${backup_file}
	echo "Find backup in ${backup_file}"
fi

# Rename context and user if necessary
if [[ "${rename:-undefined}" != "undefined" ]]; then
	# Copy the kube file to merge over so that the orig file isn't touched
	tmp_renamed=$(mktemp "/tmp/kconfig.renamed.XXXXX")
	cp "${file}" ${tmp_renamed}

	# Get the existing context and username
	# TODO: Make this more elegant if there are more than 1. Maybe error out?
	contextname=$(KUBECONFIG=${tmp_renamed} kubectl config view -ojsonpath='{.contexts[0].name}')
	username=$(KUBECONFIG=${tmp_renamed} kubectl config view -ojsonpath='{.users[0].name}')

	KUBECONFIG=${tmp_renamed} kubectl config rename-context "${contextname}" "${rename}" > /dev/null

	# Frustratingly, kubectl config set doesn't allow you to rename a user
	# thankfully yq should be installed so just use that to drop in replace
	yq e -i '(.users[]|select(.name == "'${username}'").name) |= "'${rename}'"' "${tmp_renamed}"
	yq e -i '(.contexts[]|select(.name == "'${rename}'").context.user) |= "'${rename}'"' "${tmp_renamed}"

	# Use the new renamed file as the file to merge
	file=${tmp_renamed}
fi

tmp_merged=$(mktemp "/tmp/kconfig.merged.XXXXX")

# Don't want to write in place because sometimes it will truncate the file before kubectl can read it
KUBECONFIG=${base_kubeconfig}:${file} kubectl config view --flatten > ${tmp_merged}

mv ${tmp_merged} ${base_kubeconfig}

echo "Merged!"
