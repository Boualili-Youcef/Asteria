# Preuve M16 — Audit AS-IS complet

## Métadonnées

- **Date :** 2026-07-26
- **Mission :** M16
- **Statut :** réussi
- **Périmètre :** clôture de la phase 1, sans implémentation TO-BE

## Objectif et résultat attendu

Produire un état factuel et vérifiable de la plateforme après M15 :

1. décrire les méthodes de livraison et de déploiement réellement utilisées ;
2. décrire la couverture d'observabilité réellement disponible ;
3. qualifier chaque problème connu par impact et preuve ;
4. séparer strictement les constats AS-IS des recommandations futures.

## Dépendances et prérequis vérifiés

- M00 à M15 sont documentées comme terminées ;
- les cinq VM répondent à Ansible ;
- le bastion possède le kubeconfig protégé et joint l'API K3s ;
- les deux workflows M15 sont terminés avec succès ;
- aucun apply Terraform ou changement d'infrastructure n'est requis par M16.

Les quotas et capacités OpenStack restent ceux inventoriés dans M03 à M06. Ils
n'ont pas été présentés comme une nouvelle mesure du tenant pendant M16.

## Fichiers livrés

- `docs/phase-1-as-is/06-deployment-methods.md` ;
- `docs/phase-1-as-is/07-observability-as-is.md` ;
- `docs/phase-1-as-is/08-as-is-known-issues.md`.

Les sources de vérité suivantes ont aussi été alignées sur les faits M15/M16 :

- `PROJECT_CONTEXT.md` ;
- `archi.md` ;
- `docs/diagrams/as-is-architecture.mmd` ;
- `docs/phase-1-as-is/01-as-is-architecture.md`.

## Commandes d'audit exécutées

### Accessibilité et temps

```bash
.venv/bin/ansible all \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping

.venv/bin/ansible all \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.command \
  -a 'timedatectl show --property=NTPSynchronized --property=NTP'
```

### Kubernetes

Depuis le bastion :

```bash
kubectl get nodes
kubectl get deployments -A
kubectl get daemonsets -A
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get networkpolicies -A
kubectl get ingress -A
kubectl get pvc -A
kubectl -n ingress-nginx get service ingress-nginx-controller
```

### Prometheus et Grafana

```bash
/home/ubuntu/.local/bin/asteria-m12-validate-monitoring busybox:1.37.0

kubectl -n monitoring port-forward \
  --address=127.0.0.1 service/prometheus 19090:9090
curl --fail --silent http://127.0.0.1:19090/api/v1/targets
curl --fail --silent http://127.0.0.1:19090/api/v1/rules
```

Le port-forward a été ouvert uniquement sur la boucle locale du bastion et
arrêté à la fin du contrôle.

### PostgreSQL, Redis et datastore K3s

```bash
systemctl is-active postgresql
sudo -u postgres psql --no-psqlrc --tuples-only --no-align \
  --command 'select pg_is_in_recovery()'
sudo -u postgres psql --no-psqlrc --tuples-only --no-align \
  --command 'select count(*) from pg_stat_replication'

kubectl -n shared exec deployment/redis-shared -- redis-cli ping
kubectl -n shared exec deployment/redis-shared -- redis-cli --raw \
  ACL GETUSER default
kubectl -n shared exec deployment/redis-shared -- redis-cli --raw \
  INFO replication
```

L'arborescence de sauvegarde PostgreSQL et le répertoire de snapshots K3s ont
été inventoriés par nom seulement ; aucun dump, mot de passe ou token n'a été
lu.

## Résultats runtime observés

### Infrastructure et temps

- cinq réponses Ansible `pong` ;
- PostgreSQL `active`, K3s `active` ;
- poste local à `18:30:54+02:00` et cinq VM à
  `18:23:45/46+02:00` pendant la même capture ;
- `NTP=yes`, mais `NTPSynchronized=no` sur les cinq VM.

La dérive commune est donc d'environ sept minutes. Elle est enregistrée comme
problème AS-IS, pas corrigée silencieusement.

### Kubernetes et exposition

| Contrôle | Résultat |
|---|---|
| Nœuds | 3/3 `Ready`, K3s `v1.36.2+k3s1` |
| Deployments | tous les replicas demandés disponibles |
| node-exporter | 3/3 prêts |
| Pods hors `Running`/`Succeeded` | aucun |
| NetworkPolicies | zéro |
| Ingress controller | 2/2 disponibles |
| Service Ingress | `NodePort`, 30080/30443, aucune IP externe |
| Redis PVC | `Bound`, 1 Gi, `local-path` |

