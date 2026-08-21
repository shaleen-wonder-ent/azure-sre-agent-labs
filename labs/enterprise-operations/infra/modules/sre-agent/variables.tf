variable "name_prefix" {
  description = "Name prefix for agent resources."
  type        = string
}

variable "agent_name" {
  description = "Azure SRE Agent resource name."
  type        = string
}

variable "resource_group_id" {
  description = "Overlay resource group ID."
  type        = string
}

variable "resource_group_name" {
  description = "Overlay resource group name."
  type        = string
}

variable "zava_resource_group_id" {
  description = "Existing Zava resource group ID."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "primary_subscription_id" {
  description = "Primary subscription resource ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Existing Zava Log Analytics workspace ID."
  type        = string
}

variable "application_insights_id" {
  description = "Existing Zava Application Insights resource ID."
  type        = string
}

variable "application_insights_app_id" {
  description = "Application Insights application ID."
  type        = string
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string used by SRE Agent logging."
  type        = string
  sensitive   = true
}

variable "model_provider" {
  description = "SRE Agent model provider."
  type        = string
}

variable "model_name" {
  description = "SRE Agent model name."
  type        = string
}

variable "admin_principal_id" {
  description = "Principal receiving SRE Agent Administrator."
  type        = string
}

variable "enable_cost_management_reader" {
  description = "Grant Cost Management Reader at primary subscription scope."
  type        = bool
}

variable "enable_security_reader" {
  description = "Grant Security Reader at primary subscription scope."
  type        = bool
}

variable "remediation_role_definition_ids" {
  description = "Reviewed write-capable role definition IDs assigned at Zava RG scope."
  type        = set(string)
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
}
