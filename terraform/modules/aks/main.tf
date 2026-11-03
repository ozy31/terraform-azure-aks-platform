# Control plane and kubelet use user-assigned identities, so their role
# assignments exist before the cluster does and survive a cluster rebuild.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${var.name}-kubelet"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Needed for the API server subnet, NAT gateway egress and internal load balancers.
resource "azurerm_role_assignment" "control_plane_network" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "control_plane_kubelet_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = "rg-${var.name}-nodes"
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  # Entra ID only: no static admin kubeconfig, every human and pipeline
  # authenticates with Entra and is authorised by Azure RBAC.
  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  run_command_enabled               = false
  private_cluster_enabled           = var.private_cluster_enabled
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48
  cost_analysis_enabled             = var.sku_tier != "Free"

  azure_active_directory_role_based_access_control {
    tenant_id              = var.entra_tenant_id
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  api_server_access_profile {
    subnet_id                           = var.apiserver_subnet_id
    virtual_network_integration_enabled = true
    authorized_ip_ranges                = var.private_cluster_enabled ? null : var.authorized_ip_ranges
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  # Critical add-ons only (CoreDNS, Cilium, konnectivity, Flux, Gatekeeper,
  # istiod). Application pods land on nodes created by Node Auto-Provisioning.
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    node_count                   = var.system_pool.node_count
    zones                        = var.system_pool.zones
    vnet_subnet_id               = var.node_subnet_id
    only_critical_addons_enabled = true
    os_sku                       = "AzureLinux"
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 128
    max_pods                     = 110
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge                     = "33%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 5
    }
  }

  # Node Auto-Provisioning (Karpenter): picks VM sizes per pending pod set and
  # consolidates underused nodes. NodePools live in Git (gitops/infrastructure/configs).
  node_provisioning_profile {
    mode               = "Auto"
    default_node_pools = "None"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
    load_balancer_sku   = "standard"
    outbound_type       = "userAssignedNATGateway"
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  storage_profile {
    disk_driver_enabled         = true
    file_driver_enabled         = true
    blob_driver_enabled         = false
    snapshot_controller_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance.cluster_day
    start_time  = var.maintenance.start_time
    utc_offset  = "+00:00"
    duration    = var.maintenance.duration_hrs
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance.node_os_day
    start_time  = var.maintenance.start_time
    utc_offset  = "+00:00"
    duration    = var.maintenance.duration_hrs
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.control_plane_network,
    azurerm_role_assignment.control_plane_kubelet_operator,
  ]
}
