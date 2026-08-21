resource "azurerm_network_security_group" "sqlmi" {
  name                = "nsg-${var.name_prefix}-sqlmi"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_route_table" "sqlmi" {
  name                          = "rt-${var.name_prefix}-sqlmi"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_subnet" "sqlmi" {
  name                            = "snet-${var.name_prefix}-sqlmi"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = var.virtual_network_name
  address_prefixes                = [var.subnet_prefix]
  default_outbound_access_enabled = false

  delegation {
    name = "managed-instance"

    service_delegation {
      name = "Microsoft.Sql/managedInstances"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
        "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
        "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "sqlmi" {
  subnet_id                 = azurerm_subnet.sqlmi.id
  network_security_group_id = azurerm_network_security_group.sqlmi.id
}

resource "azurerm_subnet_route_table_association" "sqlmi" {
  subnet_id      = azurerm_subnet.sqlmi.id
  route_table_id = azurerm_route_table.sqlmi.id
}

resource "azurerm_mssql_managed_instance" "this" {
  name                         = var.managed_instance_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  license_type                 = var.license_type
  sku_name                     = var.sku_name
  storage_size_in_gb           = var.storage_size_gb
  subnet_id                    = azurerm_subnet.sqlmi.id
  vcores                       = var.vcores
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_password
  minimum_tls_version          = "1.2"
  public_data_endpoint_enabled = false
  proxy_override               = "Redirect"
  storage_account_type         = "GRS"
  timezone_id                  = "UTC"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    precondition {
      condition     = var.administrator_password != null && length(var.administrator_password) >= 16
      error_message = "administrator_password must be supplied securely and contain at least 16 characters when SQL MI is enabled."
    }
    precondition {
      condition     = var.storage_size_gb % 32 == 0
      error_message = "storage_size_gb must be a multiple of 32."
    }
  }

  timeouts {
    create = "24h"
    update = "24h"
    delete = "24h"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.sqlmi,
    azurerm_subnet_route_table_association.sqlmi,
  ]
}

data "azurerm_monitor_diagnostic_categories" "sqlmi" {
  resource_id = azurerm_mssql_managed_instance.this.id
}

resource "azurerm_monitor_diagnostic_setting" "sqlmi" {
  name                       = "diag-${var.name_prefix}-sqlmi"
  target_resource_id         = azurerm_mssql_managed_instance.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.sqlmi.log_category_types

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.sqlmi.metrics

    content {
      category = enabled_metric.value
    }
  }
}
