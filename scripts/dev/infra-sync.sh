#!/usr/bin/env bash
# Fetches cluster artifacts from infra.rox.systems and merges them into a kubeconfig file.

set -euo pipefail

os=$(uname -o)
infra_dir="${HOME}/.kube/infra"
clusters_dir="${infra_dir}/clusters"
infra_kubeconfig="${INFRA_KUBECONFIG:-${infra_dir}/kubeconfig}"
extra_kubeconfigs="${EXTRA_KUBECONFIGS:-}"
original_kubeconfig="${KUBECONFIG:-}"
opts=($@)

clean_infra_cluster_cache() {
    echo "Deleting old cluster artifacts..."
    # Just a couple of safety checks to make sure that we are not attempting to delete
    # something like `/`.
    mkdir -p "${clusters_dir}"
    if [[ ( "${#clusters_dir}" -le 1 ) || ( ! -d "${clusters_dir}" ) ]]; then
        echo >&2 "The clusters directory '${clusters_dir}' does not seem properly initialized."
        exit 1
    fi
    # A call of the form `rm -rf some_directory/*` would fail if `some_directory/*` doesn't
    # evaluate to anything.
    find "${clusters_dir}" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
}

fetch_infra_clusters() {
    export INFRA_TOKEN="${INFRA_TOKEN:-}"
    if [[ "${INFRA_TOKEN}" == "" ]]; then
        case "${os}" in
            "Darwin")
                if token=$(security find-generic-password -s infra.rox.systems -D token -a "" -l acs -w); then
                    INFRA_TOKEN="${token}"
                else
                    echo >&2 "Failed to retrieve token from Keychain"
                    echo >&2 "Use the following command for saving your infra token in Keychain:"
                    echo >&2
                    echo >&2 "  $ security add-generic-password -s infra.rox.systems -D token -a \"\" -l acs -T \"\" -w \"YOUR_INFRA_TOKEN\""
                    echo >&2
                    exit 1
                fi
            ;;
            *)
                echo >&2 "INFRA_TOKEN is not set and support for retrieving a token has not been implemented on ${os}."
                exit 1
            ;;
        esac
    fi

    echo "Syncing your infra clusters..."
    clean_infra_cluster_cache

    # Fetching artifacts for infra clusters.
    cluster_names=""
    if ! cluster_names=$(infractl list "${opts[@]}" --json | jq -r '(.Clusters // [])[] | select(.Status==2).ID'); then
        echo >&2 "Failed to retrieve clusters names from infra."
        exit 1
    fi

    idx=0
    for cluster_name in ${cluster_names}; do
        idx=$((idx + 1))
        cluster_dir="${clusters_dir}/${cluster_name}"
        echo "Downloading artifacts for cluster ${cluster_name} into ${clusters_dir}"
        infractl artifacts "${cluster_name}" --download-dir="${cluster_dir}" >/dev/null
        kubeconfig="${cluster_dir}/kubeconfig"
        chmod 600 "${kubeconfig}"
        echo "Stored kubeconfig at ${kubeconfig}"
    done

    if [[ $idx == 0 ]]; then
        echo "No ready clusters found."
    fi
}

kubecfg_merge() {
    # Backup previous kubeconfig file.
    infra_kubeconfig_backup="${infra_kubeconfig}.bkp"
    if [[ -e "${infra_kubeconfig}" ]]; then
        echo "Backing up previous infra kubeconfig ${infra_kubeconfig} as ${infra_kubeconfig_backup}"
        mv "${infra_kubeconfig}" "${infra_kubeconfig_backup}"
    fi

    # Merge all the kubeconfigs.
    export KUBECONFIG="/dev/null"
    for cluster_dir in "${clusters_dir}"/*; do
        if [ -e "${cluster_dir}/kubeconfig" ]; then
            KUBECONFIG="${KUBECONFIG}:${cluster_dir}/kubeconfig"
        fi
    done
    if [[ -n "${extra_kubeconfigs}" ]]; then
        KUBECONFIG="${KUBECONFIG}:${extra_kubeconfigs}"
    fi

    echo "Merging kube configurations into ${infra_kubeconfig}"
    tmp_infra_kubeconfig=$(mktemp)
    kubectl config view --flatten > "${tmp_infra_kubeconfig}"
    mv "${tmp_infra_kubeconfig}" "${infra_kubeconfig}"
}

fetch_infra_clusters
kubecfg_merge

if [[ "${original_kubeconfig}" != "${infra_kubeconfig}" ]]; then
    echo
    echo "For accessing the infra clusters you can use"
    echo "export KUBECONFIG=\"${infra_kubeconfig}\""
fi
