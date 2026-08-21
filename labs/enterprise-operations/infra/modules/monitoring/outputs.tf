output "network_watcher_id" {
  description = "Network Watcher resource ID used by Connection Monitor."
  value       = local.network_watcher_id
}

output "connection_monitor_id" {
  description = "Connection Monitor resource ID."
  value       = azurerm_network_connection_monitor.zava.id
}

output "action_group_id" {
  description = "Created or supplied action group resource ID."
  value       = local.action_group_id
}

output "alert_rule_ids" {
  description = "Focused SRE lab alert rule resource IDs."
  value = {
    heartbeat_missing    = azurerm_monitor_scheduled_query_rules_alert_v2.heartbeat_missing.id
    high_cpu             = azurerm_monitor_scheduled_query_rules_alert_v2.high_cpu.id
    connection_failure   = azurerm_monitor_scheduled_query_rules_alert_v2.connection_failure.id
    application_failures = azurerm_monitor_scheduled_query_rules_alert_v2.application_failures.id
  }
}
