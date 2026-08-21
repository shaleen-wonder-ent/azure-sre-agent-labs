output "resource_group_id" {
  description = "Enterprise operations overlay resource group ID."
  value       = azurerm_resource_group.overlay.id
}

output "sre_agent_id" {
  description = "Azure SRE Agent resource ID."
  value       = module.sre_agent.agent_id
}

output "sre_agent_name" {
  description = "Azure SRE Agent name."
  value       = module.sre_agent.agent_name
}

output "sre_agent_endpoint" {
  description = "Azure SRE Agent endpoint returned by the preview API."
  value       = module.sre_agent.agent_endpoint
}

output "sre_agent_portal_url" {
  description = "Azure SRE Agent portal URL."
  value       = module.sre_agent.agent_portal_url
}

output "sre_agent_identity_id" {
  description = "UAMI resource ID used by SRE Agent actions and knowledge."
  value       = module.sre_agent.agent_identity_id
}

output "hub_virtual_network_id" {
  description = "SRE hub VNet resource ID."
  value       = module.networking.hub_virtual_network_id
}

output "diagnostics_vm_id" {
  description = "Private diagnostics VM resource ID."
  value       = module.compute.virtual_machine_id
}

output "diagnostics_vm_private_ip" {
  description = "Private diagnostics VM address."
  value       = module.compute.private_ip_address
}

output "nat_public_ip_address" {
  description = "Deterministic outbound IP for the diagnostics subnet."
  value       = module.networking.nat_public_ip_address
}

output "connection_monitor_id" {
  description = "Zava Connection Monitor resource ID."
  value       = module.monitoring.connection_monitor_id
}

output "action_group_id" {
  description = "Created or supplied action group resource ID."
  value       = module.monitoring.action_group_id
}

output "zava_public_endpoint_ip" {
  description = "Existing Zava Application Gateway public IP used by Connection Monitor."
  value       = data.azurerm_public_ip.zava_application_gateway.ip_address
}

output "zava_resource_group_id" {
  description = "Existing Zava resource group ID."
  value       = data.azurerm_resource_group.zava.id
}

output "zava_log_analytics_workspace_id" {
  description = "Existing Zava Log Analytics workspace ID."
  value       = data.azurerm_log_analytics_workspace.zava.id
}

output "primary_subscription_id" {
  description = "Primary subscription ID used by the overlay."
  value       = data.azurerm_client_config.current.subscription_id
}

output "sqlmi_fqdn" {
  description = "Optional private SQL MI FQDN."
  value       = try(module.sqlmi[0].managed_instance_fqdn, null)
}

output "secondary_test_resource_group_id" {
  description = "Optional second-subscription test scope resource group ID."
  value       = try(module.secondary_subscription[0].test_resource_group_id, null)
}
