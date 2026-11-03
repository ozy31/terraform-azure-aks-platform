# Runs without Azure credentials: the provider is mocked.
mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
      client_id    = "33333333-3333-3333-3333-333333333333"
      principal_id = "44444444-4444-4444-4444-444444444444"
    }
  }

  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      vault_uri = "https://kv-test.vault.azure.net/"
    }
  }
}

variables {
  name_prefix         = "plat-prod"
  location            = "uksouth"
  resource_group_name = "rg-test"
  entra_tenant_id     = "00000000-0000-0000-0000-000000000000"
  cluster_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
  oidc_issuer_url     = "https://uksouth.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/11111111-1111-1111-1111-111111111111/"
  node_subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/nodes"

  tenant = {
    name            = "checkout"
    displayName     = "Checkout"
    ownerGroupId    = "2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10"
    costCenter      = "CC-1042"
    serviceAccounts = ["app", "worker"]
    # Chart-only keys are accepted and ignored.
    hostnames = ["checkout.platform.example.co.uk"]
  }
}

run "namespace_scoped_access" {
  command = apply

  assert {
    condition     = azurerm_role_assignment.namespace_writer.scope == "${var.cluster_id}/namespaces/checkout"
    error_message = "The team must get write access to its own namespace only."
  }

  assert {
    condition     = azurerm_role_assignment.namespace_writer.role_definition_name == "Azure Kubernetes Service RBAC Writer"
    error_message = "Teams get Writer, not Admin or Cluster Admin."
  }
}

run "one_federated_credential_per_service_account" {
  command = apply

  assert {
    condition = toset([for c in azurerm_federated_identity_credential.workload : c.subject]) == toset([
      "system:serviceaccount:checkout:app",
      "system:serviceaccount:checkout:worker",
    ])
    error_message = "Each declared service account needs exactly one federated credential."
  }
}

run "key_vault_name_fits_azure_limit" {
  command = apply

  variables {
    name_prefix = "plat-production-westeu"
    tenant = {
      name         = "customer-analytics"
      displayName  = "Customer Analytics"
      ownerGroupId = "2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10"
      costCenter   = "CC-3000"
    }
  }

  assert {
    condition     = length(azurerm_key_vault.this[0].name) <= 24
    error_message = "Key Vault names are limited to 24 characters."
  }
}

run "key_vault_optional" {
  command = apply

  variables {
    tenant = {
      name         = "batch"
      displayName  = "Batch"
      ownerGroupId = "2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10"
      costCenter   = "CC-3001"
      keyVault     = false
    }
  }

  assert {
    condition     = length(azurerm_key_vault.this) == 0 && output.key_vault_uri == ""
    error_message = "keyVault = false must not create a vault."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    tenant = {
      name         = "Checkout_Team"
      displayName  = "Checkout"
      ownerGroupId = "2f1c9a54-7d3e-4b8a-9c61-0e5d4a3b2c10"
      costCenter   = "CC-1042"
    }
  }

  expect_failures = [var.tenant]
}

run "rejects_owner_that_is_not_a_group_id" {
  command = plan

  variables {
    tenant = {
      name         = "checkout"
      displayName  = "Checkout"
      ownerGroupId = "checkout-team@example.co.uk"
      costCenter   = "CC-1042"
    }
  }

  expect_failures = [var.tenant]
}
