# Wiring tests for the prod root module. The provider is mocked, so this runs
# in CI without Azure credentials; terraform.tfvars supplies the inputs.
mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.ContainerService/managedClusters/aks-plat-prod-uks"
      oidc_issuer_url = "https://uksouth.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-mock"
      client_id    = "33333333-3333-3333-3333-333333333333"
      principal_id = "44444444-4444-4444-4444-444444444444"
    }
  }

  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.KeyVault/vaults/kv-mock"
      vault_uri = "https://kv-mock.vault.azure.net/"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/virtualNetworks/vnet-plat-prod-uks/subnets/mock"
    }
  }

  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/virtualNetworks/vnet-plat-prod-uks"
    }
  }

  mock_resource "azurerm_container_registry" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.ContainerRegistry/registries/acrplatproduks"
      login_server = "acrplatproduks.azurecr.io"
    }
  }

  mock_resource "azurerm_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/dnsZones/platform.example.co.uk"
    }
  }

  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.OperationalInsights/workspaces/log-plat-prod-uks"
    }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/natGateways/ng-plat-prod-uks"
    }
  }

  mock_resource "azurerm_public_ip_prefix" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/publicIPPrefixes/ippre-plat-prod-uks-egress"
    }
  }

  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-prod-uks/providers/Microsoft.Network/networkSecurityGroups/nsg-plat-prod-uks-aks-nodes"
    }
  }
}

run "every_tenant_directory_is_onboarded" {
  command = apply

  assert {
    condition = toset(keys(module.tenant)) == toset([
      for f in fileset("${path.module}/../../../gitops/tenants", "*/tenant.yaml") : dirname(f)
    ])
    error_message = "Each gitops/tenants/<name>/tenant.yaml must produce one tenant module instance."
  }

  assert {
    condition     = output.tenants["checkout"].namespace == "checkout"
    error_message = "The namespace is the tenant directory name."
  }
}

run "flux_gets_every_value_the_manifests_use" {
  command = apply

  assert {
    condition = alltrue([for k in [
      "ACR_LOGIN_SERVER",
      "CERT_MANAGER_CLIENT_ID",
      "EXTERNAL_DNS_CLIENT_ID",
      "EXTERNAL_SECRETS_CLIENT_ID",
      "PLATFORM_KEY_VAULT_URI",
      "TENANT_CHECKOUT_CLIENT_ID",
      "TENANT_CHECKOUT_KEY_VAULT_URI",
      "TENANT_LOYALTY_CLIENT_ID",
      "TENANT_LOYALTY_KEY_VAULT_URI",
    ] : contains(output.flux_substitution_keys, k)])
    error_message = "A variable referenced in gitops/ is missing from the Flux substitutions."
  }
}

run "kustomizations_are_ordered" {
  command = apply

  assert {
    condition = one([
      for k in azurerm_kubernetes_flux_configuration.platform.kustomizations : k.depends_on if k.name == "tenants"
    ]) == tolist(["infra-configs", "policies"])
    error_message = "Tenants must wait for the platform configs and the policy constraints."
  }
}
