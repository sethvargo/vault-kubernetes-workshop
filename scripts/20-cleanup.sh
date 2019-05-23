#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

SERVICE_ACCOUNT="vault-server@$(google-project).iam.gserviceaccount.com"

kubectl delete deployment kv-sidecar \
  --cluster="$(gke-cluster-name "my-apps")" \
  --force \
  --grace-period=0

kubectl delete deployment sa-sidecar \
  --cluster="$(gke-cluster-name "my-apps")" \
  --force \
  --grace-period=0

gcloud container clusters delete my-apps \
  --async \
  --quiet \
  --project="$(google-project)" \
  --region="$(google-region)"

vault lease revoke -prefix gcp/

kubectl delete service vault \
  --cluster="$(gke-cluster-name "vault")"

kubectl delete statefulsets vault \
  --cluster="$(gke-cluster-name "vault")" \
  --grace-period=0 \
  --force

gcloud container clusters delete vault \
  --async \
  --quiet \
  --project="$(google-project)" \
  --region="$(google-region)"

gcloud compute addresses delete vault \
  --quiet \
  --project="$(google-project)" \
  --region="$(google-region)"

gcloud iam service-accounts delete "${SERVICE_ACCOUNT}" \
  --quiet \
  --project="$(google-project)"

gsutil -m rm -rf "gs://$(google-project)-vault-storage"
gsutil rb -f "gs://$(google-project)-vault-storage"
