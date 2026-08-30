variable "source_bastion_cidr" {
  description = "Adresse IPv4 /32 du bastion du projet source, jamais commitée."
  type        = string

  validation {
    condition = (
      can(cidrnetmask(var.source_bastion_cidr)) &&
      try(tonumber(split("/", var.source_bastion_cidr)[1]), 0) == 32
    )
    error_message = "source_bastion_cidr doit être un CIDR IPv4 strictement en /32."
  }
}

variable "target_security_group_name" {
  description = "Security group existant du projet secondaire utilisé par les deux VM de test."
  type        = string
  default     = "default"

  validation {
    condition     = length(trimspace(var.target_security_group_name)) > 0
    error_message = "Le nom du security group cible ne peut pas être vide."
  }
}
