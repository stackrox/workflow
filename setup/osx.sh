#!/usr/bin/env bash

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../lib/common.sh"

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
brew install jq jsmin 2>/dev/null
[[ $? -eq 0 && -x "$(command -v jq)" && -x "$(command -v jsmin)" ]] || \
	die "Failed to install required packages"

einfo "Checking if ~/.bash_profile is set up correctly ..."
egrep '^\s*(source|\.)\s.*/workflow/env\.sh("|'"'"')?\s*(#.*)?$' ~/.bash_profile >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
	einfo "It looks like your ~/.bash_profile is not set up to read the environment."
	einfo "The following line needs to be added to your ~/.bash_profile:"
	workflow_dir="$(cd "$(dirname "$SCRIPT")/.."; pwd)"
	home_cleaned="${HOME%/}"  # Remove trailing slash, if any
	line='source "'"${workflow_dir/#${home_cleaned}\//\$HOME/}/env.sh"'"'
	eecho "  $line"
	yes_no_prompt "Do you want me to add the above line to your ~/.bash_profile?"
	if [[ $? -eq 0 ]]; then
		echo "$line" >>~/.bash_profile
		einfo "Modified ~/.bash_profile. Type '. ~/.bash_profile' in your current shell for changes to take effect."
	else
		einfo "Not touching ~/.bash_profile."
	fi
else
	einfo "It looks like your ~/.bash_profile is set up correctly."
fi

einfo "Setup completed successfully."
exit 0
