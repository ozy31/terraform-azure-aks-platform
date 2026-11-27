#!/usr/bin/env bash
# VNet peering in BOTH directions: hub-to-spoke and spoke-to-hub.
# Traffic stays on the Microsoft backbone. Peering is NOT transitive: with spoke A <-> hub <-> spoke B,
# A still cannot reach B without a firewall/NVA in the hub and UDRs pointing at it.
# Portal: vnet-spoke -> Peerings (state: Connected).  AWS: VPC peering (Transit Gateway for hub routing).
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
az network vnet peering create -g $RG -n hub-to-spoke --vnet-name vnet-hub \
  --remote-vnet vnet-spoke --allow-vnet-access --allow-forwarded-traffic -o none
az network vnet peering create -g $RG -n spoke-to-hub --vnet-name vnet-spoke \
  --remote-vnet vnet-hub --allow-vnet-access --allow-forwarded-traffic -o none
az network vnet peering list -g $RG --vnet-name vnet-spoke --query "[].{peering:name, state:peeringState}" -o table
