#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

gcloud kms keyrings create vault \
  --project="$(google-project)" \
  --location="$(google-region)"

gcloud kms keys create vault-init \
  --project="$(google-project)" \
  --location="$(google-region)" \
  --keyring="vault" \
  --purpose="encryption"
