#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../lib/common.sh"
source "$(dirname "$SCRIPT")/../lib/shell_config.sh"
source "$(dirname "$SCRIPT")/../setup/packages.sh"

einfo "Checking for Homebrew ..."
if [[ ! -x "$(command -v brew)" ]]; then
	einfo "Looks like Homebrew is not installed. Installing ..."
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	[[ $? -eq 0 && -x "$(command -v brew)" ]] || die "Error installing Homebrew"
	einfo "Homebrew installation successful."
else
	einfo "Found Homebrew."
fi

einfo "Installing missing packages, if any ..."
IFS=$'\n' read -d '' -r -a missing_packages < <(
	{
		brew ls --versions "${REQUIRED_PACKAGES[@]}" | awk '{print$1}'
		printf "%s\n" "${REQUIRED_PACKAGES[@]}"
	} | sort | uniq -u
)
status=0
if [[ "${#missing_packages[@]}" > 0 ]]; then
	brew install "${missing_packages[@]}"
	status=$?
fi
[[ $status == 0 && -x "$(command -v jq)" ]] || \
	die "Failed to install required packages"

check_env_installed

einfo "Setup completed successfully."
exit 0
