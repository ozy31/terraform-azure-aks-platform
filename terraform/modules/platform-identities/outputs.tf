output "client_ids" {
  description = "Client ID per controller, passed to Flux as substitution variables for the service account annotations."
  value       = { for k, v in azurerm_user_assigned_identity.this : k => v.client_id }
}
