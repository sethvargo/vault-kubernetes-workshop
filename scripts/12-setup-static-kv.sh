#!/usr/bin/env bash
set -e

# This enables the KV secrets engine at the path "kv/"
vault secrets enable -version=2 -path=kv kv

# This creates a policy that allows reading, writing, and deleting from anything
# under "myapp" in the kv secrets engine just created. This policy still must
# be attached to tokens in order to receive the permission(s).
vault policy write myapp-kv-rw - <<EOH
path "kv/data/myapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

# This stores a static credential at kv/myapp/config with a username and
# password for connecting to our myapp application.
vault kv put kv/myapp/config \
  ttl="30s" \
  username="appuser" \
  password="suP3rsec(et!"
