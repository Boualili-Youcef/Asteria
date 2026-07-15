data "openstack_networking_network_v2" "external" {
  name     = var.external_network_name
  external = true
}

resource "openstack_networking_network_v2" "internal" {
  for_each = local.networks

  name                  = each.value.name
  admin_state_up        = true
  port_security_enabled = true
}

resource "openstack_networking_subnet_v2" "internal" {
  for_each = local.networks

  name            = "${each.value.name}-subnet"
  network_id      = openstack_networking_network_v2.internal[each.key].id
  cidr            = each.value.cidr
  gateway_ip      = each.value.gateway_ip
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = each.value.pool_start
    end   = each.value.pool_end
  }
}

resource "openstack_networking_router_v2" "asteria" {
  name                = "${var.name_prefix}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "internal" {
  for_each = openstack_networking_subnet_v2.internal

  router_id = openstack_networking_router_v2.asteria.id
  subnet_id = each.value.id
}
