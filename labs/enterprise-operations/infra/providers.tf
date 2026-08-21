terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "zava"

  features {}

  subscription_id = var.zava_subscription_id != null ? var.zava_subscription_id : var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "secondary"

  features {}

  subscription_id = var.secondary_subscription_id != null ? var.secondary_subscription_id : var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
