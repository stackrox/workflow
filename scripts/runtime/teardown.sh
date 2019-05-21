#!/usr/bin/env bash

# Tears down a running StackRox installation very quickly.

kubectl -n stackrox delete --now deploy/central deploy/sensor ds/collector deploy/monitoring
kubectl -n stackrox delete secret central-jwt central-tls collector-tls sensor-tls monitoring-ui-tls monitoring-db-tls root-ca monitoring-client-certs monitoring central-htpasswd stackrox collector-stackrox monitoring-client central-htpasswd central-license stackrox-scanner benchmark-tls
kubectl -n stackrox delete cm/influxdb cm/kapacitor cm/chronograf cm/telegraf cm/central cm/telegraf-proxy
kubectl -n stackrox delete pvc/stackrox-db pvc/monitoring-db
kubectl -n stackrox delete svc/monitoring svc/monitoring-loadbalancer svc/central svc/central-loadbalancer svc/sensor
kubectl -n stackrox delete netpol/allow-ext-to-central netpol/allow-ext-to-monitoring
kubectl -n stackrox delete sa --all
kubectl -n stackrox delete validatingwebhookconfiguration/stackrox
helm del --purge monitoring; helm del --purge central
kubectl -n stackrox delete svc/scanner deploy/scanner
kubectl -n stackrox delete scc monitoring
kubectl -n stackrox delete scc central
kubectl -n stackrox delete scc sensor
