#!/usr/bin/env bash

function check_env_installed() {
  case "$(basename $SHELL)" in
    bash)
      check_env_installed_in ~/.bash_profile
    ;;
    zsh)
      check_env_installed_in ~/.zshrc
  ;;
  esac
}

function check_env_installed_in() {
  local dotfile=$1
  einfo "Checking if $dotfile is set up correctly ..."
  if ! egrep '^\s*(source|\.)\s.*/workflow/env\.sh("|'"'"')?\s*(#.*)?$' $dotfile >/dev/null 2>&1; then
    einfo "It looks like your $dotfile is not set up to read the environment."
    einfo "The following line needs to be added to your $dotfile:"
    workflow_dir="$(cd "$(dirname "$SCRIPT")/.."; pwd)"
    home_cleaned="${HOME%/}"  # Remove trailing slash, if any
    line='source "'"${workflow_dir/#${home_cleaned}\//\$HOME/}/env.sh"'"'
    eecho "  $line"
    if yes_no_prompt "Do you want me to add the above line to your ${dotfile}?"; then
      echo "$line" >> $dotfile
      einfo "Modified $dotfile. Type '. $dotfile' in your current shell for changes to take effect."
    else
      einfo "Not touching $dotfile."
    fi
  else
    einfo "It looks like your $dotfile is set up correctly."
  fi
}
