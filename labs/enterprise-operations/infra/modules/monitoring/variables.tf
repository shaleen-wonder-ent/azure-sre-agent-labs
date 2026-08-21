variable "name_prefix" {
  description = "Name prefix for monitoring resources."
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

variable "subscription_id" {
  description = "Primary subscription ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Existing Zava Log Analytics workspace ID."
  type        = string
}

variable "application_insights_id" {
  description = "Existing Zava Application Insights component ID."
  type        = string
}

variable "source_virtual_machine_id" {
  description = "Diagnostics VM used as the Connection Monitor source."
  type        = string
}

variable "public_target_address" {
  description = "Public Application Gateway IP or FQDN."
  type        = string
}

variable "private_target_address" {
  description = "Optional private Zava IP or FQDN."
  type        = string
  default     = null
  nullable    = true
}

variable "network_watcher_name" {
  description = "Existing Network Watcher name."
  type        = string
}

variable "network_watcher_resource_group_name" {
  description = "Existing Network Watcher resource group name."
  type        = string
}

variable "create_network_watcher" {
  description = "Create the regional watcher instead of reading an existing one."
  type        = bool
}

variable "notification_email_addresses" {
  description = "Map of receiver names to email addresses."
  type        = map(string)
  sensitive   = true
}

variable "existing_action_group_id" {
  description = "Existing action group resource ID, or null to create one."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_entra_diagnostics" {
  description = "Export tenant audit and sign-in logs."
  type        = bool
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
