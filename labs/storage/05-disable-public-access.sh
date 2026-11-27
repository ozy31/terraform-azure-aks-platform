#!/usr/bin/env bash
# Close the storage account to the internet (publicNetworkAccess = Disabled).
# From now on only the private endpoint works; the same command from a laptop is refused.
# Portal: <account> -> Networking -> Public network access: Disabled.
source "$(dirname "$0")/../lib.sh"; source "$(dirname "$0")/.env"; RG=rg-lab-core
az storage account update -g $RG -n "$SA" --public-network-access Disabled -o none
az storage account show -g $RG -n "$SA" --query "{name:name, publicNetwork:publicNetworkAccess, privateEndpoints:length(privateEndpointConnections)}" -o table
