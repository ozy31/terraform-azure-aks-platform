#!/usr/bin/env bash
# VNet vnet-spoke (10.1.0.0/16) with subnet snet-aks (10.1.0.0/22, 1024 addresses).
# The spoke is where the application (AKS) lives. Its address space must not overlap the hub.
# Portal: rg-lab-core -> vnet-spoke -> Subnets.
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
az network vnet create -g $RG -n vnet-spoke -l "$LOCATION" \
  --address-prefixes 10.1.0.0/16 \
  --subnet-name snet-aks --subnet-prefixes 10.1.0.0/22 -o none
az network vnet show -g $RG -n vnet-spoke --query "{vnet:name, space:addressSpace.addressPrefixes[0], subnets:subnets[].name}" -o json
