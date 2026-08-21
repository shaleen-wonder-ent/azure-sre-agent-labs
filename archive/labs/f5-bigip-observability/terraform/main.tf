resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                         = "${var.prefix}-law"
  location                     = azurerm_resource_group.this.location
  resource_group_name          = azurerm_resource_group.this.name
  sku                          = "PerGB2018"
  retention_in_days            = 30
  local_authentication_enabled = true
  internet_ingestion_enabled   = true
  internet_query_enabled       = true
  tags                         = var.tags
}
