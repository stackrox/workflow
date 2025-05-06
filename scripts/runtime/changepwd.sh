#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Missing new password. Usage: $0 newpassword"
    exit
fi
NEWPASS=`htpasswd -B -n -b admin $1 | base64`

cat > newpass.yaml << EOF
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: central-htpasswd
  namespace: stackrox
  labels:
    app.kubernetes.io/name: stackrox
  annotations:
    "helm.sh/hook": "pre-install"
data:
  htpasswd: $NEWPASS
EOF

kubectl -n stackrox delete secret central-htpasswd
kubectl create -f newpass.yaml

echo "The new password may take time to propagate due to config map propagation times"
