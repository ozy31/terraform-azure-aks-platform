variable "name" {
  description = "Name prefix for network resources, e.g. \"plat-prod-uks\"."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the network resources."
  type        = string
}

variable "address_space" {
  description = "VNet address space. Pods use an overlay CIDR, so only nodes, the API server and private endpoints consume VNet addresses."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.address_space, 0)) && tonumber(split("/", var.address_space)[1]) <= 20
    error_message = "address_space must be a valid CIDR of /20 or larger."
  }
}

variable "nat_public_ip_prefix_length" {
  description = "Size of the public IP prefix used for egress. /30 gives four static egress IPs that partners can allow-list."
  type        = number
  default     = 30
}

variable "zones" {
  description = "Availability zones for the NAT gateway and its IP prefix."
  type        = list(string)
  default     = ["1"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "private_dns_zones" {
  description = "Private DNS zones to create and link to the VNet, keyed by the service that uses them."
  type        = map(string)
  default = {
    key_vault = "privatelink.vaultcore.azure.net"
    acr       = "privatelink.azurecr.io"
  }
}
