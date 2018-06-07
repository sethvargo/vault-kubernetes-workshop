#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

# Enable the gcp secrets engine
vault secrets enable gcp

# Configure the gcp secrets engine TTLs
vault write gcp/config ttl=30s max_ttl=5m

# Create a roleset which will determine the permissions that the generated
# service accounts receive
vault write gcp/roleset/myapp-sa \
  secret_type="access_token" \
  project="${GOOGLE_CLOUD_PROJECT}" \
  token_scopes="https://www.googleapis.com/auth/cloud-platform" \
  bindings=-<<EOF
resource "projects/${GOOGLE_CLOUD_PROJECT}" {
  roles = ["roles/viewer"]
}
EOF

# Create a new policy which allows generating these dynamic credentials
vault policy write myapp-sa-r -<<EOF
path "gcp/token/myapp-sa" {
  capabilities = ["read"]
}
EOF

# Update the Vault kubernetes auth mapping to include this new policy
vault write auth/kubernetes/role/myapp-role \
  bound_service_account_names=default \
  bound_service_account_namespaces=default \
  policies=default,myapp-kv-rw,myapp-sa-r \
  ttl=15m
