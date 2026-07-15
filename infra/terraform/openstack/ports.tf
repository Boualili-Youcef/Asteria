resource "openstack_networking_port_v2" "bastion" {
  name                  = "${var.name_prefix}-bastion-port"
  network_id            = data.openstack_networking_network_v2.external.id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.bastion.id
  ]
}

resource "openstack_networking_port_v2" "control_plane" {
  name                  = "${var.name_prefix}-control-plane-port"
  network_id            = data.openstack_networking_network_v2.external.id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.control_plane.id
  ]
}

resource "openstack_networking_port_v2" "worker_01" {
  name                  = "${var.name_prefix}-worker-01-port"
  network_id            = data.openstack_networking_network_v2.external.id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.workers.id,
    openstack_networking_secgroup_v2.ingress.id
  ]
}

resource "openstack_networking_port_v2" "worker_02" {
  name                  = "${var.name_prefix}-worker-02-port"
  network_id            = data.openstack_networking_network_v2.external.id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.workers.id,
    openstack_networking_secgroup_v2.ingress.id
  ]
}

resource "openstack_networking_port_v2" "postgres" {
  name                  = "${var.name_prefix}-postgres-port"
  network_id            = data.openstack_networking_network_v2.external.id
  admin_state_up        = true
  port_security_enabled = true
  security_group_ids = [
    openstack_networking_secgroup_v2.postgres.id
  ]
}
