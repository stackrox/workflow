#!/usr/bin/env bash


# Dependent packages
REQUIRED_PACKAGES=(yq jq)


function check_environment() {
  # Determine yq version
  YQ_SYSTEM_VERSION="$(yq --version | cut -d' ' -f3)"

  local requiredver="4.0.0"  # yq 4 introduced breaking syntax changes
  if [ "$(printf '%s\n' "$requiredver" "$YQ_SYSTEM_VERSION" | sort -V | head -n1)" != "$requiredver" ]; then 
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
