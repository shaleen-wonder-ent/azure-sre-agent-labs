# Values verified from the deployed srelab-zava environment.
zava_resource_group_name          = "rg-zava-learning-srelab-zava"
zava_virtual_network_name         = "vnet-zava-t2gn3pt35jtsy"
zava_log_analytics_workspace_name = "log-zava-t2gn3pt35jtsy"
zava_application_insights_name    = "appi-zava-t2gn3pt35jtsy"
zava_application_gateway_name     = "agw-zava-t2gn3pt35jtsy"
admin_ssh_public_key              = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJmo+fM8pCWk2GlwwX2DMwNDucjGPv8pH96iAHODszWr arck8s-demo"

subscription_id      = "09e7c1cb-53ca-4d05-bcf0-8881c42e680e"
zava_subscription_id = "09e7c1cb-53ca-4d05-bcf0-8881c42e680e"

location           = "centralindia"
sre_agent_location = "eastus2"
environment        = "lab"
name_prefix        = "sre-eops"

# High-cost and privileged scenarios remain explicit opt-ins.
enable_sql_managed_instance     = true
sqlmi_database_name             = "sre_demo"
sqlmi_sku_name                  = "GP_Gen5"
sqlmi_vcores                    = 4
sqlmi_storage_size_gb           = 32
sqlmi_license_type              = "LicenseIncluded"
sqlmi_entra_administrator_login = "shaleent@microsoft.com"
enable_entra_diagnostics        = false
enable_secondary_subscription   = false

# Agent write access remains empty unless a reviewed scenario requires it.
remediation_role_definition_ids = []
