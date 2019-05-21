#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

SERVICE_ACCOUNT="vault-server@$(google-project).iam.gserviceaccount.com"

# Create the service account
gcloud iam service-accounts create vault-server \
  --project="$(google-project)" \
  --display-name="vault server"

# (Optional) grant the service account the ability to generate new service
# accounts. This is required to use the Vault GCP secrets engine, otherwise it
# can be omitted.
ROLES=(
  "roles/resourcemanager.projectIamAdmin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/iam.serviceAccountTokenCreator"
  "roles/iam.serviceAccountUser"
  "roles/viewer"
)
for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$(google-project)" \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "${role}"
done

# Grant the service account the ability to read and write objects in our storage
# bucket
gsutil iam ch \
  "serviceAccount:${SERVICE_ACCOUNT}:objectAdmin" \
  "serviceAccount:${SERVICE_ACCOUNT}:legacyBucketReader" \
  "gs://$(google-project)-vault-storage"

# Grant the service account the ability to access the Cloud KMS crypto key
gcloud kms keys add-iam-policy-binding vault-init \
  --project="$(google-project)" \
  --location="$(google-region)" \
  --keyring="vault" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
