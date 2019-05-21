#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

kubectl apply \
  --cluster="$(gke-cluster-name "vault")" \
  --filename="k8s/vault.yaml"
