#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

gsutil mb -p "$(google-project)" "gs://$(google-project)-vault-storage"
