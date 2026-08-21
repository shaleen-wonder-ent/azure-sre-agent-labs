locals {
  resource_group_name = "${var.prefix}-rg"
  vnet_name           = "${var.prefix}-vnet"
  f5_subnet_name      = "f5-subnet"
  backend_subnet_name = "backend-subnet"

  bigip_primary_private_ip = "10.50.1.10"
  application_private_ip   = "10.50.1.20"
  backend_private_ips      = ["10.50.2.10", "10.50.2.11"]

  backend_cloud_init = {
    for index, private_ip in local.backend_private_ips : index => templatefile("${path.module}/templates/backend-cloud-init.yaml.tftpl", {
      node_name  = format("web-%02d", index + 1)
      private_ip = private_ip
    })
  }
}
