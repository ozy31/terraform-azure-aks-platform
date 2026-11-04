locals {
  # /16 -> nodes /22, API server /28, private endpoints /24.
  subnets = {
    nodes             = cidrsubnet(var.address_space, 6, 0)
    apiserver         = cidrsubnet(var.address_space, 12, 1024)
    private_endpoints = cidrsubnet(var.address_space, 8, 8)
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "nodes" {
  name                            = "snet-aks-nodes"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.subnets.nodes]
  default_outbound_access_enabled = false

  # Key Vault and ACR are reached over private endpoints. Storage keeps a
  # service endpoint so storage firewalls can allow this subnet.
  service_endpoint {
    service = "Microsoft.Storage"
  }
}

# API Server VNet Integration: the control plane gets an internal load balancer
# in this delegated subnet, so node -> API server traffic never leaves the VNet.
resource "azurerm_subnet" "apiserver" {
  name                            = "snet-aks-apiserver"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [local.subnets.apiserver]
  default_outbound_access_enabled = false

  delegation {
    name = "aks"

    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [local.subnets.private_endpoints]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "nodes" {
  name                = "nsg-${var.name}-aks-nodes"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Public ingress reaches the Istio gateway through the Azure load balancer.
# AKS updates the NSG it owns in the node resource group, not a custom subnet
# NSG like this one, so web traffic must be allowed here explicitly. Everything
# else from the internet is denied by the NSG default rules.
#trivy:ignore:AZU-0047 public web ingress is the purpose of the shared gateway
resource "azurerm_network_security_rule" "https_in" {
  name                        = "allow-https-from-internet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

# Egress goes through a NAT gateway with a fixed public IP prefix, so the
# platform has a small, known set of egress IPs and no SNAT port exhaustion
# from the cluster load balancer.
resource "azurerm_public_ip_prefix" "egress" {
  name                = "ippre-${var.name}-egress"
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix_length       = var.nat_public_ip_prefix_length
  sku                 = "Standard"
  zones               = var.zones
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  name                    = "ng-${var.name}"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = var.zones
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "this" {
  nat_gateway_id      = azurerm_nat_gateway.this.id
  public_ip_prefix_id = azurerm_public_ip_prefix.egress.id
}

resource "azurerm_subnet_nat_gateway_association" "nodes" {
  subnet_id      = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}

# Private DNS zones for the private endpoints in this VNet. Azure does not
# create these: without a zone linked to the VNet, the service name keeps
# resolving to its public IP and traffic never reaches the private endpoint.
resource "azurerm_private_dns_zone" "this" {
  for_each = var.private_dns_zones

  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.private_dns_zones

  name                 = "link-${var.name}"
  private_dns_zone_id  = azurerm_private_dns_zone.this[each.key].id
  virtual_network_id   = azurerm_virtual_network.this.id
  registration_enabled = false
  tags                 = var.tags
}
