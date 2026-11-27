#!/usr/bin/env bash
# Subnet snet-pe (10.1.4.0/24) in vnet-spoke, with nsg-pe attached.
# Private endpoints (the private IPs of Storage, Key Vault, ACR) live here.
# private-endpoint-network-policies Enabled: NSG rules also apply to the private endpoints.
# Portal: vnet-spoke -> Subnets -> snet-pe (Network security group column shows nsg-pe).
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
az network vnet subnet create -g $RG --vnet-name vnet-spoke -n snet-pe \
  --address-prefixes 10.1.4.0/24 --network-security-group nsg-pe \
  --private-endpoint-network-policies Enabled -o none
az network vnet subnet list -g $RG --vnet-name vnet-spoke --query "[].{subnet:name, prefix:addressPrefix, nsg:networkSecurityGroup.id}" -o table
