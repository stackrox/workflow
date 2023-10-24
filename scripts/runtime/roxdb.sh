#!/usr/bin/env bash

# Opens an interactive session to the specified stackrox database, by default attempts to connect to central-db in stackrox namespace.
#
# Accepts an optional positional argument <db>, which specifies the
# database to connect to, valid values are "central" and "scanner"
#
# Example usages:
#   roxdb central        Connects to central-db
#   roxdb scanner        Connects to scanner-db

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

usage() {
  die "Usage: $0 [central/scanner] [namespace]"
}

validate_and_setup() {
  db="$1"
  [[ -n "${db}" ]] || db="central"

  case "$db" in
    "central")
      secret=central-db-password
      label="app=central-db"
      container="central-db"
      database="central_active"
      ;;
    "scanner")
      secret=scanner-db-password
      label="app=scanner-db"
      container="db"
      database="postgres"
      ;;
    *)
      usage
      ;;
  esac

  # hardcode stackrox namespace (for now)
  ns="stackrox"
}

validate_and_setup "$@"

test_in_well_known_dev_context

pass=$(kubectl get secret $secret -o json -n $ns | jq .data.password -r | base64 -d);
kubectl exec -it $(kubectl get pods --no-headers -o custom-columns=":metadata.name" -l $label -n $ns) -n $ns -c $container -- /bin/bash -c "PGPASSWORD=$pass psql -d $database"
