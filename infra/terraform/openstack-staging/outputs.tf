output "staging_instances" {
  description = "Baseline des deux VM staging T05."
  value = {
    for key, instance in openstack_compute_instance_v2.node :
    key => {
      name         = instance.name
      status       = instance.power_state
      access_ip_v4 = instance.access_ip_v4
      flavor_name  = instance.flavor_name
      image_name   = instance.image_name
      config_drive = instance.config_drive
      port_id      = openstack_networking_port_v2.node[key].id
    }
  }
}

output "capacity_budget" {
  description = "Consommation maximale décidée par CAP-05."
  value = {
    instances       = 2
    vcpus           = data.openstack_compute_flavor_v2.platform.vcpus * 2
    ram_mb          = data.openstack_compute_flavor_v2.platform.ram * 2
    quota_vcpus     = 4
    quota_ram_mb    = 8192
    remaining_vcpus = 4 - data.openstack_compute_flavor_v2.platform.vcpus * 2
    remaining_ram   = 8192 - data.openstack_compute_flavor_v2.platform.ram * 2
  }
}

output "connectivity_probe_enabled" {
  description = "Doit être faux hors fenêtre de probe T05."
  value       = var.enable_connectivity_probe
}

output "source_bastion_cidr" {
  description = "Source administrative attendue pour le staging."
  value       = var.source_bastion_cidr
  sensitive   = true
}
