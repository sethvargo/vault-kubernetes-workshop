#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

export VAULT_CACERT="$(pwd)/tls/ca.crt"
export VAULT_ADDR="https://$(vault-lb-ip):443"
export VAULT_TOKEN="$(gsutil cat "gs://$(google-project)-vault-storage/root-token.enc" | \
  base64 --decode | \
  gcloud kms decrypt \
    --project="$(google-project)" \
    --location="$(google-region)" \
    --keyring="vault" \
    --key="vault-init" \
    --ciphertext-file - \
    --plaintext-file -)"

export PATH="${PATH}:${HOME}/bin"

alias vualt=vault

exec $SHELL
