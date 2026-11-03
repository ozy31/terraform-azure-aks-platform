# Run once, locally, by a subscription owner. Creates:
#   - a storage account for Terraform state (Entra auth only, no keys)
#   - two Entra applications federated to GitHub Actions:
#       plan:  pull requests, read-only on the subscription
#       apply: protected environments, can deploy but can only grant the
#              roles the platform itself assigns
# No client secrets are created; GitHub exchanges its OIDC token directly.

data "azurerm_subscription" "this" {
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "state" {
  name     = "rg-plat-tfstate"
  location = var.location
}

# Access is Entra ID only (shared keys disabled) and versioned. The network
# stays open because GitHub-hosted runners have no fixed IPs; with self-hosted
# runners in a VNet, add network_rules with default_action = "Deny".
#trivy:ignore:AZU-0012 see above
resource "azurerm_storage_account" "state" {
  name                            = var.state_storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

locals {
  identities = {
    plan = {
      subjects = { pull-request = "repo:${var.github_repository}:pull_request" }
    }
    apply = {
      subjects = {
        for env in var.apply_environments : "env-${env}" => "repo:${var.github_repository}:environment:${env}"
      }
    }
  }

  # Roles the platform assigns to its own identities and to tenant groups.
  # The apply identity may create or delete assignments of these roles only,
  # so a compromised pipeline cannot make itself Owner.
  assignable_roles = [
    "AcrPull",
    "Network Contributor",
    "Managed Identity Operator",
    "DNS Zone Contributor",
    "Key Vault Secrets User",
    "Key Vault Secrets Officer",
    "Azure Kubernetes Service Cluster User Role",
    "Azure Kubernetes Service RBAC Writer",
  ]

  role_guids = join(", ", [for r in data.azurerm_role_definition.assignable : r.role_definition_id])

  rbac_admin_condition = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
  EOT
}

data "azurerm_role_definition" "assignable" {
  for_each = toset(local.assignable_roles)

  name  = each.key
  scope = data.azurerm_subscription.this.id
}

resource "azuread_application" "github" {
  for_each = local.identities

  display_name = "github-${replace(var.github_repository, "/", "-")}-${each.key}"
}

resource "azuread_service_principal" "github" {
  for_each = local.identities

  client_id = azuread_application.github[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = merge([
    for id, cfg in local.identities : {
      for name, subject in cfg.subjects : "${id}/${name}" => { identity = id, name = name, subject = subject }
    }
  ]...)

  application_id = azuread_application.github[each.value.identity].id
  display_name   = each.value.name
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value.subject
  audiences      = ["api://AzureADTokenExchange"]
}

# Both identities read and lock state.
resource "azurerm_role_assignment" "state" {
  for_each = local.identities

  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.github[each.key].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_subscription.this.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.github["plan"].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_contributor" {
  scope                = data.azurerm_subscription.this.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github["apply"].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "apply_rbac_admin" {
  scope                = data.azurerm_subscription.this.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.github["apply"].object_id
  principal_type       = "ServicePrincipal"
  condition            = local.rbac_admin_condition
  condition_version    = "2.0"
}
