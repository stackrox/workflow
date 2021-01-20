#!/usr/bin/env bash

PACKAGES_PATH="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")" 
source "$(dirname "$PACKAGES_PATH")/../lib/common.sh"

# Dependent packages
REQUIRED_PACKAGES=(yq jq)


# Expected arguments: Required major version, e.g. "4.0.0"
# Returns:            Whether the running yq version is bigger
function check_min_required_yq_version() {
  # Determine yq version
  local yq_system_version="$(yq --version | cut -d' ' -f3)"
  printf '%s\n%s\n' "$1" "$yq_system_version"  | sort -V -C
}


function check_dependencies() {
  local missing
  missing=()

  # Scan for missing packages
  for pkg in "${REQUIRED_PACKAGES[@]}"
  do
    if [[ ! -x "$(command -v "${pkg}")" ]]; then
      missing+=("$pkg")
    fi
  done

  if [[ "${missing}" != "" ]]; then
    local setup_path
    setup_path="$(dirname "${SCRIPT}")/../../setup.sh"
    efatal "Dependent packages are missing: ${missing[*]}"
    efatal "Please run ${setup_path}"
    exit 1
  fi

  # yq 4 introduced breaking syntax changes
  if ! check_min_required_yq_version "4.0.0"; then
    einfo "You are using yq < 4, consider upgrading to the latest version"
  fi
}
