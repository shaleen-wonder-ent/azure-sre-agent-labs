variable "name_prefix" {
  description = "Name prefix for networking resources."
  type        = string
}

variable "resource_group_name" {
  description = "Overlay resource group name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "hub_address_space" {
  description = "Hub VNet address space."
  type        = string
}

variable "diagnostics_subnet_prefix" {
  description = "Private diagnostics subnet prefix."
  type        = string
}

variable "zava_virtual_network_id" {
  description = "Existing Zava spoke VNet resource ID."
  type        = string
}

variable "enable_fault_route" {
  description = "Create a blackhole default route for the fault exercise."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
