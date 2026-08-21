output "managed_instance_id" {
  description = "SQL Managed Instance resource ID."
  value       = azurerm_mssql_managed_instance.this.id
}

output "managed_instance_fqdn" {
  description = "Private VNet-local SQL Managed Instance FQDN."
  value       = azurerm_mssql_managed_instance.this.fqdn
}

output "subnet_id" {
  description = "Dedicated SQL Managed Instance subnet ID."
  value       = azurerm_subnet.sqlmi.id
}
