#!/usr/bin/env bash


# Dependent packages
REQUIRED_PACKAGES=(yq jq)

# Expected arguments:
# Required mayor version, e.g. 4.0.0
function check_required_yq_version() {
  # Determine yq version
  local yq_system_version="$(yq --version | cut -d' ' -f3)"

  # Check whether the running or the required version is
  printf '%s\n%s\n' "$1" "$yq_system_version"  | sort -V -C
}


function check_environment() {
  # yq 4 introduced breaking syntax changes
  if ! check_required_yq_version "4.0.0"; then
    einfo "You are using yq < 4.0.0, consider upgrading"
  fi
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

  check_environment
}
