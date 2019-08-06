#!/usr/bin/env bash

cmd=(kubectl)

case "${0##*/}" in
    k*c)
	if [[ ! -f ./kubeconfig ]]; then
	   echo "No kubeconfig present" >&2
	   exit 1
	fi
	cmd+=(--kubeconfig ./kubeconfig)
	;;
esac


case "${0##*/}" in
    ks*)
	cmd+=(-n stackrox)
	;;
    kk*)
	cmd+=(-n kube-system)
	;;
esac

exec "${cmd[@]}" "$@"
