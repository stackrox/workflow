#!/usr/bin/env bash

# Imports credentials for a cluster from setup and creates RBAC role bindings.
#
# Usage:
#  getcreds <setup-id>  Imports credentials for a given cluster from setup.

getcreds () 
{ 
    cluster_name=$1
    if [[ -z "${cluster_name}" ]]; then
        if [[ -n "$ROX_SETUP_ID" ]]; then
            cluster_name="setup-${ROX_SETUP_ID}"
        else
            echo >&2 'Please specify a cluster name!'
            return 1
        fi
    fi

    cluster_name="${cluster_name%-rg}"
    gcloud container clusters get-credentials "${cluster_name}" "${@:2}" || {
        return 1
    }
    
    [[ -n "$GCLOUD_USER" ]] || GCLOUD_USER="$(gcloud config get-value account 2>/dev/null)"
    [[ -n "$GCLOUD_USER" ]] || {
        echo >&2 'Please specify a gcloud username via the GCLOUD_USER environment variable'
        return 1
    }
    kubectl create clusterrolebinding "temporary-admin-${GCLOUD_USER%@*}" --clusterrole=cluster-admin --user="$GCLOUD_USER"
    if [[ "$(lsof -n -i tcp:8000 | wc -l)" -gt 0 ]]; then
        echo "WARNING: Port 8000 is bound. You might want to kill the process port-forwarding right now.";
        lsof -n -i tcp:8000;
    fi
}

getcreds "$@"
