resource "openstack_networking_secgroup_v2" "bastion" {
  name                 = "${var.name_prefix}-bastion-sg"
  description          = "Asteria AS-IS - acces administratif au bastion"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "control_plane" {
  name                 = "${var.name_prefix}-control-plane-sg"
  description          = "Asteria AS-IS - control plane Kubernetes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "workers" {
  name                 = "${var.name_prefix}-workers-sg"
  description          = "Asteria AS-IS - workers Kubernetes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "ingress" {
  name                 = "${var.name_prefix}-ingress-sg"
  description          = "Asteria AS-IS - NodePorts ingress-nginx prives"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "postgres" {
  name                 = "${var.name_prefix}-postgres-sg"
  description          = "Asteria AS-IS - PostgreSQL hors cluster"
  delete_default_rules = true
}

locals {
  security_group_ids = {
    bastion       = openstack_networking_secgroup_v2.bastion.id
    control_plane = openstack_networking_secgroup_v2.control_plane.id
    workers       = openstack_networking_secgroup_v2.workers.id
    ingress       = openstack_networking_secgroup_v2.ingress.id
    postgres      = openstack_networking_secgroup_v2.postgres.id
  }
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv4" {
  for_each = local.security_group_ids

  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = each.value
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  for_each = var.admin_cidrs

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_api_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_api_from_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_group_id   = openstack_networking_secgroup_v2.workers.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_kubelet_from_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_group_id   = openstack_networking_secgroup_v2.workers.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "control_plane_vxlan_from_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8472
  port_range_max    = 8472
  remote_group_id   = openstack_networking_secgroup_v2.workers.id
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "workers_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "workers_kubelet_from_control_plane" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_group_id   = openstack_networking_secgroup_v2.control_plane.id
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "workers_vxlan_from_control_plane" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8472
  port_range_max    = 8472
  remote_group_id   = openstack_networking_secgroup_v2.control_plane.id
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "workers_vxlan_from_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 8472
  port_range_max    = 8472
  remote_group_id   = openstack_networking_secgroup_v2.workers.id
  security_group_id = openstack_networking_secgroup_v2.workers.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_http_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30080
  port_range_max    = 30080
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.ingress.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_https_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30443
  port_range_max    = 30443
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.ingress.id
}

resource "openstack_networking_secgroup_rule_v2" "postgres_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.postgres.id
}

resource "openstack_networking_secgroup_rule_v2" "postgres_from_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5432
  port_range_max    = 5432
  remote_group_id   = openstack_networking_secgroup_v2.workers.id
  security_group_id = openstack_networking_secgroup_v2.postgres.id
}
