#!/usr/bin/env bash
# Private DNS zone privatelink.blob.core.windows.net, linked to both VNets.
# From inside a linked VNet, <account>.blob.core.windows.net CNAMEs to
# <account>.privatelink.blob.core.windows.net, which this zone answers with the private
# endpoint's IP (10.1.4.x). Outside the VNet the same name still resolves to the public IP.
# The privatelink CNAME is normal; what matters is that it ends on the private IP.
# On-prem resolvers need Azure DNS Private Resolver plus a conditional forwarder for the PUBLIC zone name.
# AWS: Route 53 private hosted zone ("private DNS" on an interface endpoint).
# Portal: rg-lab-core -> privatelink.blob.core.windows.net -> Recordsets / Virtual network links.
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
ZONE=privatelink.blob.core.windows.net
az network private-dns zone create -g $RG -n $ZONE -o none
for V in vnet-hub vnet-spoke; do
  az network private-dns link vnet create -g $RG -z $ZONE -n link-$V \
    --virtual-network $V --registration-enabled false -o none
done
az network private-dns link vnet list -g $RG -z $ZONE --query "[].{link:name, state:virtualNetworkLinkState}" -o table
