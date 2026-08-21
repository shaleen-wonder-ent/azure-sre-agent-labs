output "agent_id" {
  description = "Azure SRE Agent resource ID."
  value       = azapi_resource.agent.id
}

output "agent_name" {
  description = "Azure SRE Agent name."
  value       = azapi_resource.agent.name
}

output "agent_endpoint" {
  description = "Azure SRE Agent endpoint returned by the preview API."
  value       = try(azapi_resource.agent.output.properties.agentEndpoint, null)
}

output "agent_portal_url" {
  description = "Azure SRE Agent portal URL."
  value       = "https://sre.azure.com/agents${azapi_resource.agent.id}"
}

output "agent_identity_id" {
  description = "UAMI resource ID used for SRE Agent actions and knowledge."
  value       = azurerm_user_assigned_identity.agent.id
}

output "agent_identity_principal_id" {
  description = "UAMI principal ID used for RBAC."
  value       = azurerm_user_assigned_identity.agent.principal_id
}
