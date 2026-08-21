variable "subscription_id" {
  description = "Primary Azure subscription ID. Set this explicitly or through ARM_SUBSCRIPTION_ID."
  type        = string
  default     = null
  nullable    = true
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID. Null uses the authenticated Azure CLI or workload identity tenant."
  type        = string
  default     = null
  nullable    = true
}

variable "zava_subscription_id" {
  description = "Subscription containing the existing Zava Learning deployment. Null uses subscription_id."
  type        = string
  default     = null
  nullable    = true
}

variable "location" {
  description = "Azure region for the enterprise operations overlay."
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Short environment identifier used in names and tags."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,12}$", var.environment))
    error_message = "environment must contain 2-12 lowercase letters, numbers, or hyphens."
  }
}

variable "name_prefix" {
  description = "CAF-compatible prefix for created resources."
  type        = string
  default     = "sre-eops"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.name_prefix))
    error_message = "name_prefix must start with a lowercase letter and contain 3-21 lowercase letters, numbers, or hyphens."
  }
}

variable "tags" {
  description = "Additional tags merged with the required lab tags."
  type        = map(string)
  default     = {}
}

variable "zava_resource_group_name" {
  description = "Existing Zava Learning resource group name."
  type        = string
}

variable "zava_virtual_network_name" {
  description = "Existing Zava spoke virtual network name."
  type        = string
}

variable "zava_log_analytics_workspace_name" {
  description = "Existing Zava Log Analytics workspace name."
  type        = string
}

variable "zava_application_insights_name" {
  description = "Existing workspace-based Zava Application Insights component name."
  type        = string
}

variable "zava_application_gateway_name" {
  description = "Existing public Zava Application Gateway name."
  type        = string
}

variable "zava_private_probe_address" {
  description = "Optional private IP or FQDN in the Zava spoke for Connection Monitor. Null creates only the public application test."
  type        = string
  default     = null
  nullable    = true
}

variable "hub_address_space" {
  description = "Non-overlapping /16 address space for the SRE hub."
  type        = string
  default     = "10.90.0.0/16"

  validation {
    condition     = can(cidrhost(var.hub_address_space, 0)) && tonumber(split("/", var.hub_address_space)[1]) <= 24
    error_message = "hub_address_space must be a valid IPv4 CIDR with enough room for /24 subnets."
  }
}

variable "diagnostics_subnet_prefix" {
  description = "Address prefix for the private diagnostics subnet."
  type        = string
  default     = "10.90.1.0/24"
}

variable "enable_network_fault_route" {
  description = "Create a 0.0.0.0/0 None route to intentionally break diagnostics-subnet egress. Use only during the networking fault exercise."
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Administrator username for the diagnostics Linux VM."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for the private diagnostics VM. No private key is stored by Terraform."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be a valid OpenSSH public key."
  }
}

variable "diagnostics_vm_size" {
  description = "VM size for the private diagnostics endpoint. Standard_B2s was validated in centralindia."
  type        = string
  default     = "Standard_B2s"
}

variable "network_watcher_name" {
  description = "Existing regional Network Watcher name when create_network_watcher is false."
  type        = string
  default     = "NetworkWatcher_centralindia"
}

variable "network_watcher_resource_group_name" {
  description = "Resource group containing the existing regional Network Watcher."
  type        = string
  default     = "NetworkWatcherRG"
}

variable "create_network_watcher" {
  description = "Create a Network Watcher in the overlay resource group. Enable only when the target subscription has no watcher in this region."
  type        = bool
  default     = false
}

variable "notification_email_addresses" {
  description = "Map of receiver name to email address. Empty creates an action group without receivers."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "existing_action_group_id" {
  description = "Optional existing action group ID. When set, alert actions use it instead of the created group."
  type        = string
  default     = null
  nullable    = true
}

variable "sre_agent_name" {
  description = "Optional explicit SRE Agent name. Null uses a suffix-stabilized generated name."
  type        = string
  default     = null
  nullable    = true
}

variable "sre_agent_model_provider" {
  description = "Model provider accepted by the SRE Agent preview API."
  type        = string
  default     = "Anthropic"

  validation {
    condition     = contains(["Anthropic", "MicrosoftFoundry"], var.sre_agent_model_provider)
    error_message = "sre_agent_model_provider must be Anthropic or MicrosoftFoundry."
  }
}

variable "sre_agent_model_name" {
  description = "SRE Agent model name. Automatic lets the platform select the model."
  type        = string
  default     = "Automatic"
}

variable "sre_agent_admin_principal_id" {
  description = "Object ID receiving Azure SRE Agent Administrator on the new agent. Null uses the deploying principal."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_cost_management_reader" {
  description = "Grant Cost Management Reader to the SRE Agent UAMI at primary subscription scope."
  type        = bool
  default     = false
}

variable "enable_security_reader" {
  description = "Grant Security Reader to the SRE Agent UAMI at primary subscription scope."
  type        = bool
  default     = false
}

variable "remediation_role_definition_ids" {
  description = "Explicit role definition resource IDs for approved write scenarios. Empty keeps the agent read-only."
  type        = set(string)
  default     = []
}

variable "enable_entra_diagnostics" {
  description = "Export Entra audit and sign-in logs. Requires tenant-root authorization and suitable licensing."
  type        = bool
  default     = false
}

variable "enable_sql_managed_instance" {
  description = "Deploy the expensive, slow-provisioning SQL Managed Instance scenario."
  type        = bool
  default     = false
}

variable "sqlmi_subnet_prefix" {
  description = "Dedicated /24 subnet for optional SQL Managed Instance."
  type        = string
  default     = "10.90.2.0/24"
}

variable "sqlmi_name" {
  description = "Optional globally unique SQL MI name. Null generates a lowercase suffix-stabilized name."
  type        = string
  default     = null
  nullable    = true
}

variable "sqlmi_sku_name" {
  description = "SQL MI SKU name."
  type        = string
  default     = "GP_Gen5"
}

variable "sqlmi_vcores" {
  description = "SQL MI vCore count; verify regional quota before enabling."
  type        = number
  default     = 4
}

variable "sqlmi_storage_size_gb" {
  description = "SQL MI storage size in GB."
  type        = number
  default     = 32
}

variable "sqlmi_license_type" {
  description = "LicenseIncluded, or BasePrice only when Azure Hybrid Benefit eligibility is confirmed."
  type        = string
  default     = "LicenseIncluded"

  validation {
    condition     = contains(["LicenseIncluded", "BasePrice"], var.sqlmi_license_type)
    error_message = "sqlmi_license_type must be LicenseIncluded or BasePrice."
  }
}

variable "sqlmi_administrator_login" {
  description = "SQL MI administrator login used only when the optional module is enabled."
  type        = string
  default     = "sqlmiadmin"
}

variable "sqlmi_administrator_password" {
  description = "SQL MI administrator password. Supply via TF_VAR_sqlmi_administrator_password or a secure variable store."
  type        = string
  default     = null
  nullable    = true
  sensitive   = true
}

variable "enable_secondary_subscription" {
  description = "Create the optional second-subscription test scope and read-only agent access."
  type        = bool
  default     = false
}

variable "secondary_subscription_id" {
  description = "Existing second subscription ID. Required when enable_secondary_subscription is true."
  type        = string
  default     = null
  nullable    = true
}
