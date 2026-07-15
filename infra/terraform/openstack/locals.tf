locals {
  networks = {
    management = {
      name       = "${var.name_prefix}-mgmt-net"
      cidr       = var.management_cidr
      gateway_ip = cidrhost(var.management_cidr, 1)
      pool_start = cidrhost(var.management_cidr, 20)
      pool_end   = cidrhost(var.management_cidr, 199)
    }
    application = {
      name       = "${var.name_prefix}-app-net"
      cidr       = var.application_cidr
      gateway_ip = cidrhost(var.application_cidr, 1)
      pool_start = cidrhost(var.application_cidr, 20)
      pool_end   = cidrhost(var.application_cidr, 199)
    }
    data = {
      name       = "${var.name_prefix}-data-net"
      cidr       = var.data_cidr
      gateway_ip = cidrhost(var.data_cidr, 1)
      pool_start = cidrhost(var.data_cidr, 20)
      pool_end   = cidrhost(var.data_cidr, 199)
    }
    public_services = {
      name       = "${var.name_prefix}-public-services-net"
      cidr       = var.public_services_cidr
      gateway_ip = cidrhost(var.public_services_cidr, 1)
      pool_start = cidrhost(var.public_services_cidr, 20)
      pool_end   = cidrhost(var.public_services_cidr, 199)
    }
  }
}
