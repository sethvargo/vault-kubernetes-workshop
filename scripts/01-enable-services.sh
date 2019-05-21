#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

gcloud services enable \
  --async \
  --project="$(google-project)" \
  cloudapis.googleapis.com \
  cloudkms.googleapis.com \
  cloudresourcemanager.googleapis.com \
  cloudshell.googleapis.com \
  container.googleapis.com \
  containerregistry.googleapis.com \
  iam.googleapis.com
