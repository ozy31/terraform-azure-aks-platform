locals {
  namespace = var.tenant.name
  # Key Vault names are global and limited to 24 characters.
  key_vault_name = substr("kv-${var.name_prefix}-${var.tenant.name}", 0, 24)
  tags           = merge(var.tags, { tenant = var.tenant.name, cost-center = var.tenant.costCenter })
}

# --- Kubernetes access -------------------------------------------------------
# The owning Entra group can fetch credentials for the cluster and gets write
# access to its own namespace only. Azure RBAC is evaluated by the API server,
# so there is no RoleBinding to drift or to be edited from inside the cluster.

resource "azurerm_role_assignment" "cluster_user" {
  scope                = var.cluster_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.tenant.ownerGroupId
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "namespace_writer" {
  scope                = "${var.cluster_id}/namespaces/${local.namespace}"
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.tenant.ownerGroupId
  principal_type       = "Group"
}

# --- Workload identity ------------------------------------------------------
# One identity per tenant, federated to each service account the tenant
# declares. Pods use it to reach Azure services without secrets.

resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${var.name_prefix}-tenant-${var.tenant.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "workload" {
  for_each = toset(var.tenant.serviceAccounts)

  name                      = "aks-${local.namespace}-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.workload.id
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${local.namespace}:${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
}

# --- Secrets ----------------------------------------------------------------
# A Key Vault per tenant: the team manages its own secrets, the workload
# identity can only read them, and no other tenant has access.

resource "azurerm_key_vault" "this" {
  count = var.tenant.keyVault ? 1 : 0

  name                       = local.key_vault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.entra_tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = local.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.node_subnet_id]
    ip_rules                   = var.tenant.keyVaultIpRules
  }
}

resource "azurerm_role_assignment" "kv_secrets_officer" {
  count = var.tenant.keyVault ? 1 : 0

  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.tenant.ownerGroupId
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  count = var.tenant.keyVault ? 1 : 0

  scope                = azurerm_key_vault.this[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}
