locals {
  subscription_scope = "/subscriptions/${var.secondary_subscription_id}"
}

resource "azurerm_resource_group" "test_scope" {
  name     = "rg-${var.name_prefix}-secondary"
  location = var.location
  tags     = var.tags
}

data "azurerm_role_definition" "reader" {
  name  = "Reader"
  scope = local.subscription_scope
}

data "azurerm_role_definition" "monitoring_reader" {
  name  = "Monitoring Reader"
  scope = local.subscription_scope
}

resource "azurerm_role_assignment" "reader" {
  name               = uuidv5("url", "${azurerm_resource_group.test_scope.id}|${var.agent_principal_id}|reader")
  scope              = azurerm_resource_group.test_scope.id
  role_definition_id = data.azurerm_role_definition.reader.id
  principal_id       = var.agent_principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "monitoring_reader" {
  name               = uuidv5("url", "${azurerm_resource_group.test_scope.id}|${var.agent_principal_id}|monitoring-reader")
  scope              = azurerm_resource_group.test_scope.id
  role_definition_id = data.azurerm_role_definition.monitoring_reader.id
  principal_id       = var.agent_principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-${var.name_prefix}-secondary-activity"
  target_resource_id         = local.subscription_scope
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
