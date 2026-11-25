# Security and operations baseline of the AKS module. The provider is mocked,
# so this runs in CI without Azure credentials.
mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-test"
      client_id    = "33333333-3333-3333-3333-333333333333"
      principal_id = "44444444-4444-4444-4444-444444444444"
    }
  }
}

variables {
  name                       = "aks-plat-test-uks"
  location                   = "uksouth"
  resource_group_name        = "rg-test"
  kubernetes_version         = "1.34"
  node_subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/nodes"
  apiserver_subnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/apiserver"
  vnet_id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet"
  entra_tenant_id            = "00000000-0000-0000-0000-000000000000"
  admin_group_object_ids     = ["55555555-5555-5555-5555-555555555555"]
  acr_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ContainerRegistry/registries/acrtest"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
}

run "access_is_entra_only" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.local_account_disabled
    error_message = "Local accounts must stay disabled: a static kubeconfig bypasses Entra ID and the audit trail."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled
    error_message = "Kubernetes authorisation must go through Azure RBAC."
  }

  assert {
    condition     = !azurerm_kubernetes_cluster.this.run_command_enabled
    error_message = "Run command lets anyone with cluster read access execute pods through the ARM API."
  }
}

run "workloads_use_federated_identity" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "Workload identity needs both the OIDC issuer and the webhook."
  }
}

run "event_driven_and_vertical_autoscaling" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.workload_autoscaler_profile[0].keda_enabled
    error_message = "KEDA scales inference and queue workers; CPU alone does not reflect their load."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.workload_autoscaler_profile[0].vertical_pod_autoscaler_enabled
    error_message = "VPA recommendations keep requests honest, which Node Auto-Provisioning sizes VMs from."
  }
}

run "control_plane_roles_exist_before_the_cluster" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.control_plane_network.principal_type == "ServicePrincipal"
    error_message = "Role assignments for managed identities must set principal_type to avoid replication races."
  }

  assert {
    condition     = azurerm_role_assignment.kubelet_acr_pull.role_definition_name == "AcrPull"
    error_message = "The kubelet identity gets pull access only."
  }
}

run "upgrades_drain_and_soak" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].upgrade_settings[0].node_soak_duration_in_minutes > 0
    error_message = "Each upgrade batch must soak before the next one drains."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.automatic_upgrade_channel == "patch"
    error_message = "Minor versions are a reviewed change; only patches upgrade automatically."
  }
}

run "defender_reports_to_the_platform_workspace" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.microsoft_defender[0].log_analytics_workspace_id == var.log_analytics_workspace_id
    error_message = "Defender findings must land in the same workspace as the audit logs."
  }
}

run "defender_can_be_turned_off" {
  command = plan

  variables {
    defender_enabled = false
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this.microsoft_defender) == 0
    error_message = "defender_enabled = false must remove the sensor."
  }
}

run "minor_version_only" {
  command = plan

  variables {
    kubernetes_version = "1.34.2"
  }

  expect_failures = [var.kubernetes_version]
}
