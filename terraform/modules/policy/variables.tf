variable "subscription_id" {
  description = "Subscription resource ID, e.g. \"/subscriptions/<guid>\"."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-f-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a resource ID: /subscriptions/<guid>."
  }
}

variable "location" {
  description = "Region for the identities of modify policies."
  type        = string
}

variable "allowed_locations" {
  description = "Regions where resources and resource groups may be created."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

variable "required_tags" {
  description = "Tags every resource group must have; resources inherit them when missing."
  type        = list(string)
  default     = ["cost-center"]
}

variable "enforce" {
  description = "false runs the assignments in audit-only mode (DoNotEnforce): roll out new guardrails this way first."
  type        = bool
  default     = true
}
