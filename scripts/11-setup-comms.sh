#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

REGION="us-west1"

LB_IP="$(gcloud compute addresses describe vault --region ${REGION} --format 'value(address)')"
GCS_BUCKET="${GOOGLE_CLOUD_PROJECT}-vault-storage"

export VAULT_CACERT="$(pwd)/tls/ca.crt"
export VAULT_ADDR="https://${LB_IP}:443"
export VAULT_TOKEN="$(gsutil cat "gs://${GCS_BUCKET}/root-token.enc" | \
  base64 --decode | \
  gcloud kms decrypt \
    --location global \
    --keyring vault \
    --key vault-init \
    --ciphertext-file - \
    --plaintext-file -)"

export PATH="${PATH}:${HOME}/bin"

alias vualt=vault

exec $SHELL
