output "hub_virtual_network_id" {
  description = "Hub virtual network resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "hub_virtual_network_name" {
  description = "Hub virtual network name."
  value       = azurerm_virtual_network.hub.name
}

output "diagnostics_subnet_id" {
  description = "Private diagnostics subnet resource ID."
  value       = azurerm_subnet.diagnostics.id
}

output "nat_public_ip_address" {
  description = "Deterministic outbound public IP address."
  value       = azurerm_public_ip.nat.ip_address
}

output "diagnostics_route_table_id" {
  description = "Diagnostics route table resource ID."
  value       = azurerm_route_table.diagnostics.id
}
