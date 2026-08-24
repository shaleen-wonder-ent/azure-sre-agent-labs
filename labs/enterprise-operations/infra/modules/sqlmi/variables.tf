variable "name_prefix" {
  description = "Name prefix for SQL MI networking resources."
  type        = string
}

variable "managed_instance_name" {
  description = "Globally unique SQL Managed Instance name."
  type        = string
}

variable "database_name" {
  description = "Dedicated database used by the SQL MI performance demonstration."
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

variable "entra_administrator_login" {
  description = "Microsoft Entra administrator login name."
  type        = string
}

variable "entra_administrator_id" {
  description = "Microsoft Entra administrator object ID."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
