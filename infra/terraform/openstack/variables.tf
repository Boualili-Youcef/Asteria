variable "name_prefix" {
  description = "Préfixe commun des ressources gérées par Asteria."
  type        = string
  default     = "asteria"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Le préfixe doit contenir uniquement a-z, 0-9 et des tirets."
  }
}

variable "external_network_name" {
  description = "Réseau externe existant, référencé mais jamais géré."
  type        = string
  default     = "prive"
}

variable "admin_cidrs" {
  description = "CIDR IPv4 autorisés à joindre le bastion en SSH."
  type        = set(string)

  validation {
    condition = (
      length(var.admin_cidrs) > 0 &&
      alltrue([
        for cidr in var.admin_cidrs :
        can(regex("^[0-9.]+/[0-9]+$", cidr)) &&
        can(cidrnetmask(cidr)) &&
        try(tonumber(split("/", cidr)[1]), 0) >= 24
      ]) &&
      !contains(var.admin_cidrs, "0.0.0.0/0")
    )
    error_message = "Fournir au moins un CIDR IPv4 valide entre /24 et /32 ; les réseaux larges sont interdits."
  }
}

variable "image_name" {
  description = "Nom exact de l'image OpenStack commune aux cinq VMs."
  type        = string
  default     = "ubuntu24.04"
}

variable "bastion_flavor_name" {
  description = "Flavor du bastion (1 vCPU / 1 Go dans la baseline)."
  type        = string
  default     = "normale"
}

variable "platform_flavor_name" {
  description = "Flavor des nœuds Kubernetes et de PostgreSQL (2 vCPU / 4 Go)."
  type        = string
  default     = "puissante"
}

variable "ssh_public_key_path" {
  description = "Chemin local de la clé SSH publique injectée dans les VMs."
  type        = string
  default     = "~/.ssh/tp_cloud.pub"

  validation {
    condition     = fileexists(pathexpand(var.ssh_public_key_path))
    error_message = "La clé SSH publique indiquée doit exister sur la machine qui exécute Terraform."
  }
}

variable "ssh_user" {
  description = "Utilisateur cloud attendu pour l'image de référence."
  type        = string
  default     = "ubuntu"
}

variable "teleport_staging_agent_cidrs" {
  description = "Adresses /32 des agents Teleport du projet staging autorises vers le proxy T06."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.teleport_staging_agent_cidrs :
      can(cidrnetmask(cidr)) && endswith(cidr, "/32")
    ])
    error_message = "Chaque agent staging Teleport doit etre declare par un CIDR IPv4 /32."
  }
}
