#!/usr/bin/env bash
# Network security group nsg-pe: a stateful L4 filter attached to a subnet.
# Lower priority number wins, first match wins; the 65000+ rules are Azure's defaults.
# Here: HTTPS from the AKS subnet is allowed, everything else from inside the VNet is denied.
# Portal: rg-lab-core -> nsg-pe -> Inbound security rules.  AWS: security group / NACL.
source "$(dirname "$0")/../lib.sh"; RG=rg-lab-core
az network nsg create -g $RG -n nsg-pe -l "$LOCATION" -o none
az network nsg rule create -g $RG --nsg-name nsg-pe -n allow-https-from-aks \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 10.1.0.0/22 --destination-port-ranges 443 -o none
az network nsg rule create -g $RG --nsg-name nsg-pe -n deny-all-other-vnet \
  --priority 4000 --direction Inbound --access Deny --protocol '*' \
  --source-address-prefixes VirtualNetwork --destination-port-ranges '*' -o none
az network nsg rule list -g $RG --nsg-name nsg-pe --include-default \
  --query "sort_by([?direction=='Inbound'], &priority)[].{prio:priority, name:name, access:access, src:sourceAddressPrefix, port:destinationPortRange}" -o table
