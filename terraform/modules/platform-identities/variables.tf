variable "name" {
  description = "Name prefix, e.g. \"plat-prod-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the identities."
  type        = string
}

variable "oidc_issuer_url" {
  description = "AKS OIDC issuer URL."
  type        = string
}

variable "dns_zone_id" {
  description = "Public DNS zone managed by external-dns and used by cert-manager for DNS-01."
  type        = string
}

variable "platform_key_vault_id" {
  description = "Platform Key Vault read by External Secrets for cluster-wide secrets."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
