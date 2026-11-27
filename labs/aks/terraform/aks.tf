resource "azurerm_kubernetes_cluster" "lab" {
  name                = "aks-lab"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "aks-lab"
  sku_tier            = "Free" # production: Standard, for the uptime SLA

  # VMSS, disks and the load balancer go here; AKS owns it, don't edit by hand.
  node_resource_group = "MC_rg-lab-aks_aks-lab"

  # Identity: no static admin kubeconfig, everyone signs in with Entra ID,
  # and Kubernetes permissions are Azure RBAC role assignments.
  local_account_disabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.me.tenant_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Workload identity: pods reach Azure without secrets.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Production would be a private cluster. The lab keeps a public endpoint,
  # open to one IP only.
  api_server_access_profile {
    authorized_ip_ranges = ["${var.my_ip}/32"]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay" # pods don't consume subnet IPs
    network_data_plane  = "cilium"  # eBPF dataplane, no kube-proxy
    network_policy      = "cilium"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    outbound_type       = "loadBalancer" # production: userDefinedRouting to the hub firewall
  }

  # System pool: CoreDNS, metrics-server, konnectivity. Tainted CriticalAddonsOnly.
  default_node_pool {
    name                         = "system"
    vm_size                      = var.node_size
    node_count                   = 1
    vnet_subnet_id               = data.azurerm_subnet.aks.id
    only_critical_addons_enabled = true
    os_sku                       = "AzureLinux"
    # Azure's default, written out: without it every plan shows drift.
    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Istio add-on, managed by Microsoft. Upgrades add a new revision next to the old one (canary).
  service_mesh_profile {
    mode                             = "Istio"
    revisions                        = ["asm-1-30"]
    internal_ingress_gateway_enabled = false
    external_ingress_gateway_enabled = false
  }

  # Patch upgrades and weekly node images, only inside the maintenance window.
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    duration    = 4
    utc_offset  = "+03:00"
  }

  tags = azurerm_resource_group.aks.tags

  depends_on = [azurerm_role_assignment.aks_subnet]
}

# User pool: application pods land here.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.lab.id
  vm_size               = var.node_size
  node_count            = 1
  vnet_subnet_id        = data.azurerm_subnet.aks.id
  os_sku                = "AzureLinux"
  mode                  = "User"
  upgrade_settings {
    max_surge = "10%"
  }
}
