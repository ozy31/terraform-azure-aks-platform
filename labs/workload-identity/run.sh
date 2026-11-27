#!/usr/bin/env bash
# Renders the two manifests with the identity's client id and the storage account name,
# applies them, and prints the pod's log. Expected: a 10.1.4.x address, "login OK",
# the blob's content, then AuthorizationPermissionMismatch on the write.
set -euo pipefail
cd "$(dirname "$0")"
source ../storage/.env
export STORAGE_ACCOUNT="$SA"
APP_READER_CLIENT_ID=$(terraform -chdir=../aks/terraform output -raw app_reader_client_id)
export APP_READER_CLIENT_ID
K="kubectl --kubeconfig $HOME/.kube/azlab"
# Only our two variables are substituted; $AZURE_* stays for the pod's shell.
envsubst '${APP_READER_CLIENT_ID} ${STORAGE_ACCOUNT}' < 01-namespace-sa.yaml | $K apply -f -
$K -n demo delete pod blob-reader --ignore-not-found
envsubst '${APP_READER_CLIENT_ID} ${STORAGE_ACCOUNT}' < 02-pod-reader.yaml | $K apply -f -
$K -n demo wait --for=jsonpath='{.status.phase}'=Succeeded pod/blob-reader --timeout=180s
$K -n demo logs blob-reader
