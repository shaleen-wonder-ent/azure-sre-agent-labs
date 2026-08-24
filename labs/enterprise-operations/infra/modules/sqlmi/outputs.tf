output "managed_instance_id" {
  description = "SQL Managed Instance resource ID."
  value       = azurerm_mssql_managed_instance.this.id
}

output "managed_instance_fqdn" {
  description = "Private VNet-local SQL Managed Instance FQDN."
  value       = azurerm_mssql_managed_instance.this.fqdn
}

output "database_id" {
  description = "Dedicated SQL MI performance demo database ID."
  value       = azurerm_mssql_managed_database.demo.id
}

output "database_name" {
  description = "Dedicated SQL MI performance demo database name."
  value       = azurerm_mssql_managed_database.demo.name
}

output "subnet_id" {
  description = "Dedicated SQL Managed Instance subnet ID."
  value       = azurerm_subnet.sqlmi.id
}
