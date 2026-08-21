data "azurerm_network_watcher" "existing" {
  count = var.create_network_watcher ? 0 : 1

  name                = var.network_watcher_name
  resource_group_name = var.network_watcher_resource_group_name
}

resource "azurerm_network_watcher" "this" {
  count = var.create_network_watcher ? 1 : 0

  name                = var.network_watcher_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

locals {
  network_watcher_id = var.create_network_watcher ? azurerm_network_watcher.this[0].id : data.azurerm_network_watcher.existing[0].id
  action_group_id    = var.existing_action_group_id != null ? var.existing_action_group_id : azurerm_monitor_action_group.this[0].id
}

resource "azurerm_network_connection_monitor" "zava" {
  name                          = "cm-${var.name_prefix}-zava"
  network_watcher_id            = local.network_watcher_id
  location                      = var.location
  output_workspace_resource_ids = [var.log_analytics_workspace_id]
  notes                         = "SRE lab reachability from the private diagnostics VM to Zava."
  tags                          = var.tags

  endpoint {
    name               = "diagnostics-vm"
    target_resource_id = var.source_virtual_machine_id

    filter {
      item {
        address = var.source_virtual_machine_id
        type    = "AgentAddress"
      }
      type = "Include"
    }
  }

  endpoint {
    name    = "zava-public-appgw"
    address = var.public_target_address
  }

  dynamic "endpoint" {
    for_each = var.private_target_address == null ? [] : [var.private_target_address]

    content {
      name    = "zava-private"
      address = endpoint.value
    }
  }

  test_configuration {
    name                      = "public-http"
    protocol                  = "Tcp"
    test_frequency_in_seconds = 60
    preferred_ip_version      = "IPv4"

    tcp_configuration {
      port                = 80
      trace_route_enabled = true
    }

    success_threshold {
      checks_failed_percent = 20
      round_trip_time_ms    = 1000
    }
  }

  dynamic "test_configuration" {
    for_each = var.private_target_address == null ? [] : [var.private_target_address]

    content {
      name                      = "private-tcp"
      protocol                  = "Tcp"
      test_frequency_in_seconds = 60
      preferred_ip_version      = "IPv4"

      tcp_configuration {
        port                = 443
        trace_route_enabled = true
      }
    }
  }

  test_group {
    name                     = "public-appgw"
    destination_endpoints    = ["zava-public-appgw"]
    source_endpoints         = ["diagnostics-vm"]
    test_configuration_names = ["public-http"]
  }

  dynamic "test_group" {
    for_each = var.private_target_address == null ? [] : [var.private_target_address]

    content {
      name                     = "private-zava"
      destination_endpoints    = ["zava-private"]
      source_endpoints         = ["diagnostics-vm"]
      test_configuration_names = ["private-tcp"]
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "subscription_activity" {
  name                       = "diag-${var.name_prefix}-activity"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Administrative"
  }
  enabled_log {
    category = "Security"
  }
  enabled_log {
    category = "ServiceHealth"
  }
  enabled_log {
    category = "Alert"
  }
  enabled_log {
    category = "Recommendation"
  }
  enabled_log {
    category = "Policy"
  }
  enabled_log {
    category = "Autoscale"
  }
  enabled_log {
    category = "ResourceHealth"
  }
}

resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  count = var.enable_entra_diagnostics ? 1 : 0

  name                       = "diag-${var.name_prefix}-entra"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditLogs"
  }
  enabled_log {
    category = "SignInLogs"
  }
  enabled_log {
    category = "NonInteractiveUserSignInLogs"
  }
  enabled_log {
    category = "ServicePrincipalSignInLogs"
  }
  enabled_log {
    category = "ManagedIdentitySignInLogs"
  }
  enabled_log {
    category = "ProvisioningLogs"
  }
}

resource "azurerm_monitor_action_group" "this" {
  count = var.existing_action_group_id == null ? 1 : 0

  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(var.name_prefix, "-", ""), 0, 12)
  enabled             = true
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.notification_email_addresses

    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "heartbeat_missing" {
  name                    = "alert-${var.name_prefix}-heartbeat"
  resource_group_name     = var.resource_group_name
  location                = var.location
  scopes                  = [var.log_analytics_workspace_id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  severity                = 2
  display_name            = "SRE diagnostics VM heartbeat missing"
  description             = "No heartbeat from the private diagnostics VM in the last ten minutes."
  enabled                 = true
  auto_mitigation_enabled = true
  skip_query_validation   = true
  tags                    = var.tags

  criteria {
    query                   = <<-QUERY
      Heartbeat
      | where _ResourceId =~ '${var.source_virtual_machine_id}'
      | summarize HeartbeatCount = count()
    QUERY
    time_aggregation_method = "Minimum"
    metric_measure_column   = "HeartbeatCount"
    operator                = "LessThan"
    threshold               = 1

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_cpu" {
  name                    = "alert-${var.name_prefix}-cpu"
  resource_group_name     = var.resource_group_name
  location                = var.location
  scopes                  = [var.log_analytics_workspace_id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT15M"
  severity                = 3
  display_name            = "SRE diagnostics VM high CPU"
  description             = "Average diagnostics VM CPU is above 85 percent."
  enabled                 = true
  auto_mitigation_enabled = true
  skip_query_validation   = true
  tags                    = var.tags

  criteria {
    query                   = <<-QUERY
      Perf
      | where _ResourceId =~ '${var.source_virtual_machine_id}'
      | where ObjectName == 'Processor' and CounterName == '% Processor Time' and InstanceName == '_Total'
      | summarize CpuPercent = avg(CounterValue) by bin(TimeGenerated, 5m)
    QUERY
    time_aggregation_method = "Average"
    metric_measure_column   = "CpuPercent"
    operator                = "GreaterThan"
    threshold               = 85

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 2
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [local.action_group_id]
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "connection_failure" {
  name                    = "alert-${var.name_prefix}-connection"
  resource_group_name     = var.resource_group_name
  location                = var.location
  scopes                  = [var.log_analytics_workspace_id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  severity                = 2
  display_name            = "SRE Connection Monitor failure"
  description             = "Connection Monitor reported failed checks from the diagnostics VM."
  enabled                 = true
  auto_mitigation_enabled = true
  skip_query_validation   = true
  tags                    = var.tags

  criteria {
    query                   = <<-QUERY
      NWConnectionMonitorTestResult
      | where TestResult == 'Failed'
      | summarize FailureCount = count()
    QUERY
    time_aggregation_method = "Total"
    metric_measure_column   = "FailureCount"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [local.action_group_id]
  }

  depends_on = [azurerm_network_connection_monitor.zava]
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "application_failures" {
  name                    = "alert-${var.name_prefix}-app-failures"
  resource_group_name     = var.resource_group_name
  location                = var.location
  scopes                  = [var.application_insights_id]
  evaluation_frequency    = "PT5M"
  window_duration         = "PT15M"
  severity                = 2
  display_name            = "Zava application failure rate"
  description             = "More than five percent of Zava requests failed in the evaluation window."
  enabled                 = true
  auto_mitigation_enabled = true
  skip_query_validation   = true
  tags                    = var.tags

  criteria {
    query                   = <<-QUERY
      AppRequests
      | summarize FailureRate = 100.0 * countif(Success == false) / count()
    QUERY
    time_aggregation_method = "Maximum"
    metric_measure_column   = "FailureRate"
    operator                = "GreaterThan"
    threshold               = 5

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 2
      number_of_evaluation_periods             = 3
    }
  }

  action {
    action_groups = [local.action_group_id]
  }
}
