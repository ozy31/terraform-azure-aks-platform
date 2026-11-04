# Subscription guardrails with built-in Azure Policy definitions. Gatekeeper
# governs what runs inside the cluster; these govern the Azure resources
# around it, including ones created outside this repository.

locals {
  # Built-ins are looked up by display name: their GUIDs are stable but
  # unreadable in a plan.
  definitions = {
    allowed_locations    = "Allowed locations"
    allowed_rg_locations = "Allowed locations for resource groups"
    require_rg_tag       = "Require a tag on resource groups"
    inherit_rg_tag       = "Inherit a tag from the resource group if missing"
  }
}

data "azurerm_policy_definition" "builtin" {
  for_each = local.definitions

  display_name = each.value
}

resource "azurerm_subscription_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Platform: resources only in ${join(", ", var.allowed_locations)}"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.builtin["allowed_locations"].id
  enforce              = var.enforce

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })

  non_compliance_message {
    content = "Platform resources are kept in ${join(", ", var.allowed_locations)} for data residency."
  }
}

resource "azurerm_subscription_policy_assignment" "allowed_rg_locations" {
  name                 = "allowed-rg-locations"
  display_name         = "Platform: resource groups only in ${join(", ", var.allowed_locations)}"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.builtin["allowed_rg_locations"].id
  enforce              = var.enforce

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
  })
}

# Every resource group must say who pays for it, and resources inside inherit
# the tag, so cost reports can be split by team without tagging every resource.
resource "azurerm_subscription_policy_assignment" "require_rg_tag" {
  for_each = toset(var.required_tags)

  name                 = "require-rg-tag-${each.key}"
  display_name         = "Platform: resource groups need a ${each.key} tag"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.builtin["require_rg_tag"].id
  enforce              = var.enforce

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  non_compliance_message {
    content = "Add a ${each.key} tag to the resource group."
  }
}

resource "azurerm_subscription_policy_assignment" "inherit_rg_tag" {
  for_each = toset(var.required_tags)

  name                 = "inherit-rg-tag-${each.key}"
  display_name         = "Platform: inherit ${each.key} from the resource group"
  subscription_id      = var.subscription_id
  policy_definition_id = data.azurerm_policy_definition.builtin["inherit_rg_tag"].id
  enforce              = var.enforce
  location             = var.location

  parameters = jsonencode({
    tagName = { value = each.key }
  })

  # Modify policies act through their own identity.
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "inherit_rg_tag" {
  for_each = azurerm_subscription_policy_assignment.inherit_rg_tag

  scope                = var.subscription_id
  role_definition_name = "Tag Contributor"
  principal_id         = each.value.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
