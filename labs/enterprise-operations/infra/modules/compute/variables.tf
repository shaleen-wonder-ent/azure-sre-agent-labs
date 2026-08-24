variable "name_prefix" {
  description = "Name prefix for compute resources."
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

variable "data_collection_rule_location" {
  description = "Region of the destination Log Analytics workspace."
  type        = string
}

variable "user_assigned_identity_ids" {
  description = "Optional user-assigned identities attached to the diagnostics VM."
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "Private diagnostics subnet ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Existing Zava Log Analytics workspace ID."
  type        = string
}

variable "vm_size" {
  description = "Diagnostics VM size."
  type        = string
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "Linux administrator SSH public key."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
