#!/usr/bin/env bash
set -e

if [ -z "${GOOGLE_CLOUD_PROJECT}" ]; then
  echo "Missing GOOGLE_CLOUD_PROJECT!"
  exit 1
fi

# Create CloudSQL instance
gcloud sql instances create my-instance \
    --database-version MYSQL_5_7 \
    --tier db-f1-micro \
    --region us-east1 \
    --authorized-networks 0.0.0.0/0

INSTANCE_IP="$(gcloud sql instances describe my-instance --format 'value(ipAddresses[0].ipAddress)')"

# Change password
gcloud sql users set-password root \
    --host % \
    --instance my-instance \
    --password my-password

# Enable the gcp secrets engine
vault secrets enable database

# Configure the database secrets engine TTLs
vault write database/config/my-cloudsql-db \
  plugin_name=mysql-database-plugin \
  connection_url="{{username}}:{{password}}@tcp(${INSTANCE_IP}:3306)/" \
  allowed_roles="readonly" \
  username="root" \
  password="my-password"

# Rotate the root cred
vault write -f database/rotate-root/my-cloudsql-db

# Create a role which will create a readonly user
vault write database/roles/readonly \
  db_name=my-cloudsql-db \
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
  bound_service_account_names=default \
  bound_service_account_namespaces=default \
  policies=default,myapp-kv-rw,myapp-db-r \
  ttl=15m
