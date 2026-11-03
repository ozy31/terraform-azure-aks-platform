variable "name" {
  description = "Cluster name, e.g. \"aks-plat-prod-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster and its identities."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. \"1.34\"). Patch versions are applied by the auto-upgrade channel inside the maintenance window."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Use a minor version such as \"1.34\"; patches are managed by automatic_upgrade_channel = \"patch\"."
  }
}

variable "sku_tier" {
  description = "Standard gives the financially backed API server SLA and is required for cost analysis."
  type        = string
  default     = "Standard"
}

variable "node_subnet_id" {
  description = "Subnet for nodes."
  type        = string
}

variable "apiserver_subnet_id" {
  description = "Delegated subnet for API Server VNet Integration."
  type        = string
}

variable "vnet_id" {
  description = "VNet ID. The control plane identity needs Network Contributor on it."
  type        = string
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to reach the public API server endpoint (office, VPN, CI runners). Empty list with private_cluster_enabled = true for a private API."
  type        = list(string)
  default     = []
}

variable "private_cluster_enabled" {
  description = "Expose the API server only inside the VNet. GitOps (Flux) pulls from Git and needs no inbound API access."
  type        = bool
  default     = false
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID for Kubernetes authentication."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra groups that get cluster-admin through Azure RBAC (the platform team). Break-glass only; day-to-day access is namespace-scoped."
  type        = list(string)

  validation {
    condition     = length(var.admin_group_object_ids) > 0
    error_message = "At least one admin group is required because local accounts are disabled."
  }
}

variable "system_pool" {
  description = "System node pool. It only runs critical add-ons; application capacity comes from Node Auto-Provisioning."
  type = object({
    vm_size    = optional(string, "Standard_D4ds_v5")
    node_count = optional(number, 3)
    zones      = optional(list(string), ["1", "2", "3"])
  })
  default = {}
}

variable "pod_cidr" {
  description = "Overlay pod CIDR. Not routable in the VNet, so it can be reused across clusters."
  type        = string
  default     = "100.64.0.0/16"
}

variable "service_cidr" {
  description = "Service CIDR."
  type        = string
  default     = "172.16.0.0/16"
}

variable "acr_id" {
  description = "Container registry the kubelet identity can pull from."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace for Container Insights logs."
  type        = string
}

variable "maintenance" {
  description = "Maintenance windows (UTC). Cluster patches and node images roll on different days so a bad change has one cause."
  type = object({
    cluster_day  = optional(string, "Sunday")
    node_os_day  = optional(string, "Saturday")
    start_time   = optional(string, "02:00")
    duration_hrs = optional(number, 4)
  })
  default = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
