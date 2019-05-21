#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

# Create a cluster to do process namespace sharing
gcloud container clusters create my-apps \
  --project="$(google-project)" \
  --cluster-version="$(gke-latest-master-version)" \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --machine-type=n1-standard-2 \
  --node-version="$(gke-latest-node-version)" \
  --num-nodes=1 \
  --region="$(google-region)" \
  --scopes="cloud-platform"
