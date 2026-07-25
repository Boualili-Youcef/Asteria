# Preuve M14 — Déploiements hétérogènes fonctionnels

## Métadonnées

- **Date :** 2026-07-26
- **Mission :** M14
- **Statut :** réussi

## Objectif et résultat attendu

Déployer les trois applications M13 dans K3s en matérialisant l'absence de
golden path : YAML brut pour Identity, chart Helm propre à Orders et commande
`kubectl apply` manuelle pour Notifications.

Les APIs doivent répondre par ingress-nginx, le worker doit rester interne et
le flux fonctionnel doit traverser PostgreSQL et Redis.

## Dépendances et prérequis vérifiés

- M12 et M13 sont terminées ;
- les trois nœuds K3s sont accessibles et `Ready` ;
- les namespaces M10 existent ;
- PostgreSQL M08, Redis M11, Prometheus et Grafana M12 sont disponibles ;
- les trois images M13 existent localement avec l'utilisateur
  `10001:10001` ;
- les mots de passe M08 restent sous `.secrets/m08-postgres/`, hors Git.

## Décisions AS-IS

M14 précède le CI/CD et le registre M15. Les trois images locales ont donc été
importées manuellement dans containerd sur le control plane et les deux
workers. Les manifests utilisent `imagePullPolicy: IfNotPresent`.

La configuration d'exécution est séparée :

- ConfigMaps créées à partir des outputs Terraform et des noms de services ;
- Secrets créés depuis les fichiers M08 par l'entrée standard de `kubectl` ;
- aucune valeur sensible dans Git, dans les manifests ou dans les arguments de
  processus.

## Fichiers livrés

- `k8s/current-state/README.md` ;
- `k8s/current-state/identity-api/identity-api.yaml` ;
- `k8s/current-state/identity-api/README.md` ;
- `k8s/current-state/orders-api/chart/` ;
- `k8s/current-state/orders-api/README.md` ;
- `k8s/current-state/notifications-worker/notifications-worker.yaml` ;
- `k8s/current-state/notifications-worker/README.md` ;
- `k8s/current-state/scripts/m14-import-local-images.sh` ;
- `k8s/current-state/scripts/m14-configure-runtime.sh` ;
- `k8s/current-state/scripts/m14-validate-applications.sh`.

## Commandes exécutées

```bash
export ASTERIA_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/tp_cloud"

./k8s/current-state/scripts/m14-import-local-images.sh
./k8s/current-state/scripts/m14-configure-runtime.sh

# Identity : YAML brut transmis à kubectl apply
# Orders : helm upgrade --install depuis le chart interne
# Notifications : manifest transmis manuellement à kubectl apply
```

Avant application, les trois rendus ont été acceptés par :

```text
kubectl apply --dry-run=server --filename=-
```

Le chart Orders a également passé `helm lint` et `helm template`.

## Méthodes observées

| Application | Namespace | Méthode enregistrée | État |
|---|---|---|---|
| `identity-api` | `team-identity` | `raw-yaml` | `1/1 Available` |
| `orders-api` | `team-orders` | `helm` | `1/1 Available` |
| `notifications-worker` | `team-notifications` | `manual-kubectl` | `1/1 Available` |

La release Helm observée est `orders-api`, chart `orders-api-0.1.0`, révision
1 et statut `deployed`. Aucun Ingress n'existe dans `team-notifications`.

## Images réellement exécutées

| Application | Nœud observé | Image ID containerd |
|---|---|---|
| Identity | `k8s-worker-02` | `sha256:e64dbf1ea15e6ce3ca8e0cbdefecd534a6adf729278e0abd4ed32eef60209b07` |
| Orders | `k8s-worker-01` | `sha256:c7d6c8648cd32868b6f84276829d47bb83cccb7898c4097b131c015767c579d3` |
| Notifications | `k8s-worker-02` | `sha256:adda677a5cd48ae49d3a4c17f765c83a344d9844dedb79dfe6e23c3741fcd80a` |

Les trois images ont été contrôlées sur chaque nœud après leur import manuel.

## Validation fonctionnelle

Le script M14 a :

1. attendu les trois Deployments ;
2. vérifié les labels des trois méthodes ;
3. créé un utilisateur via Identity ;
4. créé une commande via Orders ;
5. observé la consommation et l'archivage par Notifications ;
6. vérifié santé, disponibilité et métriques ;
7. testé les deux APIs via les NodePorts des deux workers.

Résultat :

```text
Identity create/readiness passed
Orders PostgreSQL/Redis flow passed
Notifications worker consumed and archived an event
Ingress routes passed through 172.28.100.32
Ingress routes passed through 172.28.100.9
M14 heterogeneous application checks passed
```

Les IP ci-dessus sont des résultats observés le 26 juillet ; les procédures
dérivent toujours leurs valeurs courantes depuis Terraform.

Prometheus a ensuite observé huit targets `UP` : les cinq targets M12 et les
trois Services applicatifs annotés.

## Contrôle des secrets

Seuls les noms suivants ont été enregistrés dans la preuve :

```text
secret/identity-postgres
secret/orders-postgres
secret/notifications-postgres
```

Leurs valeurs n'ont été ni affichées, ni copiées dans les manifests, ni
ajoutées à Git.

## Écart supplémentaire observé

Les cinq VM présentaient environ sept minutes de retard sur le poste local lors
du contrôle du 26 juillet 2026. L'installation Helm a ainsi signalé des fichiers
datés dans le futur. Aucun déploiement n'a échoué, mais cette dérive peut
affecter la corrélation des logs, les certificats et les pipelines. Elle est
conservée comme constat M16, pas corrigée silencieusement dans M14.

## Limites et dettes visibles

- images importées manuellement sur chaque nœud avant M15 ;
- tags d'images lisibles mais non épinglés par digest dans les manifests ;
- trois outils et procédures de déploiement ;
- aucun rollback ou historique commun ;
- secrets Kubernetes créés manuellement, sans gestionnaire centralisé ;
- un seul replica par service ;
- aucune NetworkPolicy applicative ;
- schémas PostgreSQL créés au premier besoin, sans migration versionnée ;
- aucun GitOps et aucune promotion d'environnement.

## Conclusion et prochaine mission

M14 est **Terminée**. Les trois workloads, les routes privées, PostgreSQL,
Redis, le worker et les métriques fonctionnent, tout en exposant clairement les
différences de déploiement.

M15 — mettre en place le CI/CD hétérogène — est maintenant la seule mission en
cours.
