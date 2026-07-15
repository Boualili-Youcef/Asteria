output "provider_network" {
  description = "Réseau provider existant utilisé comme underlay."
  value = {
    id   = data.openstack_networking_network_v2.external.id
    name = data.openstack_networking_network_v2.external.name
  }
}

output "vm_ports" {
  description = "Ports précréés à attacher aux instances de M06."
  value = {
    bastion = {
      id        = openstack_networking_port_v2.bastion.id
      fixed_ips = openstack_networking_port_v2.bastion.all_fixed_ips
    }
    control_plane = {
      id        = openstack_networking_port_v2.control_plane.id
      fixed_ips = openstack_networking_port_v2.control_plane.all_fixed_ips
    }
    worker_01 = {
      id        = openstack_networking_port_v2.worker_01.id
      fixed_ips = openstack_networking_port_v2.worker_01.all_fixed_ips
    }
    worker_02 = {
      id        = openstack_networking_port_v2.worker_02.id
      fixed_ips = openstack_networking_port_v2.worker_02.all_fixed_ips
    }
    postgres = {
      id        = openstack_networking_port_v2.postgres.id
      fixed_ips = openstack_networking_port_v2.postgres.all_fixed_ips
    }
  }
}

output "security_group_ids" {
  description = "Security groups attachés aux ports."
  value       = local.security_group_ids
}

output "exposure_mode" {
  description = "Mécanisme d'exposition retenu."
  value = {
    mode           = "nodeport-via-bastion"
    http_nodeport  = 30080
    https_nodeport = 30443
    floating_ip    = false
    octavia        = false
  }
}
