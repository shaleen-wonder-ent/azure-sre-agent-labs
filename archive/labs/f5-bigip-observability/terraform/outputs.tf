output "resource_group_name" {
  description = "Resource group containing the disposable lab."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region used by the Telemetry Streaming consumer."
  value       = azurerm_resource_group.this.location
}

output "log_analytics_workspace_id" {
  description = "Azure resource ID of the dedicated Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_customer_id" {
  description = "Workspace customer ID used by the Telemetry Streaming declaration."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "bigip_management_public_ip" {
  description = "Public IP used for restricted BIG-IP management access."
  value       = azurerm_public_ip.management.ip_address
}

output "bigip_management_url" {
  description = "BIG-IP Configuration Utility URL."
  value       = "https://${azurerm_public_ip.management.ip_address}:8443"
}

output "application_public_ip" {
  description = "Public IP associated with the BIG-IP application VIP."
  value       = azurerm_public_ip.application.ip_address
}

output "application_url" {
  description = "HTTP URL for the demo application."
  value       = "http://${azurerm_public_ip.application.ip_address}"
}

output "bigip_private_ip" {
  description = "Primary BIG-IP private IP."
  value       = local.bigip_primary_private_ip
}

output "application_vip_private_ip" {
  description = "Secondary private IP used by the BIG-IP virtual server."
  value       = local.application_private_ip
}

output "backend_private_ips" {
  description = "Private IPs of the two backend HTTP servers."
  value       = local.backend_private_ips
}