Les méthodes et images applicatives observées sont :

| Workload | Méthode | Replica | Image runtime |
|---|---|---:|---|
| `identity-api` | `raw-yaml` | 1/1 | `docker.io/asteria/identity-api:m13` |
| `orders-api` | `helm` | 1/1 | `docker.io/asteria/orders-api:m13` |
| `notifications-worker` | `manual-kubectl` | 1/1 | `docker.io/asteria/notifications-worker:m13` |

Cette capture confirme que les images GHCR M15 existent, mais ne sont pas
encore les images exécutées par les Deployments M14.

### Données et reprise

PostgreSQL retourne :

```text
POSTGRES_VERSION=16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
IN_RECOVERY=f
REPLICATION_CLIENTS=0
ASTERIA_BACKUP_TIMERS=0
```

Une seule arborescence de sauvegarde, datée du 19 juillet, contient les globals,
les trois dumps et `SHA256SUMS`. Aucune restauration n'a été exécutée.

Le control plane utilise le fichier SQLite K3s local et le nombre de fichiers
observés sous le répertoire de snapshots est zéro.

Redis retourne :

```text
PONG
flags: on, nopass
commands: +@all
role:master
connected_slaves:0
```

### Observabilité

Le test synthétique retourne :

```text
Prometheus targets up: 8
Grafana dashboard visible: Asteria AS-IS Nodes
M12 monitoring checks passed
```

Les huit targets sont Prometheus, CoreDNS, trois node-exporters et les trois
applications. L'API des règles retourne :

```text
RULE_GROUPS=0
```

Aucun Alertmanager ni composant de centralisation des logs ou de traces n'est
présent.

## Contradictions documentaires résolues

Avant M16, la documentation disait encore que le registre du lab serait « GHCR
ou un registre conteneurisé » et que les nœuds téléchargeraient les images
depuis ce registre.

M15 a tranché le premier point et M16 a observé le second :

- GHCR est utilisé par les deux workflows ;
- les images M15 publiées ne sont pas consommées par les workloads M14 ;
- Notifications reste construit et déployé manuellement ;
- le stockage objet de sauvegarde appartient à la référence entreprise et
  n'est pas déployé dans le lab.

`PROJECT_CONTEXT.md`, `archi.md`, son source Mermaid et le document
d'architecture ont été corrigés sans modifier le runtime.

## Registre des problèmes et recommandations

`docs/phase-1-as-is/08-as-is-known-issues.md` contient :

- 22 constats numérotés `ASIS-001` à `ASIS-022` ;
- un niveau d'impact pour chaque constat ;
- au moins une preuve liée pour chaque constat ;
- les contrôles positifs existants ;
- une section TO-BE séparée, explicitement non approuvée et non implémentée.

Les recommandations ne sont donc pas présentées comme des livrables de phase 1.

## Validation documentaire

Les liens Markdown locaux des quatre documents M16 ont été résolus depuis leur
répertoire respectif. Les contrôles ont ensuite confirmé :

```text
issue_rows=22
issue_ids=ASIS-001 ... ASIS-022
broken_links=0
git diff --check: success
```

Le source `docs/diagrams/as-is-architecture.mmd` a aussi été rendu sans erreur
par le moteur Mermaid. Le bloc de `archi.md` et ce source sont identiques.

## Contrôle des secrets

- aucune valeur de Secret Kubernetes n'a été lue ;
- les dumps PostgreSQL ont été inventoriés par nom uniquement ;
- aucun kubeconfig, token GitHub, mot de passe ou fichier OpenStack n'est
  enregistré dans cette preuve ;
- les adresses de VM sont volontairement absentes de l'audit.

## Critères d'acceptation

- trois livrables M16 présents ;
- état live des cinq VM, de K3s, PostgreSQL, Redis et monitoring relevé ;
- méthodes de déploiement et images runtime différenciées des artefacts CI ;
- chaque problème associé à un impact et une preuve ;
- recommandations TO-BE isolées dans leur propre section ;
- contradictions de documentation corrigées ;
- liens locaux et diagramme Mermaid validés ;
- aucune ressource d'infrastructure ou correction de phase 2 appliquée.

## Conclusion

M16 est **Terminée**. L'AS-IS est fonctionnel dans les limites du lab, et ses
dettes de disponibilité, sécurité, données, livraison, observabilité et
exploitation sont observables et reliées aux preuves M00 à M16.

La phase 1 peut être clôturée. La phase 2 ne commence qu'après approbation
explicite de sa portée et de ses priorités.
