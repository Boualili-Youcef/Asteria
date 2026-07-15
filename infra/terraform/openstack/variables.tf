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
