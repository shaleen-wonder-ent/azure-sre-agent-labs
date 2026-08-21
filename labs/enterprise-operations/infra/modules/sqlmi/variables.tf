variable "name_prefix" {
  description = "Name prefix for SQL MI networking resources."
  type        = string
}

variable "managed_instance_name" {
  description = "Globally unique SQL Managed Instance name."
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

variable "virtual_network_name" {
  description = "Hub virtual network name."
  type        = string
}

variable "subnet_prefix" {
  description = "Dedicated SQL MI subnet prefix."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Existing Zava Log Analytics workspace ID."
  type        = string
}

variable "sku_name" {
  description = "SQL MI SKU name."
  type        = string
}

variable "vcores" {
  description = "SQL MI vCore count."
  type        = number
}

variable "storage_size_gb" {
  description = "SQL MI storage in GB, in multiples of 32."
  type        = number
}

variable "license_type" {
  description = "SQL MI license type."
  type        = string
}

variable "administrator_login" {
  description = "SQL MI administrator login."
  type        = string
}

variable "administrator_password" {
  description = "SQL MI administrator password."
  type        = string
  sensitive   = true
  nullable    = true
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
