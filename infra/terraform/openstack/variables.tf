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
        can(regex("^[0-9.]+/[0-9]+$", cidr)) && can(cidrnetmask(cidr))
      ]) &&
      !contains(var.admin_cidrs, "0.0.0.0/0")
    )
    error_message = "Fournir au moins un CIDR valide et ne jamais utiliser 0.0.0.0/0."
  }
}

variable "dns_nameservers" {
  description = "Résolveurs DNS IPv4 fournis par le lab OpenStack."
  type        = list(string)

  validation {
    condition = (
      length(var.dns_nameservers) > 0 &&
      alltrue([
        for address in var.dns_nameservers :
        can(regex("^[0-9.]+$", address)) && can(cidrhost("${address}/32", 0))
      ])
    )
    error_message = "Fournir au moins une adresse DNS IPv4 valide."
  }
}

variable "management_cidr" {
  description = "CIDR du réseau de management."
  type        = string
  default     = "10.20.10.0/24"
}

variable "application_cidr" {
  description = "CIDR du réseau des nœuds Kubernetes."
  type        = string
  default     = "10.20.20.0/24"
}

variable "data_cidr" {
  description = "CIDR du réseau PostgreSQL."
  type        = string
  default     = "10.20.30.0/24"
}

variable "public_services_cidr" {
  description = "CIDR de la DMZ logique."
  type        = string
  default     = "10.20.40.0/24"
}
