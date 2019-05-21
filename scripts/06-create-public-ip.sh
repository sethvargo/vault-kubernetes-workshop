#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

gcloud compute addresses create vault \
  --project="$(google-project)" \
  --region="$(google-region)"
