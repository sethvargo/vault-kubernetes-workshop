#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

if [ -z "${1:-}" ]; then
  echo "Missing pod name!"
  exit 1
fi

POD="$(kubectl get pods \
  --cluster="$(gke-cluster-name "my-apps")" \
  --selector="app=${1}" \
  -o=jsonpath='{.items[0].metadata.name}')"

kubectl logs "${POD}" -c "app" \
  --context="$(gke-cluster-name "my-apps")" \
