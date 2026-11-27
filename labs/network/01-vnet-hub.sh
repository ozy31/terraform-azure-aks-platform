#!/usr/bin/env bash
# VNet vnet-hub (10.0.0.0/16) with subnet snet-shared (10.0.1.0/24).
# The hub holds shared services: firewall, VPN/ExpressRoute gateway, DNS resolver.
# Portal: rg-lab-core -> vnet-hub -> Subnets / Address space.  AWS: a VPC (often a transit/shared VPC).
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
az network vnet create -g $RG -n vnet-hub -l "$LOCATION" \
  --address-prefixes 10.0.0.0/16 \
  --subnet-name snet-shared --subnet-prefixes 10.0.1.0/24 -o none
az network vnet show -g $RG -n vnet-hub --query "{vnet:name, space:addressSpace.addressPrefixes[0], subnets:subnets[].name}" -o json
