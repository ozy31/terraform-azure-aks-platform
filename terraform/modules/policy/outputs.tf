output "assignment_ids" {
  description = "Policy assignment IDs, for exemptions and compliance queries."
  value = merge(
    {
      allowed_locations    = azurerm_subscription_policy_assignment.allowed_locations.id
      allowed_rg_locations = azurerm_subscription_policy_assignment.allowed_rg_locations.id
    },
    { for k, a in azurerm_subscription_policy_assignment.require_rg_tag : "require_rg_tag_${k}" => a.id },
    { for k, a in azurerm_subscription_policy_assignment.inherit_rg_tag : "inherit_rg_tag_${k}" => a.id },
  )
}
