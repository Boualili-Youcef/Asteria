data "openstack_images_image_v2" "ubuntu" {
  name = var.image_name
}

data "openstack_compute_flavor_v2" "bastion" {
  name = var.bastion_flavor_name
}

data "openstack_compute_flavor_v2" "platform" {
  name = var.platform_flavor_name
}

resource "openstack_compute_keypair_v2" "admin" {
  name       = "${var.name_prefix}-admin-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

locals {
  instances = {
    bastion = {
      name      = "bastion-admin-01"
      role      = "bastion"
      flavor_id = data.openstack_compute_flavor_v2.bastion.id
      port_id   = openstack_networking_port_v2.bastion.id
    }
    control_plane = {
      name      = "k8s-control-plane-01"
      role      = "kubernetes-control-plane"
      flavor_id = data.openstack_compute_flavor_v2.platform.id
      port_id   = openstack_networking_port_v2.control_plane.id
    }
    worker_01 = {
      name      = "k8s-worker-01"
      role      = "kubernetes-worker"
      flavor_id = data.openstack_compute_flavor_v2.platform.id
      port_id   = openstack_networking_port_v2.worker_01.id
    }
    worker_02 = {
      name      = "k8s-worker-02"
      role      = "kubernetes-worker"
      flavor_id = data.openstack_compute_flavor_v2.platform.id
      port_id   = openstack_networking_port_v2.worker_02.id
    }
    postgres = {
      name      = "db-postgres-01"
      role      = "postgresql"
      flavor_id = data.openstack_compute_flavor_v2.platform.id
      port_id   = openstack_networking_port_v2.postgres.id
    }
  }
}

resource "openstack_compute_instance_v2" "vm" {
  for_each = local.instances

  name      = each.value.name
  image_id  = data.openstack_images_image_v2.ubuntu.id
  flavor_id = each.value.flavor_id
  key_pair  = openstack_compute_keypair_v2.admin.name

  metadata = {
    environment = "phase-1-as-is"
    managed_by  = "terraform"
    project     = "asteria"
    role        = each.value.role
  }

  network {
    port = each.value.port_id
  }
}
