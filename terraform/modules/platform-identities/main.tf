# One user-assigned identity per platform controller, federated to exactly one
# Kubernetes service account. No client secrets exist anywhere.
locals {
  controllers = {
    cert-manager = {
      namespace       = "cert-manager"
      service_account = "cert-manager"
      roles           = { dns = { scope = var.dns_zone_id, role = "DNS Zone Contributor" } }
    }
    external-dns = {
      namespace       = "external-dns"
      service_account = "external-dns"
      roles           = { dns = { scope = var.dns_zone_id, role = "DNS Zone Contributor" } }
    }
    external-secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
      roles           = { kv = { scope = var.platform_key_vault_id, role = "Key Vault Secrets User" } }
    }
  }

  role_assignments = merge([
    for c, cfg in local.controllers : {
      for k, r in cfg.roles : "${c}/${k}" => merge(r, { controller = c })
    }
  ]...)
}

resource "azurerm_user_assigned_identity" "this" {
  for_each = local.controllers

  name                = "id-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = local.controllers

  name                      = "aks-${each.value.namespace}-${each.value.service_account}"
  user_assigned_identity_id = azurerm_user_assigned_identity.this[each.key].id
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "this" {
  for_each = local.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this[each.value.controller].principal_id
  principal_type       = "ServicePrincipal"
}
