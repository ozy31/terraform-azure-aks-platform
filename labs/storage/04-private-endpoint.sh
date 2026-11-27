#!/usr/bin/env bash
# Private endpoint pe-stlab-blob in snet-pe (Azure creates a NIC behind it).
# It gives the storage account's blob service a PRIVATE IP in our subnet.
#   --group-id blob : blob only; file/queue/table each need their own endpoint.
#   dns-zone-group  : writes and removes the endpoint's A record in the private zone automatically.
# AWS: interface VPC endpoint (PrivateLink).
# Portal: rg-lab-core -> pe-stlab-blob -> DNS configuration (FQDN <-> 10.1.4.x).
source "$(dirname "$0")/../lib.sh"; source "$(dirname "$0")/.env"; RG=rg-lab-core
SA_ID=$(az storage account show -g $RG -n "$SA" --query id -o tsv)
az network private-endpoint create -g $RG -n pe-stlab-blob -l "$LOCATION" \
  --vnet-name vnet-spoke --subnet snet-pe \
  --private-connection-resource-id "$SA_ID" --group-id blob \
  --connection-name conn-stlab-blob -o none
az network private-endpoint dns-zone-group create -g $RG --endpoint-name pe-stlab-blob \
  -n default --private-dns-zone privatelink.blob.core.windows.net --zone-name blob -o none
az network private-endpoint show -g $RG -n pe-stlab-blob \
  --query "customDnsConfigs[].{fqdn:fqdn, ip:ipAddresses[0]}" -o table
az network private-dns record-set a list -g $RG -z privatelink.blob.core.windows.net \
  --query "[].{record:name, ip:aRecords[0].ipv4Address}" -o table
