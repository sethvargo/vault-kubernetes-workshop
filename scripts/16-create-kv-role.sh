#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

vault write auth/kubernetes/role/myapp-role \
  bound_service_account_names="default" \
  bound_service_account_namespaces="default" \
  policies="default,myapp-kv-rw" \
  ttl="15m"
