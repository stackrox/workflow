#!/usr/bin/env bash

# Opens an interactive session to the specified stackrox database, by default attempts to connect to central-db in stackrox namespace.
#
# Accepts an optional positional argument <db>, which specifies the
# database to connect to, valid values are "central" and "scanner". 
#
# Also accepts an optional namespace flag "-n <namespace>".
#
# Example usages:
#   roxdb central                      Connects to central-db
#   roxdb scanner                      Connects to scanner-db
#   roxdb -n rhacs-operator scanner    Connects to scanner-db in rhacs-operator namespace

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

usage() {
  die "Usage: $0 [-n <namespace>] [central/scanner]"
}

validate_and_setup() {
  num_args=0
  while [[ "${#}" -gt 0 ]]; do
    case "${1}" in
      -n)
        ns="${2}"

        # if no value, print usage
        [[ -z "${ns}" ]] && usage
        shift 2
        ;;
      *)
        # if already have a positional argument, are too many args
        [[ $num_args -gt 0 ]] && usage

        db="${1}"
        num_args=$((num_args+1))
        shift
        ;;
    esac
  done

  # set defaults if not specified via args
  [[ -n "${db}" ]] || db="central"
  [[ -n "${ns}" ]] || ns="stackrox"

  case "$db" in
    "central")
      secret="central-db-password"
      label="app=central-db"
      container="central-db"
      database="central_active"
      ;;
    "scanner")
      secret="scanner-db-password"
      label="app=scanner-db"
      container="db"
      database="postgres"
      ;;
    "scanner4")
      secret="scanner-v4-db-password"
      label="app=scanner-v4-db"
      container="db"
      database="postgres"
      ;;
    *)
      usage
      ;;
  esac
}

validate_and_setup "$@"

test_in_well_known_dev_context

pass=$(kubectl get secret $secret -o json -n $ns | jq .data.password -r | base64 -d);
kubectl exec -it $(kubectl get pods --no-headers -o custom-columns=":metadata.name" -l $label -n $ns) -n $ns -c $container -- /bin/bash -c "PGPASSWORD=$pass psql -d $database"
