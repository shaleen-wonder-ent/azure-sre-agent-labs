output "test_resource_group_id" {
  description = "Secondary-subscription test resource group ID."
  value       = azurerm_resource_group.test_scope.id
}
