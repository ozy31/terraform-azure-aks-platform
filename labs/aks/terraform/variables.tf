variable "subscription_id" {
  description = "Lab subscription id"
  type        = string
}

variable "location" {
  description = "Region; must match rg-lab-core"
  type        = string
  default     = "swedencentral"
}

variable "my_ip" {
  description = "Only this IP may reach the API server (authorized IP ranges)"
  type        = string
}

variable "node_size" {
  description = "A 4 vCPU regional quota fits two 2 vCPU nodes: one system, one user"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "storage_account_name" {
  description = "The storage account created by labs/storage (read by workload-identity.tf)"
  type        = string
}
