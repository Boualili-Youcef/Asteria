# CI/CD hétérogène AS-IS — M15

## But

M15 reproduit une livraison partiellement industrialisée, sans créer une
golden path commune.

| Service | Déclenchement | Tests | Build/push | Artefact | Lacunes volontaires |
|---|---|---:|---:|---|---|
| Identity | push `main` ciblé ou manuel | non | GHCR | référence image | aucun test ni scan |
| Orders | push `main` ciblé ou manuel | oui | GHCR | JUnit + référence image | aucun scan ni SBOM |
| Notifications | opérateur local | non | option manuelle | fichier local | aucun runner ni historique central |

Les deux workflows GitHub utilisent le `GITHUB_TOKEN` limité au dépôt avec
`packages: write`. Aucun PAT n'est stocké dans Git.

## Identity

Workflow : `.github/workflows/identity-api.yml`.

Il construit et pousse :

```text
ghcr.io/<owner>/<repository>/identity-api:<commit-sha>
ghcr.io/<owner>/<repository>/identity-api:main
```

Il ne lance volontairement aucun test, scan ou SBOM. Son unique artefact
conservé sept jours contient la référence immuable image + digest.

## Orders

Workflow : `.github/workflows/orders-api.yml`.

Il installe les dépendances figées, exécute pytest, publie un rapport JUnit,
puis construit et pousse :

```text
ghcr.io/<owner>/<repository>/orders-api:<commit-sha>
ghcr.io/<owner>/<repository>/orders-api:main
```

Le build désactive explicitement le SBOM et ne lance aucun scanner.

## Notifications

Le worker reste hors runner avec `notifications-worker-manual.sh`.

Construction locale identifiable, sans push :

```bash
image_ref="ghcr.io/boualili-youcef/asteria/notifications-worker:manual-$(git rev-parse --short HEAD)"
./ci/current-state/notifications-worker-manual.sh "${image_ref}"
```

Pour un push manuel, l'opérateur doit d'abord s'authentifier sans placer le
token dans l'historique du shell :

```bash
printf '%s' "$GHCR_TOKEN" |
  docker login ghcr.io --username "$GHCR_USERNAME" --password-stdin

./ci/current-state/notifications-worker-manual.sh "${image_ref}" --push
docker logout ghcr.io
```

`GHCR_TOKEN` et `GHCR_USERNAME` doivent provenir de l'environnement local et ne
doivent jamais être ajoutés au dépôt.

## Validation

Validation statique locale :

```bash
actionlint
bash -n ci/current-state/notifications-worker-manual.sh
```

Validation observable après push :

1. les deux runs GitHub Actions sont terminés avec succès ;
2. les jobs et étapes attendus sont visibles ;
3. les artefacts partiels existent ;
4. les deux images GHCR sont identifiables par SHA et digest ;
5. le build manuel Notifications produit une image et un enregistrement local.

## Dettes AS-IS conservées

- deux workflows spécifiques et un chemin hors CI ;
- aucun scan de vulnérabilités ;
- aucun SBOM ;
- actions tierces référencées par tags majeurs plutôt que par SHA immuable ;
- aucune signature d'image ni provenance ;
- aucune promotion entre environnements ;
- aucune mise à jour automatique des Deployments M14 ;
- rétention courte et artefacts incomplets ;
- aucun contrôle homogène avant publication.
