variable "subscription_id" {
  description = "Azure subscription in which to create the disposable lab."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "location" {
  description = "Azure region for all lab resources."
  type        = string
  default     = "centralindia"
}

variable "prefix" {
  description = "Lowercase prefix used for resource names."
  type        = string
  default     = "f5obs"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,14}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 3-16 lowercase alphanumeric or hyphen characters and must start and end with alphanumeric."
  }
}

variable "management_cidr" {
  description = "Trusted public IPv4 CIDR allowed to access BIG-IP SSH and TCP 8443. Never use 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.management_cidr, 0)) && !strcontains(var.management_cidr, ":") && var.management_cidr != "0.0.0.0/0"
    error_message = "management_cidr must be a restricted IPv4 CIDR and cannot be 0.0.0.0/0."
  }
}

variable "admin_username" {
  description = "SSH administrator name for BIG-IP and backend VMs."
  type        = string
  default     = "azureuser"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,30}$", var.admin_username))
    error_message = "admin_username must be a valid Linux user name of at most 31 characters."
  }
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key used for VM access. Private keys must never be supplied to Terraform."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-(rsa|ed25519)|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+(?: .*)?$", trimspace(var.admin_ssh_public_key)))
    error_message = "admin_ssh_public_key must be a valid OpenSSH public key."
  }
}

variable "bigip_vm_size" {
  description = "Azure VM size for BIG-IP BEST with AWAF and iControl LX extensions."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "backend_vm_size" {
  description = "Azure VM size for each disposable backend."
  type        = string
  default     = "Standard_B1s"
}

variable "bigip_image_version" {
  description = "Pinned BIG-IP Marketplace image version. Revalidate availability before deployment."
  type        = string
  default     = "21.0.001000"
}

variable "tags" {
  description = "Tags applied to lab resources."
  type        = map(string)
  default = {
    environment = "lab"
    managed_by  = "terraform"
    workload    = "f5-bigip-observability"
  }
}
