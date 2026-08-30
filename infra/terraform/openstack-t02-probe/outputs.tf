output "probe_contract" {
  description = "Contrat réseau temporaire à vérifier puis supprimer."
  value = {
    target_security_group = data.openstack_networking_secgroup_v2.target.name
    source_cidr           = var.source_bastion_cidr
    protocol              = "tcp"
    allowed_port          = 22
    expected_denied_port  = 6443
  }
}
