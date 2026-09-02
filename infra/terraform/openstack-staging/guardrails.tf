data "openstack_identity_auth_scope_v3" "current" {
  name         = "asteria-t05-current-scope"
  set_token_id = false

  lifecycle {
    postcondition {
      condition     = self.project_id == var.expected_project_id
      error_message = "T05 bloquée : le scope authentifié n'est pas le projet secondaire attendu."
    }
  }
}
