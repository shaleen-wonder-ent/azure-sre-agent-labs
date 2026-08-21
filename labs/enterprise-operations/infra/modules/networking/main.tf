resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name_prefix}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_network_security_group" "diagnostics" {
  name                = "nsg-${var.name_prefix}-diagnostics"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_route_table" "diagnostics" {
  name                          = "rt-${var.name_prefix}-diagnostics"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_route" "fault_blackhole" {
  count = var.enable_fault_route ? 1 : 0

  name                = "fault-blackhole-default"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.diagnostics.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "None"
}

resource "azurerm_public_ip" "nat" {
  name                = "pip-${var.name_prefix}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "hub" {
  name                    = "ng-${var.name_prefix}-hub"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "hub" {
  nat_gateway_id       = azurerm_nat_gateway.hub.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet" "diagnostics" {
  name                            = "snet-${var.name_prefix}-diagnostics"
  resource_group_name             = var.resource_group_name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = [var.diagnostics_subnet_prefix]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet_network_security_group_association" "diagnostics" {
  subnet_id                 = azurerm_subnet.diagnostics.id
  network_security_group_id = azurerm_network_security_group.diagnostics.id
}

resource "azurerm_subnet_route_table_association" "diagnostics" {
  subnet_id      = azurerm_subnet.diagnostics.id
  route_table_id = azurerm_route_table.diagnostics.id
}

resource "azurerm_subnet_nat_gateway_association" "diagnostics" {
  subnet_id      = azurerm_subnet.diagnostics.id
  nat_gateway_id = azurerm_nat_gateway.hub.id
}

resource "azurerm_virtual_network_peering" "hub_to_zava" {
  name                         = "peer-${var.name_prefix}-hub-to-zava"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = var.zava_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
