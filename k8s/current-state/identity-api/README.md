# identity-api — YAML brut

`identity-api.yaml` contient directement le Deployment, le Service annoté pour
Prometheus et l'Ingress `identity.asteria.local`.

La configuration non sensible doit exister dans `identity-runtime` et le mot de
passe PostgreSQL dans `identity-postgres`. Ils sont créés par
`../scripts/m14-configure-runtime.sh`, jamais stockés dans ce manifest.

Cette méthode n'a ni release Helm, ni historique de valeurs, ni mécanisme de
rollback commun.
