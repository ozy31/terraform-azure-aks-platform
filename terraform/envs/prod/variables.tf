variable "subscription_id" {
  description = "Subscription that hosts the platform."
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "uksouth"
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
  default     = "prod"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version. Bump one minor at a time, dev before prod (docs/runbooks/upgrades.md)."
  type        = string
}

variable "platform_admin_group_ids" {
  description = "Entra groups with cluster-admin (platform team, break-glass)."
  type        = list(string)
}

variable "authorized_ip_ranges" {
  description = "CIDRs allowed to reach the API server."
  type        = list(string)
}

variable "acr_name" {
  description = "Globally unique container registry name (alphanumeric)."
  type        = string
}

variable "dns_zone_name" {
  description = "Public DNS zone for platform and tenant hostnames."
  type        = string
}

variable "acme_email" {
  description = "Contact address for Let's Encrypt."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository Flux reconciles from."
  type        = string
  default     = "https://github.com/ozy31/terraform-azure-aks-platform"
}

variable "gitops_branch" {
  description = "Branch Flux follows."
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
