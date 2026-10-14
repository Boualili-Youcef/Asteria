# Demo v1

Une extension Orders isolée ; voir [ADR-015](../docs/adr/ADR-015-demo-v1-source-only.md).

- Tests sans installation/réseau : `bash demo/scripts/test-offline.sh`.
- Audit source de lecture : `python3 demo/scripts/preflight.py --read-source`.
- Audit OpenStack après chargement privé de l'OpenRC source :
  `python3 demo/scripts/openstack-read.py`.
- Site autonome : [runbook](../docs/demo-v1/DEMO-5-MINUTES.md).
- Promotion : `python3 demo/scripts/promote.py --help`, aperçu par défaut.
- Test Docker : `python3 demo/scripts/local-e2e.py --help` ; images PostgreSQL
  et Redis préchargées par digest, aucune VM ni base historique utilisée.

Le bootstrap Kubernetes proposé dans `manifests/isolation.yaml` n'est pas
appliqué et ne suffit pas encore à activer le live : il manque le provisionnement
de données séparées et la validation des NetworkPolicies. Ne pas l'appliquer
sur un contexte déduit implicitement. Le rôle Helm peut lire les Secrets de
démo ; ne jamais le réutiliser dans un namespace historique.

Le site se construit avec une allowlist de quatre fichiers publics. Héberger
uniquement le répertoire produit, jamais la racine du dépôt ou `.secrets`.
Sur GitHub Pages, utiliser le bundle comme artefact statique, avec les permissions
`pages:write` et `id-token:write` uniquement dans un job de publication autorisé.
L'hébergement doit faire l'objet d'une activation distincte ; aucun lien public
n'est inventé avant déploiement.
