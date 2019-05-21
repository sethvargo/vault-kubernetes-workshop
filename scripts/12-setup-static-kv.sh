#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

# This creates a policy that allows reading, writing, and deleting from anything
# under "myapp" in the kv secrets engine just created. This policy still must
# be attached to tokens in order to receive the permission(s).
vault policy write myapp-kv-rw - <<EOH
path "secret/myapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

# This stores a static credential at secrets/myapp/config with a username and
# password for connecting to our myapp application.
vault kv put secret/myapp/config \
  ttl="30s" \
  username="appuser" \
  password="suP3rsec(et!"
