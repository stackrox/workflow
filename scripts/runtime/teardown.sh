#!/usr/bin/env bash

# Tears down a running StackRox installation very quickly, and makes sure no resources we create are left running around.

SCRIPT="$(python -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

well_known_dev_context_regexes=(docker-for-desktop gke.*setup-dev.*)

current_context="$(kubectl config current-context)"

matched=0
for regex in "${well_known_dev_context_regexes[@]}"; do
  if [[ ${current_context} =~ ^${regex} ]]; then
    matched=1
    break
  fi
done

if (( matched == 0 )); then
  yes_no_prompt "Detected that you're connected to cluster ${current_context}, which is not a well-known dev environment. Are you sure you want to proceed with the teardown?" || { eecho "Exiting as requested"; exit 1; }
fi

# Delete deployments quickly. If we add a new deployment and forget to add it here, it'll get caught in the next line anyway.
kubectl -n stackrox delete --grace-period=0 --force deploy/central deploy/sensor ds/collector deploy/monitoring
kubectl -n stackrox get cm,deploy,ds,networkpolicy,secret,svc,serviceaccount,validatingwebhookconfiguration -o name | xargs kubectl -n stackrox delete --wait

## DO NOT RUN THIS IN A CUSTOMER ENVIRONMENT, IT WILL DELETE ALL THEIR DATA
## AND THEY WILL NEVER TALK TO US AGAIN.
kubectl -n stackrox get pv,pvc -o name | xargs kubectl -n stackrox delete --wait

for scc in central monitoring scanner sensor; do
  oc delete scc $scc
done
