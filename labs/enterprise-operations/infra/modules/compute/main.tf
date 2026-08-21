resource "azurerm_network_interface" "diagnostics" {
  name                = "nic-${var.name_prefix}-diagnostics"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "diagnostics" {
  name                            = "vm-${var.name_prefix}-diag"
  computer_name                   = "srediag"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.diagnostics.id]
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  patch_assessment_mode           = "AutomaticByPlatform"
  patch_mode                      = "AutomaticByPlatform"
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    name                 = "osdisk-${var.name_prefix}-diag"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.diagnostics.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.33"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

resource "azurerm_virtual_machine_extension" "network_watcher_agent" {
  name                       = "NetworkWatcherAgentLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.diagnostics.id
  publisher                  = "Microsoft.Azure.NetworkWatcher"
  type                       = "NetworkWatcherAgentLinux"
  type_handler_version       = "1.4"
  automatic_upgrade_enabled  = true
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

resource "azurerm_monitor_data_collection_rule" "diagnostics" {
  name                = "dcr-${var.name_prefix}-diagnostics"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "zava-law"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["zava-law"]
  }

  data_sources {
    performance_counter {
      name                          = "core-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes",
        "\\LogicalDisk(*)\\% Free Space",
        "\\Network(*)\\Total Bytes Transmitted",
      ]
    }

    syslog {
      name           = "warning-and-higher"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "syslog", "user"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "diagnostics" {
  name                    = "dcra-${var.name_prefix}-diagnostics"
  target_resource_id      = azurerm_linux_virtual_machine.diagnostics.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.diagnostics.id
  description             = "Collect diagnostics VM performance and warning-level syslog."

  depends_on = [azurerm_virtual_machine_extension.azure_monitor_agent]
}
