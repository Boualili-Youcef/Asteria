variable "name_prefix" {
  description = "Préfixe des ressources du staging Asteria."
  type        = string
  default     = "asteria-staging"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Le préfixe doit contenir uniquement a-z, 0-9 et des tirets."
  }
}

variable "expected_project_id" {
  description = "ID privé du projet secondaire attendu ; fourni via TF_VAR_expected_project_id."
  type        = string
  sensitive   = true

  validation {
    condition = (
      can(regex("^[0-9a-fA-F]{32}$", var.expected_project_id)) ||
      can(regex("^[0-9a-fA-F-]{36}$", var.expected_project_id))
    )
    error_message = "expected_project_id doit être un ID OpenStack de 32 caractères hexadécimaux ou un UUID."
  }
}

variable "external_network_name" {
  description = "Réseau provider existant, référencé et jamais géré par T05."
  type        = string
  default     = "prive"
}

variable "image_name" {
  description = "Image Ubuntu 24.04 observée dans le projet secondaire."
  type        = string
  default     = "ubuntu24.04"
}

variable "platform_flavor_name" {
  description = "Flavor 2 vCPU / 4 Go retenu pour chacun des deux nœuds CAP-05."
  type        = string
  default     = "puissante"
}

variable "source_bastion_cidr" {
  description = "Adresse /32 du bastion source autorisée à administrer le staging."
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.source_bastion_cidr)) &&
      try(tonumber(split("/", var.source_bastion_cidr)[1]), 0) == 32
    )
    error_message = "source_bastion_cidr doit être un CIDR IPv4 strictement en /32."
  }
}

variable "ssh_public_key_path" {
  description = "Clé publique locale injectée par config-drive dans le staging."
  type        = string
  default     = "~/.ssh/tp_cloud.pub"

  validation {
    condition     = fileexists(pathexpand(var.ssh_public_key_path))
    error_message = "La clé publique SSH doit exister sur le contrôleur Terraform."
  }
}

variable "enable_connectivity_probe" {
  description = "Autorise temporairement le probe T05 depuis le bastion ; faux hors test contrôlé."
  type        = bool
  default     = false
}

variable "connectivity_probe_port" {
  description = "Port TCP temporaire du test positif/négatif et de rollback T05."
  type        = number
  default     = 18080

  validation {
    condition = (
      var.connectivity_probe_port >= 1024 &&
      var.connectivity_probe_port <= 65535
    )
    error_message = "Le port de probe doit être compris entre 1024 et 65535."
  }
}
