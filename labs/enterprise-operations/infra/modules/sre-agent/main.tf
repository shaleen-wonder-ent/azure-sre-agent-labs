locals {
  sre_agent_admin_role_definition_id = "${var.primary_subscription_id}/providers/Microsoft.Authorization/roleDefinitions/e79298df-d852-4c6d-84f9-5d13249d1e55"
  read_scopes = {
    overlay = var.resource_group_id
    zava    = var.zava_resource_group_id
  }
}

resource "azurerm_user_assigned_identity" "agent" {
  name                = "id-${var.name_prefix}-agent"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azapi_resource" "agent" {
  type      = "Microsoft.App/agents@2025-05-01-preview"
  name      = var.agent_name
  parent_id = var.resource_group_id
  location  = var.location
  tags = merge(var.tags, {
    "hidden-link: /app-insights-resource-id" = var.application_insights_id
  })

  identity {
    type         = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agent.id]
  }

  body = {
    properties = {
      knowledgeGraphConfiguration = {
        managedResources = [var.zava_resource_group_id, var.resource_group_id]
        identity         = azurerm_user_assigned_identity.agent.id
      }
      actionConfiguration = {
        mode        = "autonomous"
        identity    = azurerm_user_assigned_identity.agent.id
        accessLevel = "High"
      }
      defaultModel = {
        name     = var.model_name
        provider = var.model_provider
      }
      upgradeChannel = "Preview"
      experimentalSettings = {
        EnableWorkspaceTools = true
      }
      incidentManagementConfiguration = {
        type           = "AzMonitor"
        connectionName = "azmonitor"
      }
      mcpServers = []
      logConfiguration = {
        applicationInsightsConfiguration = {
          appId            = var.application_insights_app_id
          connectionString = var.application_insights_connection_string
        }
      }
    }
  }

  schema_validation_enabled = false
  response_export_values    = ["properties.agentEndpoint", "identity.principalId"]
}

resource "azurerm_role_assignment" "deployer_agent_admin" {
  name               = uuidv5("url", "${azapi_resource.agent.id}|${var.admin_principal_id}|sre-agent-admin")
  scope              = azapi_resource.agent.id
  role_definition_id = local.sre_agent_admin_role_definition_id
  principal_id       = var.admin_principal_id
}

data "azurerm_role_definition" "reader" {
  name  = "Reader"
  scope = var.primary_subscription_id
}

data "azurerm_role_definition" "monitoring_reader" {
  name  = "Monitoring Reader"
  scope = var.primary_subscription_id
}

data "azurerm_role_definition" "log_analytics_reader" {
  name  = "Log Analytics Reader"
  scope = var.primary_subscription_id
}

data "azurerm_role_definition" "cost_management_reader" {
  count = var.enable_cost_management_reader ? 1 : 0

  name  = "Cost Management Reader"
  scope = var.primary_subscription_id
}

data "azurerm_role_definition" "security_reader" {
  count = var.enable_security_reader ? 1 : 0

  name  = "Security Reader"
  scope = var.primary_subscription_id
}

resource "azurerm_role_assignment" "reader" {
  for_each = local.read_scopes

  name               = uuidv5("url", "${each.value}|${azurerm_user_assigned_identity.agent.principal_id}|reader")
  scope              = each.value
  role_definition_id = data.azurerm_role_definition.reader.id
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "monitoring_reader" {
  for_each = local.read_scopes

  name               = uuidv5("url", "${each.value}|${azurerm_user_assigned_identity.agent.principal_id}|monitoring-reader")
  scope              = each.value
  role_definition_id = data.azurerm_role_definition.monitoring_reader.id
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "log_analytics_reader" {
  name               = uuidv5("url", "${var.log_analytics_workspace_id}|${azurerm_user_assigned_identity.agent.principal_id}|log-analytics-reader")
  scope              = var.log_analytics_workspace_id
  role_definition_id = data.azurerm_role_definition.log_analytics_reader.id
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "cost_management_reader" {
  count = var.enable_cost_management_reader ? 1 : 0

  name               = uuidv5("url", "${var.primary_subscription_id}|${azurerm_user_assigned_identity.agent.principal_id}|cost-management-reader")
  scope              = var.primary_subscription_id
  role_definition_id = data.azurerm_role_definition.cost_management_reader[0].id
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "security_reader" {
  count = var.enable_security_reader ? 1 : 0

  name               = uuidv5("url", "${var.primary_subscription_id}|${azurerm_user_assigned_identity.agent.principal_id}|security-reader")
  scope              = var.primary_subscription_id
  role_definition_id = data.azurerm_role_definition.security_reader[0].id
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "approved_remediation" {
  for_each = var.remediation_role_definition_ids

  name               = uuidv5("url", "${var.zava_resource_group_id}|${azurerm_user_assigned_identity.agent.principal_id}|${each.value}")
  scope              = var.zava_resource_group_id
  role_definition_id = each.value
  principal_id       = azurerm_user_assigned_identity.agent.principal_id
  principal_type     = "ServicePrincipal"
}
