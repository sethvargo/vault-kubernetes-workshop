#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

# Create CloudSQL instance
gcloud sql instances create my-instance \
  --project="$(google-project)" \
  --activation-policy="always" \
  --authorized-networks="0.0.0.0/0" \
  --database-version="MYSQL_5_7" \
  --no-backup \
  --region="$(google-region)" \
  --tier="db-n1-standard-1"

INSTANCE_IP="$(gcloud sql instances describe my-instance --project="$(google-project)" --format='value(ipAddresses[0].ipAddress)')"

# Change password
gcloud sql users set-password root \
  --project="$(google-project)" \
  --host="%" \
  --instance="my-instance" \
  --password="my-password"

# Enable the gcp secrets engine
vault secrets enable database

# Configure the database secrets engine TTLs
vault write database/config/my-cloudsql-db \
  plugin_name="mysql-database-plugin" \
  connection_url="{{username}}:{{password}}@tcp(${INSTANCE_IP}:3306)/" \
  allowed_roles="readonly" \
  username="root" \
  password="my-password"

# Rotate the root cred
vault write -f database/rotate-root/my-cloudsql-db

# Create a role which will create a readonly user
vault write database/roles/readonly \
  db_name="my-cloudsql-db" \
  creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}'; GRANT SELECT ON *.* TO '{{name}}'@'%';" \
  default_ttl="1h" \
  max_ttl="24h"

# Create a new policy which allows generating these dynamic credentials
vault policy write myapp-db-r -<<EOF
path "database/creds/readonly" {
  capabilities = ["read"]
}
EOF

# Update the Vault kubernetes auth mapping to include this new policy
vault write auth/kubernetes/role/myapp-role \
  bound_service_account_names="default" \
  bound_service_account_namespaces="default" \
  policies="default,myapp-kv-rw,myapp-db-r" \
  ttl="15m"
