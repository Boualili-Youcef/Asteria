data "openstack_images_image_v2" "ubuntu" {
  name = var.image_name
}

data "openstack_compute_flavor_v2" "platform" {
  name = var.platform_flavor_name
}

resource "openstack_compute_keypair_v2" "admin" {
  name       = "${var.name_prefix}-admin-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

locals {
  staging_nodes = {
    control_plane = {
      name           = "staging-k8s-control-plane-01"
      role           = "kubernetes-control-plane"
      security_group = "control_plane"
    }
    worker = {
      name           = "staging-k8s-worker-01"
      role           = "kubernetes-worker"
      security_group = "worker"
    }
  }
}

resource "openstack_compute_instance_v2" "node" {
  for_each = local.staging_nodes

  name         = each.value.name
  image_id     = data.openstack_images_image_v2.ubuntu.id
  flavor_id    = data.openstack_compute_flavor_v2.platform.id
  key_pair     = openstack_compute_keypair_v2.admin.name
  config_drive = true

  metadata = {
    data_class  = "synthetic-only"
    environment = "staging"
    managed_by  = "terraform"
    project     = "asteria"
    role        = each.value.role
  }

  network {
    port = openstack_networking_port_v2.node[each.key].id
  }
}

check "cap_05_budget" {
  assert {
    condition = (
      data.openstack_compute_flavor_v2.platform.vcpus * 2 <= 4 &&
      data.openstack_compute_flavor_v2.platform.ram * 2 <= 8192
    )
    error_message = "Les deux nœuds staging dépassent CAP-05 (4 vCPU / 8 Go)."
  }
}
