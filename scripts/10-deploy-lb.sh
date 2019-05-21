#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

kubectl apply \
  --cluster="$(gke-cluster-name "vault")" \
  --filename=-<<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  labels:
    app: vault
spec:
  type: LoadBalancer
  loadBalancerIP: $(vault-lb-ip)
  externalTrafficPolicy: Local
  selector:
    app: vault
  ports:
  - name: vault-port
    port: 443
    targetPort: 8200
    protocol: TCP
EOF
