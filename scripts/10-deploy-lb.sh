#!/usr/bin/env bash
set -e

REGION="us-west1"

LB_IP="$(gcloud compute addresses describe vault --region ${REGION} --format 'value(address)')"

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  labels:
    app: vault
spec:
  type: LoadBalancer
  loadBalancerIP: ${LB_IP}
  selector:
    app: vault
  ports:
  - name: vault-port
    port: 443
    targetPort: 8200
    protocol: TCP
EOF
