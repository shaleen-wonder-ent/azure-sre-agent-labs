locals {
  resource_token = "${var.name_prefix}-${var.environment}"

  hub_prefix_length = tonumber(split("/", var.hub_address_space)[1])
  hub_start = sum([
    for index, octet in split(".", cidrhost(var.hub_address_space, 0)) :
    tonumber(octet) * pow(256, 3 - index)
  ])
  hub_end = local.hub_start + pow(2, 32 - local.hub_prefix_length) - 1

  diagnostics_prefix_length = tonumber(split("/", var.diagnostics_subnet_prefix)[1])
  diagnostics_start = sum([
    for index, octet in split(".", cidrhost(var.diagnostics_subnet_prefix, 0)) :
    tonumber(octet) * pow(256, 3 - index)
  ])
  diagnostics_end = local.diagnostics_start + pow(2, 32 - local.diagnostics_prefix_length) - 1

  sqlmi_prefix_length = tonumber(split("/", var.sqlmi_subnet_prefix)[1])
  sqlmi_start = sum([
    for index, octet in split(".", cidrhost(var.sqlmi_subnet_prefix, 0)) :
    tonumber(octet) * pow(256, 3 - index)
  ])
  sqlmi_end = local.sqlmi_start + pow(2, 32 - local.sqlmi_prefix_length) - 1

  zava_address_ranges = [
    for cidr in data.azurerm_virtual_network.zava.address_space : {
      start = sum([
        for index, octet in split(".", cidrhost(cidr, 0)) :
        tonumber(octet) * pow(256, 3 - index)
      ])
      end = sum([
        for index, octet in split(".", cidrhost(cidr, 0)) :
        tonumber(octet) * pow(256, 3 - index)
      ]) + pow(2, 32 - tonumber(split("/", cidr)[1])) - 1
    }
  ]

  required_tags = {
    environment  = var.environment
    workload     = "enterprise-operations-sre-lab"
    managed-by   = "terraform"
    scenarioPack = "13-use-cases"
  }

  tags = merge(local.required_tags, var.tags)

  agent_name = coalesce(var.sre_agent_name, "${local.resource_token}-${random_string.suffix.result}")
  sqlmi_name = coalesce(var.sqlmi_name, "sqlmi-${var.environment}-${random_string.suffix.result}")
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}
