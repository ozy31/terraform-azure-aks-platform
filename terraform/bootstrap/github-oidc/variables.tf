variable "subscription_id" {
  description = "Subscription the pipeline deploys into."
  type        = string
}

variable "entra_tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "location" {
  description = "Region for the state storage account."
  type        = string
  default     = "uksouth"
}

variable "github_repository" {
  description = "owner/name of the repository whose workflows get access."
  type        = string
  default     = "ozy31/terraform-azure-aks-platform"
}

variable "state_storage_account_name" {
  description = "Globally unique name for the Terraform state storage account."
  type        = string
}

variable "apply_environments" {
  description = "GitHub environments allowed to apply (each should require reviewers)."
  type        = list(string)
  default     = ["prod"]
}
