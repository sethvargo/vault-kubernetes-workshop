#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

REGION="us-west1"

LB_IP="$(gcloud compute addresses describe vault --region ${REGION} --format 'value(address)')"
GCS_BUCKET="${GOOGLE_CLOUD_PROJECT}-vault-storage"
KMS_KEY="projects/${GOOGLE_CLOUD_PROJECT}/locations/global/keyRings/vault/cryptoKeys/vault-init"

DIR="$(pwd)/tls"

kubectl create configmap vault \
  --from-literal "load_balancer_address=${LB_IP}" \
  --from-literal "gcs_bucket_name=${GCS_BUCKET}" \
  --from-literal "kms_key_id=${KMS_KEY}"

kubectl create secret generic vault-tls \
  --from-file "${DIR}/ca.crt" \
  --from-file "vault.crt=${DIR}/vault-combined.crt" \
  --from-file "vault.key=${DIR}/vault.key"
