output "namespace" {
  description = "Kubernetes namespace of the tenant."
  value       = local.namespace
}

output "workload_client_id" {
  description = "Client ID annotated on the tenant's service accounts."
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "key_vault_uri" {
  description = "Tenant Key Vault URI, or empty when the tenant has none."
  value       = var.tenant.keyVault ? azurerm_key_vault.this[0].vault_uri : ""
}
