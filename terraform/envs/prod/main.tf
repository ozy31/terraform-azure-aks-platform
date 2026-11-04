locals {
  name        = "plat-${var.environment}-${local.region_short[var.location]}"
  name_prefix = "plat-${var.environment}"
  region_short = {
    uksouth = "uks"
    ukwest  = "ukw"
  }

  tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform"
    repository  = "terraform-azure-aks-platform"
  })

  # One directory per tenant. The same tenant.yaml drives the Azure side here
  # and the cluster side through the tenant Helm chart.
  tenants_dir = "${path.module}/../../../gitops/tenants"
  tenants = {
    for f in fileset(local.tenants_dir, "*/tenant.yaml") :
    dirname(f) => merge(yamldecode(file("${local.tenants_dir}/${f}")), { name = dirname(f) })
  }
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "tenants" {
  name     = "rg-${local.name}-tenants"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Nodes pull through a private endpoint. The public endpoint stays for image
# pushes from the authorized ranges (build agents, admins) and is closed to
# everything else.
resource "azurerm_container_registry" "this" {
  name                       = var.acr_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  sku                        = "Premium"
  admin_enabled              = false
  zone_redundancy_enabled    = true
  retention_policy_in_days   = 30
  network_rule_bypass_option = "AzureServices"
  tags                       = local.tags

  network_rule_set = [{
    default_action = "Deny"
    ip_rule        = [for r in var.authorized_ip_ranges : { action = "Allow", ip_range = r }]
  }]
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${local.name}-acr"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = module.network.private_endpoint_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "acr"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["acr"]]
  }
}

resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

# Cluster-wide secrets (e.g. Grafana admin, alerting webhooks). Tenant secrets
# live in per-tenant vaults created by the tenant module.
resource "azurerm_key_vault" "platform" {
  name                       = substr("kv-${local.name_prefix}-platform", 0, 24)
  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  tenant_id                  = var.entra_tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = local.tags

  # The cluster reaches the vault through the private endpoint below; the
  # firewall only lets admins in from the authorized ranges.
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.authorized_ip_ranges
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "platform_kv" {
  name                = "pe-${local.name}-kv-platform"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = module.network.private_endpoint_subnet_id
  tags                = local.tags

  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.platform.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [module.network.private_dns_zone_ids["key_vault"]]
  }
}

resource "azurerm_role_assignment" "platform_kv_admins" {
  for_each = toset(var.platform_admin_group_ids)

  scope                = azurerm_key_vault.platform.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.key
  principal_type       = "Group"
}

module "network" {
  source = "../../modules/network"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

module "aks" {
  source = "../../modules/aks"

  name                       = "aks-${local.name}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  kubernetes_version         = var.kubernetes_version
  vnet_id                    = module.network.vnet_id
  node_subnet_id             = module.network.node_subnet_id
  apiserver_subnet_id        = module.network.apiserver_subnet_id
  authorized_ip_ranges       = var.authorized_ip_ranges
  entra_tenant_id            = var.entra_tenant_id
  admin_group_object_ids     = var.platform_admin_group_ids
  acr_id                     = azurerm_container_registry.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags

  # The NAT gateway must be attached to the node subnet before the cluster
  # is created with outbound_type = userAssignedNATGateway.
  depends_on = [module.network]
}

module "platform_identities" {
  source = "../../modules/platform-identities"

  name                  = local.name
  location              = var.location
  resource_group_name   = azurerm_resource_group.platform.name
  oidc_issuer_url       = module.aks.oidc_issuer_url
  dns_zone_id           = azurerm_dns_zone.this.id
  platform_key_vault_id = azurerm_key_vault.platform.id
  tags                  = local.tags
}

module "tenant" {
  source   = "../../modules/tenant"
  for_each = local.tenants

  tenant              = each.value
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.tenants.name
  entra_tenant_id     = var.entra_tenant_id
  cluster_id          = module.aks.id
  oidc_issuer_url     = module.aks.oidc_issuer_url
  tags                = local.tags

  private_endpoint_subnet_id    = module.network.private_endpoint_subnet_id
  key_vault_private_dns_zone_id = module.network.private_dns_zone_ids["key_vault"]
  log_analytics_workspace_id    = azurerm_log_analytics_workspace.this.id
}
