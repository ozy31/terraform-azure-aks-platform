output "vnet_id" {
  description = "VNet ID."
  value       = azurerm_virtual_network.this.id
}

output "node_subnet_id" {
  description = "Subnet for AKS nodes (system pool and auto-provisioned nodes)."
  value       = azurerm_subnet.nodes.id
}

output "apiserver_subnet_id" {
  description = "Delegated subnet for API Server VNet Integration."
  value       = azurerm_subnet.apiserver.id
}

output "private_endpoint_subnet_id" {
  description = "Subnet for private endpoints."
  value       = azurerm_subnet.private_endpoints.id
}

output "egress_ip_prefix" {
  description = "Public IP prefix used for all cluster egress."
  value       = azurerm_public_ip_prefix.egress.ip_prefix
}

output "nat_gateway_id" {
  description = "NAT gateway ID. The cluster must not be created before the subnet association exists."
  value       = azurerm_subnet_nat_gateway_association.nodes.nat_gateway_id
}
