output "external_network" {
  description = "Réseau externe existant utilisé par le routeur."
  value = {
    id   = data.openstack_networking_network_v2.external.id
    name = data.openstack_networking_network_v2.external.name
  }
}

output "internal_network_ids" {
  description = "IDs des réseaux internes créés."
  value = {
    for key, network in openstack_networking_network_v2.internal :
    key => network.id
  }
}

output "internal_subnet_ids" {
  description = "IDs des sous-réseaux internes créés."
  value = {
    for key, subnet in openstack_networking_subnet_v2.internal :
    key => subnet.id
  }
}

output "router_id" {
  description = "ID du routeur Asteria."
  value       = openstack_networking_router_v2.asteria.id
}

output "security_group_ids" {
  description = "IDs des security groups à attacher aux ports de M06."
  value       = local.security_group_ids
}

output "exposure_mode" {
  description = "Mécanisme d'exposition retenu pour le lab."
  value = {
    mode           = "nodeport-via-bastion"
    http_nodeport  = 30080
    https_nodeport = 30443
    floating_ip    = false
    octavia        = false
  }
}
