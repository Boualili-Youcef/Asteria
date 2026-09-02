data "openstack_networking_network_v2" "provider" {
  name     = var.external_network_name
  external = true
}

resource "openstack_networking_secgroup_v2" "control_plane" {
  name                 = "${var.name_prefix}-control-plane-sg"
  description          = "Asteria T05 - staging control plane"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "worker" {
  name                 = "${var.name_prefix}-worker-sg"
  description          = "Asteria T05 - staging worker"
  delete_default_rules = true
}

locals {
  staging_security_groups = {
    control_plane = openstack_networking_secgroup_v2.control_plane.id
    worker        = openstack_networking_secgroup_v2.worker.id
  }
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv4" {
  for_each = local.staging_security_groups

  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = each.value
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.source_bastion_cidr
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "worker_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.source_bastion_cidr
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_api_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = var.source_bastion_cidr
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_api_from_worker" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_group_id   = openstack_networking_secgroup_v2.worker.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "worker_kubelet_from_control_plane" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_group_id   = openstack_networking_secgroup_v2.control_plane.id
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_networking_secgroup_rule_v2" "probe_from_bastion" {
  count = var.enable_connectivity_probe ? 1 : 0

  description       = "Asteria T05 temporary connectivity probe"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.connectivity_probe_port
  port_range_max    = var.connectivity_probe_port
  remote_ip_prefix  = var.source_bastion_cidr
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_port_v2" "node" {
  for_each = local.staging_nodes

  name           = "${var.name_prefix}-${each.key}-port"
  network_id     = data.openstack_networking_network_v2.provider.id
  admin_state_up = true
  security_group_ids = [
    local.staging_security_groups[each.value.security_group]
  ]
}
