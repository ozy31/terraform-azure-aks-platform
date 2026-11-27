#!/usr/bin/env bash
# Role assignment "Storage Blob Data Contributor", scoped to THIS storage account only.
# Why: Owner is control plane (manage the account). Reading/writing blobs is data plane and needs
# its own role, so even a subscription Owner gets 403 on blobs without it. Allow a few minutes
# for the assignment to propagate.
# Portal: <account> -> Access control (IAM) -> Role assignments.  AWS: an S3 bucket policy / IAM policy.
source "$(dirname "$0")/../lib.sh"; source "$(dirname "$0")/.env"; RG=rg-lab-core
ME=$(az ad signed-in-user show --query id -o tsv)
SCOPE=$(az storage account show -g $RG -n "$SA" --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SCOPE" -o none
az role assignment list --scope "$SCOPE" --query "[].{role:roleDefinitionName, who:principalName}" -o table
