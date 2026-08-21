data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "zava" {
  provider = azurerm.zava
  name     = var.zava_resource_group_name
}

data "azurerm_virtual_network" "zava" {
  provider            = azurerm.zava
  name                = var.zava_virtual_network_name
  resource_group_name = data.azurerm_resource_group.zava.name
}

data "azurerm_log_analytics_workspace" "zava" {
  provider            = azurerm.zava
  name                = var.zava_log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.zava.name
}

data "azurerm_application_insights" "zava" {
  provider            = azurerm.zava
  name                = var.zava_application_insights_name
  resource_group_name = data.azurerm_resource_group.zava.name
}

data "azurerm_application_gateway" "zava" {
  provider            = azurerm.zava
  name                = var.zava_application_gateway_name
  resource_group_name = data.azurerm_resource_group.zava.name
}

locals {
  zava_application_gateway_public_ip_id = one([
    for configuration in data.azurerm_application_gateway.zava.frontend_ip_configuration :
    configuration.public_ip_address_id
    if configuration.public_ip_address_id != null
  ])
}

data "azurerm_public_ip" "zava_application_gateway" {
  provider = azurerm.zava

  name                = element(split("/", local.zava_application_gateway_public_ip_id), 8)
  resource_group_name = element(split("/", local.zava_application_gateway_public_ip_id), 4)
}

data "azurerm_subscription" "primary" {
  subscription_id = var.subscription_id
}
