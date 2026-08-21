variable "name_prefix" {
  description = "Name prefix for secondary-subscription resources."
  type        = string
}

variable "location" {
  description = "Azure region for the test resource group."
  type        = string
}

variable "secondary_subscription_id" {
  description = "Existing secondary subscription ID."
  type        = string
}

variable "agent_principal_id" {
  description = "Primary SRE Agent UAMI principal ID."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Primary-subscription Log Analytics workspace ID."
  type        = string
}

variable "tags" {
  description = "Tags applied to the test resource group."
  type        = map(string)
}
