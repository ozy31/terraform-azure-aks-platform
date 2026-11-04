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

output "private_dns_zone_ids" {
  description = "Private DNS zone IDs keyed like var.private_dns_zones. Available only once the VNet links exist, so endpoint records resolve as soon as they are created."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
  depends_on  = [azurerm_private_dns_zone_virtual_network_link.this]
}
