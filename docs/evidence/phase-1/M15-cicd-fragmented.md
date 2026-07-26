# Preuve M15 — CI/CD hétérogène observable

## Métadonnées

- **Date :** 2026-07-26
- **Mission :** M15
- **Statut :** réussi
- **Révision validée :** `7590d17aec0366d769ea973b7a8ca770f22c7bd9`

## Objectif et résultat attendu

Reproduire une livraison partiellement industrialisée sans introduire de
golden path commune :

- Identity construit et publie une image sans exécuter de tests ni de scan ;
- Orders exécute ses tests, puis construit et publie une image sans SBOM ;
- Notifications reste une procédure opérateur hors runner.

Les exécutions, images et artefacts doivent être identifiables, tandis que les
écarts restent explicitement visibles.

## Dépendances et prérequis vérifiés

- M14 est terminée et les trois applications fonctionnent dans K3s ;
- le dépôt GitHub `Boualili-Youcef/Asteria` accepte les workflows Actions ;
- le `GITHUB_TOKEN` des jobs possède seulement `contents: read` et
  `packages: write` ;
- aucune donnée d'authentification GHCR n'est ajoutée au dépôt ;
- Docker local permet de reproduire le chemin manuel Notifications.

## Fichiers livrés

- `.github/workflows/identity-api.yml` ;
- `.github/workflows/orders-api.yml` ;
- `ci/current-state/notifications-worker-manual.sh` ;
- `ci/current-state/README.md`.

## Validation statique locale

Les deux workflows ont passé `actionlint` 1.7.12 sans diagnostic. Le script
manuel a passé l'analyse syntaxique Bash :

```bash
actionlint .github/workflows/identity-api.yml \
  .github/workflows/orders-api.yml
bash -n ci/current-state/notifications-worker-manual.sh
```

## Exécutions GitHub Actions observées

Les deux exécutions ont été déclenchées par le push de la révision validée.

| Service | Run | Job | Début UTC | Fin UTC | Résultat |
|---|---:|---|---|---|---|
| Identity | [30210326425](https://github.com/Boualili-Youcef/Asteria/actions/runs/30210326425) | `build-and-push` | 16:23:46 | 16:24:14 | succès |
| Orders | [30210326439](https://github.com/Boualili-Youcef/Asteria/actions/runs/30210326439) | `test-build-and-push` | 16:23:46 | 16:24:43 | succès |

Identity a exécuté le checkout, l'authentification GHCR, le build/push et
l'enregistrement de l'image. Aucune étape de test ou de scan n'existe dans ce
job.

Orders a installé ses dépendances, exécuté pytest, publié le rapport JUnit,
puis construit et publié son image. Le rapport observé contient :

```text
tests=5 failures=0 errors=0 skipped=0
```

## Images et artefacts identifiables

| Service | Référence observée | Artefact partiel |
|---|---|---|
| Identity | `ghcr.io/boualili-youcef/asteria/identity-api@sha256:e2711f37827ccec80ce757cd5dabf52dee2dd01150cca0b145ccade21b85234f` | `identity-image-30210326425` |
| Orders | `ghcr.io/boualili-youcef/asteria/orders-api@sha256:daca994f55a121879351aab07d9336adbed5b8dd66d8f0727573ba59b346fb06` | `orders-image-30210326439` |

Orders fournit également `orders-tests-30210326439`. Les trois artefacts ont
été téléchargés et relus ; aucun n'était expiré lors de la validation.

Les workflows publient aussi les tags de commodité `main` et SHA de commit.
Les digests ci-dessus constituent la référence immuable enregistrée, mais M15
ne met volontairement pas à jour les Deployments M14.

## Chemin manuel Notifications

Commande exécutée sans publication :

```bash
M15_NOTIFICATIONS_RECORD_FILE=/tmp/asteria-m15-notifications-image-final.txt \
  ./ci/current-state/notifications-worker-manual.sh \
  ghcr.io/boualili-youcef/asteria/notifications-worker:manual-7590d17
```

Résultat :

```text
image=ghcr.io/boualili-youcef/asteria/notifications-worker:manual-7590d17
image_id=sha256:3a4cc330c3dcfe3d15364f0d9449e75f3b3b2f98eda4d099a8e0d4994caeb4c8
revision=7590d17aec0366d769ea973b7a8ca770f22c7bd9
publication=built-locally
```

Le fichier de résultat reste dans `/tmp` et n'est pas versionné. Ce chemin ne
produit aucun historique central tant que l'opérateur ne demande pas
explicitement `--push`.

## Contrôle des secrets

- les workflows utilisent uniquement `secrets.GITHUB_TOKEN` fourni au job ;
- aucun token n'est présent dans les fichiers, artefacts ou sorties conservées ;
- le script manuel attend une authentification Docker externe via
  `--password-stdin` lorsqu'une publication est demandée ;
- aucun PAT, mot de passe, kubeconfig ou fichier `.secrets/` n'est versionné.

## Limites et dettes AS-IS conservées

- Identity publie sans tests ;
- Notifications reste hors runner et n'a pas été publiée pendant la validation ;
- aucun scan de vulnérabilités, SBOM, signature ou provenance ;
- les actions sont référencées par tags majeurs, pas par SHA immuable ;
- deux workflows spécifiques et une procédure manuelle ;
- artefacts partiels avec une rétention de sept jours ;
- aucun environnement, approbation, promotion ou rollback commun ;
- aucune mise à jour automatique des workloads K3s ;
- aucun contrôle homogène avant publication.

## Conclusion et prochaine mission

M15 est **Terminée**. Deux pipelines distincts ont publié des images
identifiables, Orders a produit un rapport de cinq tests réussis et le worker
dispose d'un chemin manuel reproductible. L'hétérogénéité et les lacunes de
sécurité restent observables.

M16 — auditer et documenter les problèmes AS-IS — est maintenant la seule
mission en cours.
