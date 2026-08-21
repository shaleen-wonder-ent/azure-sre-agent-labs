resource "azurerm_linux_virtual_machine" "bigip" {
  name                            = "${var.prefix}-bigip"
  computer_name                   = "${var.prefix}-bigip"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.bigip_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.bigip.id]
  secure_boot_enabled             = false
  vtpm_enabled                    = false
  tags                            = var.tags

  identity {
    type = "SystemAssigned"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.admin_ssh_public_key)
  }

  os_disk {
    name                 = "${var.prefix}-bigip-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "f5-networks"
    offer     = "f5-big-ip-best"
    sku       = "f5-big-best-plus-hourly-25mbps-po-f5"
    version   = var.bigip_image_version
  }

  plan {
    name      = "f5-big-best-plus-hourly-25mbps"
    product   = "f5-big-ip-best"
    publisher = "f5-networks"
  }

  boot_diagnostics {}
}

resource "azurerm_linux_virtual_machine" "backend" {
  count = length(local.backend_private_ips)

  name                            = format("%s-web-%02d", var.prefix, count.index + 1)
  computer_name                   = format("web-%02d", count.index + 1)
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.backend_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.backend[count.index].id]
  custom_data                     = base64encode(local.backend_cloud_init[count.index])
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.admin_ssh_public_key)
  }

  os_disk {
    name                 = format("%s-web-%02d-osdisk", var.prefix, count.index + 1)
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_role_assignment" "bigip_log_analytics" {
  name                 = uuidv5("url", "${azurerm_log_analytics_workspace.this.id}|${azurerm_linux_virtual_machine.bigip.identity[0].principal_id}|Log Analytics Contributor")
  scope                = azurerm_log_analytics_workspace.this.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_linux_virtual_machine.bigip.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "bigip_subscription_reader" {
  name                 = uuidv5("url", "/subscriptions/${var.subscription_id}|${azurerm_linux_virtual_machine.bigip.identity[0].principal_id}|Reader")
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.bigip.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}
