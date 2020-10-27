#!/usr/bin/env bash

# Dependent packages
REQUIRED_PACKAGES=(yq jq)

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
}

