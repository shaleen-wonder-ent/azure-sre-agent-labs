output "virtual_machine_id" {
  description = "Diagnostics VM resource ID."
  value       = azurerm_linux_virtual_machine.diagnostics.id
}

output "virtual_machine_name" {
  description = "Diagnostics VM name."
  value       = azurerm_linux_virtual_machine.diagnostics.name
}

output "virtual_machine_principal_id" {
  description = "Diagnostics VM system-assigned identity principal ID."
  value       = azurerm_linux_virtual_machine.diagnostics.identity[0].principal_id
}

output "private_ip_address" {
  description = "Diagnostics VM private IP address."
  value       = azurerm_network_interface.diagnostics.private_ip_address
}

output "data_collection_rule_id" {
  description = "Diagnostics VM DCR resource ID."
  value       = azurerm_monitor_data_collection_rule.diagnostics.id
}

output "network_watcher_extension_id" {
  description = "Network Watcher extension resource ID."
  value       = azurerm_virtual_machine_extension.network_watcher_agent.id
}
