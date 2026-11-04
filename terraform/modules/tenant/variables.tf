variable "tenant" {
  description = "Tenant definition, decoded from gitops/tenants/<name>/tenant.yaml. Keys used only by the Helm chart (quota, hostnames, ...) are ignored here."
  type = object({
    name            = string
    displayName     = string
    ownerGroupId    = string
    costCenter      = string
    serviceAccounts = optional(list(string), ["app"])
    keyVault        = optional(bool, true)
    keyVaultIpRules = optional(list(string), [])
  })

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.tenant.name))
    error_message = "Tenant name must be 3-20 characters of lowercase letters, digits and hyphens (it becomes part of the Key Vault name)."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.tenant.ownerGroupId))
    error_message = "ownerGroupId must be an Entra group object ID."
  }

  validation {
    condition     = alltrue([for sa in var.tenant.serviceAccounts : can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", sa))])
    error_message = "Service account names must be valid Kubernetes names."
  }
}

variable "name_prefix" {
  description = "Short prefix for Azure resource names, e.g. \"plat-prod\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for tenant identities and Key Vaults."
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "cluster_id" {
  description = "AKS cluster resource ID."
  type        = string
}

variable "oidc_issuer_url" {
  description = "AKS OIDC issuer URL."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the tenant Key Vault private endpoint."
  type        = string
}

variable "key_vault_private_dns_zone_id" {
  description = "privatelink.vaultcore.azure.net zone linked to the cluster VNet."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace that receives the tenant Key Vault audit logs."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
