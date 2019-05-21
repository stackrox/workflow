#!/usr/bin/env bash

# Tears down a running StackRox installation very quickly, and makes sure no resources we create are left running around.


# Delete deployments quickly. If we add a new deployment and forget to add it here, it'll get caught in the next line anyway.
kubectl -n stackrox delete --grace-period=0 --force deploy/central deploy/sensor ds/collector deploy/monitoring
kubectl -n stackrox get cm,deploy,ds,networkpolicy,secret,svc,serviceaccount,validatingwebhookconfiguration -o name | xargs kubectl -n stackrox delete --wait

## DO NOT RUN THIS IN A CUSTOMER ENVIRONMENT, IT WILL DELETE ALL THEIR DATA
## AND THEY WILL NEVER TALK TO US AGAIN.
kubectl -n stackrox get pv,pvc -o name | xargs kubectl -n stackrox delete --wait

for scc in central monitoring scanner sensor; do
  oc delete scc $scc
done
