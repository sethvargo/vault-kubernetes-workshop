#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

SERVICE_ACCOUNT="vault-server@$(google-project).iam.gserviceaccount.com"

gcloud container clusters create vault \
  --project="$(google-project)" \
  --cluster-version="$(gke-latest-master-version)" \
  --enable-autorepair \
  --enable-autoupgrade \
  --enable-ip-alias \
  --machine-type="n1-standard-2" \
  --node-version="$(gke-latest-node-version)" \
  --num-nodes="1" \
  --region="$(google-region)" \
  --scopes="cloud-platform" \
  --service-account="${SERVICE_ACCOUNT}"
