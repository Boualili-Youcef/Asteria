# Méthodes de déploiement et de livraison AS-IS

## 1. Objet et date du constat

Ce document décrit la chaîne réellement observée le **26 juillet 2026**, après
M15. Il ne propose pas de chaîne cible et ne transforme pas l'hétérogénéité
volontaire de la phase 1 en standard commun.

Une distinction est essentielle :

- M15 publie des images GHCR pour Identity et Orders ;
- les workloads M14 exécutent encore les images M13 importées manuellement
  dans containerd ;
- aucun pipeline ne déploie ou ne met à jour Kubernetes.

## 2. Vue de bout en bout

| Service | Contrôle CI | Image produite par M15 | Déploiement Kubernetes observé | Image exécutée |
|---|---|---|---|---|
| `identity-api` | build/push, sans tests ni scan | GHCR, tags SHA/`main` et digest | YAML brut transmis à `kubectl apply` | `docker.io/asteria/identity-api:m13` |
| `orders-api` | 5 tests, build/push, sans scan ni SBOM | GHCR, tags SHA/`main` et digest | release Helm `orders-api` | `docker.io/asteria/orders-api:m13` |
| `notifications-worker` | aucun workflow | build local, push manuel optionnel | `kubectl apply` opérateur | `docker.io/asteria/notifications-worker:m13` |

Les trois Deployments sont disponibles avec un replica chacun. Leurs labels
exposent respectivement `raw-yaml`, `helm` et `manual-kubectl`.

## 3. Identity : YAML brut et pipeline sans tests

### Livraison

`.github/workflows/identity-api.yml` se déclenche sur les changements Identity
de `main` ou manuellement. Il construit et pousse vers GHCR sans exécuter de
test, scan, SBOM ou provenance.

Le run `30210326425` a publié :

```text
ghcr.io/boualili-youcef/asteria/identity-api@sha256:e2711f37827ccec80ce757cd5dabf52dee2dd01150cca0b145ccade21b85234f
```

### Déploiement

Le manifest complet se trouve dans
`k8s/current-state/identity-api/identity-api.yaml`. L'opérateur le transmet
depuis le poste local au `kubectl` du bastion. Il n'existe ni release Helm, ni
historique de promotion, ni lien automatique avec le digest publié par M15.

## 4. Orders : pipeline testé et chart Helm spécifique

### Livraison

`.github/workflows/orders-api.yml` installe les dépendances figées, exécute
pytest, publie un rapport JUnit, puis construit et pousse l'image sans scan,
SBOM ou provenance.

Le run `30210326439` a produit cinq tests réussis et publié :

```text
ghcr.io/boualili-youcef/asteria/orders-api@sha256:daca994f55a121879351aab07d9336adbed5b8dd66d8f0727573ba59b346fb06
```

### Déploiement

Le chart interne se trouve dans `k8s/current-state/orders-api/chart/`.
L'opérateur le copie temporairement sur le bastion et lance
`helm upgrade --install`. La release observée est `orders-api`, mais ses valeurs
référencent toujours l'image M13 locale.

## 5. Notifications : hors runner

`ci/current-state/notifications-worker-manual.sh` construit une image locale et
ne la pousse que si l'opérateur demande explicitement `--push`.

La validation M15 a construit, sans publication :

```text
ghcr.io/boualili-youcef/asteria/notifications-worker:manual-7590d17
```

Le Deployment reste une application manuelle du manifest
`k8s/current-state/notifications-worker/notifications-worker.yaml`. Aucun
Ingress n'expose le worker.

## 6. Configuration et secrets d'exécution

La configuration non sensible est créée dans des ConfigMaps à partir des
outputs Terraform et des noms de Services Kubernetes. Les mots de passe
PostgreSQL sont lus depuis `.secrets/m08-postgres/`, répertoire local ignoré,
puis transmis à l'entrée standard de `kubectl`.

Les Secrets Kubernetes observés sont :

```text
team-identity/identity-postgres
team-orders/orders-postgres
team-notifications/notifications-postgres
```

Il n'existe pas de gestionnaire centralisé, de rotation automatique ou de
promotion de configuration entre environnements. Les valeurs sensibles ne sont
cependant ni placées dans Git, ni embarquées dans les images.

## 7. Responsabilité opérationnelle réelle

| Étape | Mécanisme | Intervention humaine |
|---|---|---|
| Commit applicatif | GitHub | développeur |
| Build Identity/Orders | GitHub Actions | automatique après push ciblé |
| Build Notifications | Docker local | obligatoire |
| Publication Identity/Orders | GHCR | automatique |
| Publication Notifications | Docker local | optionnelle |
| Import des images M13 dans K3s | Docker, SSH, containerd | obligatoire sur chaque nœud |
| Création ConfigMaps/Secrets | script local + `kubectl` | obligatoire |
| Déploiement des trois services | YAML, Helm, `kubectl` manuel | obligatoire |
| Validation fonctionnelle | script depuis le bastion | déclenchée par l'opérateur |

Cette chaîne dépend fortement de l'équipe Platform et du poste qui possède le
dépôt, le state Terraform, la clé SSH et les secrets M08.

## 8. Contrôles reproduits

```bash
# Statique
actionlint .github/workflows/identity-api.yml \
  .github/workflows/orders-api.yml
bash -n ci/current-state/notifications-worker-manual.sh

# Runtime, à lancer depuis le bastion
kubectl get deployments -A
helm --namespace team-orders status orders-api
kubectl get ingress -A
```

Le détail des commandes de déploiement reste dans
`k8s/current-state/README.md`, et celui de la livraison dans
`ci/current-state/README.md`.

## 9. Dettes observées, sans correction en phase 1

- trois parcours de livraison et trois méthodes de déploiement ;
- aucune golden path, aucun GitOps et aucune promotion d'environnement ;
- publication CI décorrélée des images réellement exécutées ;
- images applicatives runtime importées sur chaque nœud, taguées mais non
  épinglées par digest dans les manifests ;
- Identity publié sans tests et Notifications hors runner ;
- aucune analyse de vulnérabilités, SBOM, signature ou provenance ;
- actions GitHub référencées par tags majeurs, pas par SHA immuable ;
- secrets et déploiements appliqués avec des droits administratifs depuis le
  bastion ;
- aucun mécanisme commun de rollback, détection de dérive ou journal de
  promotion.

## 10. Preuves

- [M13 — applications construites localement](../evidence/phase-1/M13-applications-built-locally.md) ;
- [M14 — déploiements hétérogènes](../evidence/phase-1/M14-heterogeneous-deployments.md) ;
- [M15 — CI/CD fragmenté](../evidence/phase-1/M15-cicd-fragmented.md) ;
- [M16 — audit final](../evidence/phase-1/M16-as-is-audit-complete.md).
