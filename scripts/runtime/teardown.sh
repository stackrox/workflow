#!/usr/bin/env bash

# Tears down a running StackRox installation very quickly, and makes sure no resources we create are left running around.

SCRIPT="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT")/../../lib/common.sh"

test_in_well_known_dev_context

# Collect all stackrox PVs before we delete the respective PVCs.
IFS=$'\n' read -d '' -r -a stackrox_pvs < <(
  kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.namespace == "stackrox") | .metadata.name'
)

# Delete deployments quickly. If we add a new deployment and forget to add it here, it'll get caught in the next line anyway.
kubectl -n stackrox delete --grace-period=0 --force deploy/central deploy/sensor ds/collector deploy/monitoring statefulsets/stackrox-monitoring-alertmanager
kubectl -n stackrox get application -o name | xargs kubectl -n stackrox delete --wait
# DO NOT ADD ANY NON-NAMESPACED RESOURCES TO THIS LIST, OTHERWISE ALL RESOURCES IN THE CLUSTER OF THAT TYPE
# WILL BE DELETED!
kubectl -n stackrox get cm,deploy,ds,hpa,networkpolicy,role,rolebinding,secret,svc,serviceaccount,pvc -o name | xargs kubectl -n stackrox delete --wait
# Only delete cluster-wide RBAC/PSP-related resources that contain have the app.kubernetes.io/name=stackrox label.
kubectl -n stackrox get clusterrole,clusterrolebinding,psp,validatingwebhookconfiguration -o name -l app.kubernetes.io/name=stackrox | xargs kubectl -n stackrox delete --wait

## DO NOT RUN THIS IN A CUSTOMER ENVIRONMENT, IT WILL DELETE ALL THEIR DATA
## AND THEY WILL NEVER TALK TO US AGAIN.
[[ "${#stackrox_pvs[@]}" == 0 ]] || kubectl delete --wait pv "${stackrox_pvs[@]}"

if kubectl api-versions | grep -q openshift.io; then
  for scc in central monitoring scanner sensor stackrox-central stackrox-monitoring stackrox-scanner stackrox-sensor stackrox-central-db; do
    oc delete scc $scc
  done
  oc delete route central -n stackrox
  oc delete route central-mtls -n stackrox
  oc -n kube-system get rolebinding -o name -l app.kubernetes.io/name=stackrox | xargs oc -n kube-system delete --wait
  oc -n openshift-monitoring get prometheusrule,servicemonitor -o name -l app.kubernetes.io/name=stackrox | xargs oc -n openshift-monitoring delete --wait
fi

if [[ "${current_context}" == "docker-desktop" ]]; then
  einfo "On docker-desktop, deleting hostpath (if it exists)"
  docker run --rm -it -v /:/vm-root alpine:edge rm -rf /vm-root/var/lib/stackrox
fi

einfo "Teardown complete."
