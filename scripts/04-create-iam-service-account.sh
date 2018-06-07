#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi


SERVICE_ACCOUNT="vault-server@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

# Create the service account
gcloud iam service-accounts create vault-server \
  --display-name "vault service account"

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
  gcloud projects add-iam-policy-binding "${GOOGLE_CLOUD_PROJECT}" \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "${role}"
done

# Grant the service account the ability to read and write objects in our storage
# bucket
gsutil iam ch \
  "serviceAccount:${SERVICE_ACCOUNT}:objectAdmin" \
  "serviceAccount:${SERVICE_ACCOUNT}:legacyBucketReader" \
  "gs://${GOOGLE_CLOUD_PROJECT}-vault-storage"

# Grant the service account the ability to access the Cloud KMS crypto key
gcloud kms keys add-iam-policy-binding vault-init \
  --location global \
  --keyring vault \
  --member "serviceAccount:${SERVICE_ACCOUNT}" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
