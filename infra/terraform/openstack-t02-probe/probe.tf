data "openstack_networking_secgroup_v2" "target" {
  name = var.target_security_group_name
}

resource "openstack_networking_secgroup_rule_v2" "ssh_from_source_bastion" {
  description       = "Asteria T02 temporary SSH probe from source bastion"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.source_bastion_cidr
  security_group_id = data.openstack_networking_secgroup_v2.target.id
}
