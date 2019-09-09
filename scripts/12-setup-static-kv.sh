#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

# Enable kv secrets engine - this used to be enabled by default at secret/, but
# that's not the case anymore.
vault secrets enable kv

# This creates a policy that allows reading, writing, and deleting from anything
# under "myapp" in the kv secrets engine just created. This policy still must
# be attached to tokens in order to receive the permission(s).
vault policy write myapp-kv-rw - <<EOH
path "kv/myapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOH

# This stores a static credential at secrets/myapp/config with a username and
# password for connecting to our myapp application.
vault kv put kv/myapp/config \
  ttl="30s" \
  username="appuser" \
  password="suP3rsec(et!"
