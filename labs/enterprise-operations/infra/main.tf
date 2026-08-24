resource "azurerm_resource_group" "overlay" {
  name     = "rg-${local.resource_token}"
  location = var.location
  tags     = local.tags
}

check "hub_does_not_overlap_zava" {
  assert {
    condition = alltrue([
      for zava_range in local.zava_address_ranges :
      local.hub_end < zava_range.start || zava_range.end < local.hub_start
    ])
    error_message = "hub_address_space overlaps an existing Zava VNet address space. Choose a non-overlapping RFC1918 CIDR."
  }
}

check "overlay_subnets_do_not_overlap" {
  assert {
    condition     = local.diagnostics_end < local.sqlmi_start || local.sqlmi_end < local.diagnostics_start
    error_message = "diagnostics_subnet_prefix and sqlmi_subnet_prefix must not overlap."
  }
}

check "overlay_subnets_are_inside_hub" {
  assert {
    condition = (
      local.hub_start <= local.diagnostics_start && local.diagnostics_end <= local.hub_end &&
      local.hub_start <= local.sqlmi_start && local.sqlmi_end <= local.hub_end
    )
    error_message = "diagnostics_subnet_prefix and sqlmi_subnet_prefix must both be contained within hub_address_space."
  }
}

check "secondary_subscription_inputs" {
  assert {
    condition     = !var.enable_secondary_subscription || var.secondary_subscription_id != null
    error_message = "secondary_subscription_id is required when enable_secondary_subscription is true."
  }
}

module "networking" {
  source = "./modules/networking"

  name_prefix               = local.resource_token
  resource_group_name       = azurerm_resource_group.overlay.name
  location                  = azurerm_resource_group.overlay.location
  hub_address_space         = var.hub_address_space
  diagnostics_subnet_prefix = var.diagnostics_subnet_prefix
  zava_virtual_network_id   = data.azurerm_virtual_network.zava.id
  enable_fault_route        = var.enable_network_fault_route
  tags                      = local.tags
}

resource "azurerm_virtual_network_peering" "zava_to_hub" {
  provider = azurerm.zava

  name                         = "peer-zava-to-${local.resource_token}-hub"
  resource_group_name          = data.azurerm_resource_group.zava.name
  virtual_network_name         = data.azurerm_virtual_network.zava.name
  remote_virtual_network_id    = module.networking.hub_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_user_assigned_identity" "sqlmi_workload" {
  count = var.enable_sql_managed_instance ? 1 : 0

  name                = "id-${local.resource_token}-sqlmi-workload"
  location            = azurerm_resource_group.overlay.location
  resource_group_name = azurerm_resource_group.overlay.name
  tags                = local.tags
}

module "compute" {
  source = "./modules/compute"

  name_prefix                   = local.resource_token
  resource_group_name           = azurerm_resource_group.overlay.name
  location                      = azurerm_resource_group.overlay.location
  data_collection_rule_location = data.azurerm_log_analytics_workspace.zava.location
  subnet_id                     = module.networking.diagnostics_subnet_id
  log_analytics_workspace_id    = data.azurerm_log_analytics_workspace.zava.id
  vm_size                       = var.diagnostics_vm_size
  admin_username                = var.admin_username
  admin_ssh_public_key          = var.admin_ssh_public_key
  user_assigned_identity_ids    = var.enable_sql_managed_instance ? [azurerm_user_assigned_identity.sqlmi_workload[0].id] : []
  tags                          = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix                         = local.resource_token
  resource_group_name                 = azurerm_resource_group.overlay.name
  location                            = azurerm_resource_group.overlay.location
  subscription_id                     = data.azurerm_client_config.current.subscription_id
  log_analytics_workspace_id          = data.azurerm_log_analytics_workspace.zava.id
  application_insights_id             = data.azurerm_application_insights.zava.id
  source_virtual_machine_id           = module.compute.virtual_machine_id
  public_target_address               = data.azurerm_public_ip.zava_application_gateway.ip_address
  private_target_address              = var.zava_private_probe_address
  network_watcher_name                = var.network_watcher_name
  network_watcher_resource_group_name = var.network_watcher_resource_group_name
  create_network_watcher              = var.create_network_watcher
  notification_email_addresses        = var.notification_email_addresses
  existing_action_group_id            = var.existing_action_group_id
  enable_entra_diagnostics            = var.enable_entra_diagnostics
  tags                                = local.tags

  depends_on = [module.compute]
}

module "sre_agent" {
  source = "./modules/sre-agent"

  name_prefix                            = local.resource_token
  agent_name                             = local.agent_name
  resource_group_id                      = azurerm_resource_group.overlay.id
  resource_group_name                    = azurerm_resource_group.overlay.name
  zava_resource_group_id                 = data.azurerm_resource_group.zava.id
  location                               = var.sre_agent_location
  identity_location                      = azurerm_resource_group.overlay.location
  primary_subscription_id                = data.azurerm_subscription.primary.id
  log_analytics_workspace_id             = data.azurerm_log_analytics_workspace.zava.id
  application_insights_id                = data.azurerm_application_insights.zava.id
  application_insights_app_id            = data.azurerm_application_insights.zava.app_id
  application_insights_connection_string = data.azurerm_application_insights.zava.connection_string
  model_provider                         = var.sre_agent_model_provider
  model_name                             = var.sre_agent_model_name
  admin_principal_id                     = coalesce(var.sre_agent_admin_principal_id, data.azurerm_client_config.current.object_id)
  enable_cost_management_reader          = var.enable_cost_management_reader
  enable_security_reader                 = var.enable_security_reader
  remediation_role_definition_ids        = var.remediation_role_definition_ids
  tags                                   = local.tags
}

module "sqlmi" {
  count  = var.enable_sql_managed_instance ? 1 : 0
  source = "./modules/sqlmi"

  name_prefix                = local.resource_token
  managed_instance_name      = local.sqlmi_name
  database_name              = var.sqlmi_database_name
  resource_group_name        = azurerm_resource_group.overlay.name
  location                   = azurerm_resource_group.overlay.location
  virtual_network_name       = module.networking.hub_virtual_network_name
  subnet_prefix              = var.sqlmi_subnet_prefix
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.zava.id
  sku_name                   = var.sqlmi_sku_name
  vcores                     = var.sqlmi_vcores
  storage_size_gb            = var.sqlmi_storage_size_gb
  license_type               = var.sqlmi_license_type
  entra_administrator_login  = var.sqlmi_entra_administrator_login
  entra_administrator_id     = data.azurerm_client_config.current.object_id
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  tags                       = local.tags
}

module "secondary_subscription" {
  count  = var.enable_secondary_subscription ? 1 : 0
  source = "./modules/secondary-subscription"

  providers = {
    azurerm = azurerm.secondary
  }

  name_prefix                = local.resource_token
  location                   = var.location
  secondary_subscription_id  = var.secondary_subscription_id
  agent_principal_id         = module.sre_agent.agent_identity_principal_id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.zava.id
  tags                       = local.tags
}
