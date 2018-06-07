#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

gcloud kms keyrings create vault \
  --location global

gcloud kms keys create vault-init \
  --location global \
  --keyring vault \
  --purpose encryption
