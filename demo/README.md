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
appliqué. Le générateur `scripts/prepare-bootstrap.py` prépare les données
synthétiques séparées et les NetworkPolicies ; leurs validations K3s restent requises. Ne pas l'appliquer
sur un contexte déduit implicitement. Le rôle Helm peut lire les Secrets de
démo ; ne jamais le réutiliser dans un namespace historique.

La CI complète réussie est enregistrée dans `evidence/orders-release.json`,
`evidence/ci-verification-20261014.json` et `evidence/ci-functional-20261014.json`.
Le package Orders est public : manifeste anonyme et digest vérifiés depuis
le poste et les deux workers ; téléchargement complet réussi sur le poste.
Aucun token de registre n'est requis. Le [plan de bootstrap](../docs/demo-v1/BOOTSTRAP.md)
prépare quatre services séparés et leurs tests ; il n'a pas encore été appliqué.
Aucun credential CI n'est copié dans le cluster.

Le site se construit avec une allowlist de quatre fichiers publics. Héberger
uniquement le répertoire produit, jamais la racine du dépôt ou `.secrets`.
Sur GitHub Pages, utiliser le bundle comme artefact statique, avec les permissions
`pages:write` et `id-token:write` uniquement dans un job de publication autorisé.
Le site est publié sur [GitHub Pages](https://boualili-youcef.github.io/Asteria/),
avec `.github/workflows/demo-site.yml`. Une modification de `demo/web/` ou
`demo/evidence/` sur la branche de démo déclenche sa republication ; aucune
action n'est effectuée sur le cloud privé.
