#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

REGION="us-west1"
ZONE="us-west1-b"
SERVICE_ACCOUNT="vault-server@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

kubectl delete pod --force --grace-period=0 kv-sidecar
kubectl delete pod --force --grace-period=0 sa-sidecar

gcloud container clusters delete my-apps \
  --async \
  --quiet \
  --zone "${ZONE}"

vault lease revoke -prefix gcp/

kubectl config use-context "gke_${GOOGLE_CLOUD_PROJECT}_${ZONE}_vault"
kubectl delete service vault
kubectl delete statefulsets --force --grace-period=0 vault

gcloud container clusters delete vault \
  --async \
  --quiet \
  --zone "${ZONE}"

gcloud compute addresses delete vault \
  --region "${REGION}" \
  --quiet

gcloud iam service-accounts delete "${SERVICE_ACCOUNT}" \
  --quiet

gsutil -m rm -rf "gs://${GOOGLE_CLOUD_PROJECT}-vault-storage"
gsutil rb -f "gs://${GOOGLE_CLOUD_PROJECT}-vault-storage"
