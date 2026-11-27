#!/usr/bin/env bash
# Storage account (AWS: the "account" around S3 buckets). The name is global: lowercase + digits.
# Safe defaults:
#   --allow-shared-key-access false : no access keys, only Entra ID identities
#   --allow-blob-public-access false: no anonymous/public blobs
#   --min-tls-version TLS1_2
# Portal: rg-lab-core -> <account> -> Configuration.
source "$(dirname "$0")/../lib.sh"; source "$(dirname "$0")/.env"; RG=rg-lab-core
az storage account create -g $RG -n "$SA" -l "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --allow-shared-key-access false --allow-blob-public-access false \
  --min-tls-version TLS1_2 -o none
az storage account show -g $RG -n "$SA" --query "{name:name, sharedKey:allowSharedKeyAccess, publicBlob:allowBlobPublicAccess, publicNetwork:publicNetworkAccess}" -o table
