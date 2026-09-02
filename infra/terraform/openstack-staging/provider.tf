provider "openstack" {
  # Projet secondaire uniquement. Authentification via OS_* ou OS_CLOUD,
  # jamais par une valeur stockée dans Git ou dans ce state.
  tenant_id = var.expected_project_id
}
