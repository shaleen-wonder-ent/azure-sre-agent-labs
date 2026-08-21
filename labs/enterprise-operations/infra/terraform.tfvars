# Replace these values with outputs from labs/zava-learning before planning.
zava_resource_group_name          = "REPLACE_WITH_ZAVA_RESOURCE_GROUP"
zava_virtual_network_name         = "REPLACE_WITH_ZAVA_VNET"
zava_log_analytics_workspace_name = "REPLACE_WITH_ZAVA_LOG_ANALYTICS"
zava_application_insights_name    = "REPLACE_WITH_ZAVA_APP_INSIGHTS"
zava_application_gateway_name     = "REPLACE_WITH_ZAVA_APPLICATION_GATEWAY"
admin_ssh_public_key              = "ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY"

# The authenticated Azure CLI subscription is used when subscription_id is null.
subscription_id      = null
zava_subscription_id = null

location    = "centralindia"
environment = "lab"
name_prefix = "sre-eops"

# High-cost and privileged scenarios remain explicit opt-ins.
enable_sql_managed_instance   = false
enable_entra_diagnostics      = false
enable_secondary_subscription = false

# Agent write access remains empty unless a reviewed scenario requires it.
remediation_role_definition_ids = []
