#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${0}")" &>/dev/null && pwd)/__helpers.sh"

DIR="$(pwd)/tls"

# Get the name of the secret corresponding to the service account
SECRET_NAME="$(kubectl get serviceaccount vault-auth \
  --cluster="$(gke-cluster-name "my-apps")" \
  -o go-template='{{ (index .secrets 0).name }}')"

# Get the actual token reviewer account
TR_ACCOUNT_TOKEN="$(kubectl get secret ${SECRET_NAME} \
  --cluster="$(gke-cluster-name "my-apps")" \
  -o go-template='{{ .data.token }}' | base64 --decode)"

# Get the host for the cluster (IP address)
K8S_HOST="$(kubectl config view --raw \
  -o go-template="{{ range .clusters }}{{ if eq .name \"$(gke-cluster-name "my-apps")\" }}{{ index .cluster \"server\" }}{{ end }}{{ end }}")"

# Get the CA for the cluster
K8S_CACERT="$(kubectl config view --raw \
  -o go-template="{{ range .clusters }}{{ if eq .name \"$(gke-cluster-name "my-apps")\" }}{{ index .cluster \"certificate-authority-data\" }}{{ end }}{{ end }}" | base64 --decode)"

# Enable the Kubernetes auth method
vault auth enable kubernetes

# Configure Vault to talk to our Kubernetes host with the cluster's CA and the
# correct token reviewer JWT token
vault write auth/kubernetes/config \
  kubernetes_host="${K8S_HOST}" \
  kubernetes_ca_cert="${K8S_CACERT}" \
  token_reviewer_jwt="${TR_ACCOUNT_TOKEN}"

# Create a config map to store the vault address
kubectl create configmap vault \
  --cluster="$(gke-cluster-name "my-apps")" \
  --from-literal "vault_addr=https://$(vault-lb-ip)"

# Create a secret for our CA
kubectl create secret generic vault-tls \
  --cluster="$(gke-cluster-name "my-apps")" \
  --from-file "${DIR}/ca.crt"
