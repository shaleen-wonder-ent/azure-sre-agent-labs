resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.50.0.0/16"]
  tags                = var.tags
}

resource "azurerm_network_security_group" "bigip" {
  name                = "${var.prefix}-f5-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "bigip_ssh" {
  name                        = "AllowManagementSsh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.management_cidr
  destination_address_prefix  = local.bigip_primary_private_ip
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.bigip.name
}

resource "azurerm_network_security_rule" "bigip_ui" {
  name                        = "AllowManagementUi"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = var.management_cidr
  destination_address_prefix  = local.bigip_primary_private_ip
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.bigip.name
}

resource "azurerm_network_security_rule" "bigip_application" {
  name                        = "AllowApplicationVip"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = local.application_private_ip
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.bigip.name
}

resource "azurerm_network_security_group" "backend" {
  name                = "${var.prefix}-backend-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "backend_http" {
  name                        = "AllowHttpFromBigIpSubnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.50.1.0/24"
  destination_address_prefix  = "10.50.2.0/24"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.backend.name
}

resource "azurerm_subnet" "bigip" {
  name                            = local.f5_subnet_name
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.50.1.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "backend" {
  name                            = local.backend_subnet_name
  resource_group_name             = azurerm_resource_group.this.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["10.50.2.0/24"]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "bigip" {
  subnet_id                 = azurerm_subnet.bigip.id
  network_security_group_id = azurerm_network_security_group.bigip.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

resource "azurerm_public_ip" "management" {
  name                    = "${var.prefix}-mgmt-pip"
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  allocation_method       = "Static"
  sku                     = "Standard"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
  tags                    = var.tags
}

resource "azurerm_public_ip" "application" {
  name                    = "${var.prefix}-vip-pip"
  location                = azurerm_resource_group.this.location
  resource_group_name     = azurerm_resource_group.this.name
  allocation_method       = "Static"
  sku                     = "Standard"
  ip_version              = "IPv4"
  idle_timeout_in_minutes = 4
  tags                    = var.tags
}

resource "azurerm_network_interface" "bigip" {
  name                           = "${var.prefix}-bigip-nic"
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  ip_forwarding_enabled          = true
  accelerated_networking_enabled = false
  tags                           = var.tags

  ip_configuration {
    name                          = "primary"
    primary                       = true
    subnet_id                     = azurerm_subnet.bigip.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.bigip_primary_private_ip
    public_ip_address_id          = azurerm_public_ip.management.id
  }

  ip_configuration {
    name                          = "application-vip"
    subnet_id                     = azurerm_subnet.bigip.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.application_private_ip
    public_ip_address_id          = azurerm_public_ip.application.id
  }
}

resource "azurerm_network_interface" "backend" {
  count = length(local.backend_private_ips)

  name                = format("%s-web-%02d-nic", var.prefix, count.index + 1)
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    primary                       = true
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.backend_private_ips[count.index]
  }
}
