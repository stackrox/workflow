#!/usr/bin/env bash

# Deploys using the most recently built image from the current branch.
#
# Usage: deploy-branch (while inside the repo, with the branch you want to deploy checked out.)

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

# set username and password
username=""
password=""


function set_username_pw_from_dockercfg() {
  local dockercfg="$HOME/.docker/config.json"
  [[ -f "${dockercfg}" ]] || { eecho "No dockercfg file found"; return 1; }
  local credstore="$(jq -r <<<"$(< ${dockercfg})" '.credsStore // ""')"
  [[ -n "${credstore}" ]] || { eecho "No credstore found"; return 1; }
  local helper_cmd="docker-credential-${credstore}"
  if ! type "$helper_cmd" >/dev/null 2>&1 ; then
    eecho "Not using keychain '${credstore}' as credentials helper is unavailable."
    return 1
  fi
  local creds_output
  creds_output="$("$helper_cmd" get <<<docker.io)"
  [[ $? == 0 && -n "$creds_output" ]] || return 1
  username="$(jq -r <<<"${creds_output}" '.Username // ""')"
  password="$(jq -r <<<"${creds_output}" '.Secret // ""')"
}


set_username_pw_from_dockercfg

[[ -n "${username}" && -n "${password}" ]] || {
  eecho "Couldn't read username and password from dockercfg"
  read -p "Enter username for docker.io: " username
  [[ -n "${username}" ]] || { eecho "Aborted."; exit 1; }
  read -s -p "Enter password for ${username} at docker.io: " password
  [[ -n "${password}" ]] || { eecho "Aborted."; exit 1; }
}


function docker_tag_exists() {
  tag=$1
  local token
  token="$(curl -s -H "Content-Type: application/json" -X POST -d  "$(jq --arg username "${username}" --arg password "${password}" -n '{username: $username, password: $password}')" https://hub.docker.com/v2/users/login/| jq -r '.token')"
  [[ -n "${token}" ]] || die "Failed to obtain a token"
  
  # Max allowed page size is 100
  local next_query="https://hub.docker.com/v2/repositories/stackrox/main/tags/?page_size=100"
  found=0
  while true; do
    [[ -n "${next_query}" ]] || break
    echo "Running ${next_query}..."
    local dockerhub_out
    dockerhub_out="$(curl -s -H "Authorization: JWT ${token}" "${next_query}")"
    [[ -n "${dockerhub_out}" ]] || die "Did not receive anything from dockerhub"
    tag_exists="$(jq --arg tag "${tag}" -r <<<"${dockerhub_out}" '[.results | .[] | .name == $tag] | any')"
    echo "Length: $(jq <<<"${dockerhub_out}" '.results | length')"
    if [[ "${tag_exists}" == "true" ]]; then
      found=1
      break
    fi
    next_query="$(jq -r <<<"${dockerhub_out}" '.next // ""')"
  done
  echo "FOUND ${found}"
}

docker_tag_exists $(make tag)
