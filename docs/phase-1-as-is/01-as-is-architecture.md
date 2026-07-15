# Architecture AS-IS de référence

## 1. Objet et statut

Ce document explique l'architecture AS-IS que la phase 1 doit reconstruire. Il
ne décrit pas une architecture cible et ne constitue pas une recommandation de
production.

Le diagramme figé se trouve dans
`docs/diagrams/as-is-architecture.mmd`. Son contenu est extrait sans
modification du bloc Mermaid de `archi.md`, source validée au démarrage du
projet.

## 2. Deux niveaux à ne pas confondre

### 2.1 Référence d'entreprise simulée

La référence représente une PME SaaS européenne de 100 à 500 employés utilisant
un cloud OpenStack privé. Une implémentation réelle disposerait de plusieurs
environnements, davantage d'applications, plus de ressources et, selon les
besoins, de mécanismes de haute disponibilité absents du lab.

Elle comprend quatre groupes d'acteurs :

- clients B2B et utilisateurs ;
- équipes de développement ;
- équipe Platform/DevOps ;
- équipe Sécurité/Audit.

Elle dépend également de services externes ou partagés : DNS, dépôts Git,
runners CI, registre de conteneurs, stockage objet et stockage d'artefacts.

### 2.2 Implémentation réduite du lab

Le lab matérialise les composants et les flux principaux sous une contrainte
maximale actuellement documentée de 8 instances, 10 vCPU et 20 Go de RAM.

La baseline du diagramme consomme 5 instances, 9 vCPU et 17 Go :

| Composant | Rôle | Taille |
|---|---|---:|
| Bastion | Point d'administration | 1 vCPU / 1 Go |
| Control plane Kubernetes | Pilotage du cluster, non HA | 2 vCPU / 4 Go |
| Worker 1 | Exécution des workloads | 2 vCPU / 4 Go |
| Worker 2 | Exécution des workloads | 2 vCPU / 4 Go |
| PostgreSQL | Base primaire hors cluster, non HA | 2 vCPU / 4 Go |

Le lab ne prétend donc pas reproduire la capacité ou la résilience d'une
production réelle. Il en reproduit les responsabilités, les frontières et les
dettes utiles à la mission.

## 3. Composants OpenStack

### 3.1 Réseau externe et routeur

Le réseau externe représente la connectivité fournie par le cloud. Le routeur
OpenStack relie les réseaux privés au chemin d'entrée et, selon les capacités du
tenant, à l'extérieur.

Leur existence logique dans le diagramme ne prouve pas encore leur nom ni leur
disponibilité réelle. Ces éléments sont vérifiés pendant M03.

### 3.2 Segmentation réseau

Quatre zones logiques sont représentées :

- **DMZ / public-services-net** : porte le point d'entrée public ;
- **management network** : contient le bastion ;
- **application network** : contient les nœuds Kubernetes ;
- **data network** : contient PostgreSQL.

Les security groups jouent le rôle de pare-feu logique. La segmentation existe,
mais sa gouvernance reste volontairement incomplète dans l'AS-IS.

### 3.3 Point d'entrée

Le modèle prévoit une Floating IP HTTPS vers l'Ingress. Octavia est utilisé si
le service est disponible ; sinon, le lab utilise un chemin NodePort adapté.
Cette alternative appartient déjà à l'AS-IS validé et ne constitue pas une
modernisation.

### 3.4 Bastion

Le bastion est à la fois point d'accès administratif et poste d'administration.
Il porte Terraform, Ansible, OpenStack CLI, kubectl et le client PostgreSQL.
L'équipe Platform/DevOps et l'équipe Sécurité/Audit l'atteignent depuis le VPN
ou réseau d'entreprise simulé.

### 3.5 PostgreSQL

PostgreSQL fonctionne sur une VM séparée dans le réseau de données. Il s'agit
d'un primaire unique sans réplication ni haute disponibilité. Les trois
workloads applicatifs y accèdent.

## 4. Composants Kubernetes

### 4.1 Cluster

Le cluster prod-like réduit possède un seul control plane et deux workers.
L'absence de haute disponibilité du control plane est une limite connue et
volontaire de l'AS-IS.

### 4.2 Ingress

NGINX Ingress Controller s'exécute dans `ingress-nginx`. Il reçoit le trafic
entrant et route les requêtes publiques vers `identity-api` et `orders-api`.
Le worker de notifications ne possède pas de route publique.

### 4.3 Services applicatifs

| Namespace | Workload | Dépendances | Mode de déploiement |
|---|---|---|---|
| `team-identity` | `identity-api` | PostgreSQL | YAML brut |
| `team-orders` | `orders-api` | PostgreSQL et Redis | Chart Helm interne |
| `team-notifications` | `notifications-worker` | PostgreSQL et Redis | `kubectl apply` manuel |

Ces différences de livraison sont intentionnelles : elles matérialisent
l'absence de golden path.

### 4.4 Donnée partagée

Redis est déployé dans l'espace partagé `shared/data-in-cluster`. Il est utilisé
par les commandes et les notifications. Son isolation faible est une dette
AS-IS, pas une erreur à corriger pendant la reconstruction.

### 4.5 Observabilité

Le namespace `monitoring` contient :

- Prometheus avec une collecte partielle ;
- Grafana avec des dashboards manuels ;
- une représentation des logs non centralisés.

Les équipes utilisent fréquemment `kubectl logs`. L'architecture ne fournit ni
SLO, ni alerting homogène, ni plateforme complète de centralisation des logs.

## 5. Services externes et partagés

| Service | Utilisation dans l'AS-IS |
|---|---|
| DNS public | Résolution du point d'entrée client |
| Dépôts Git | Sources applicatives et configurations |
| Runners CI | Exécution de pipelines externes ou partagés peu standardisés |
| Registre | Stockage des images ; GHCR ou registre conteneurisé dans le lab |
| Artefacts CI/CD | Rapports et packages partiels, SBOM non systématique |
| Stockage objet | Sauvegardes PostgreSQL irrégulières |

Le stockage objet réel pourrait être S3, Azure Blob ou Swift. MinIO ou une
solution gratuite peut le représenter dans le lab. Le choix concret n'est pas
encore arrêté.

## 6. Inventaire des flux

### 6.1 Flux utilisateurs

`Clients B2B → DNS public → réseau externe OpenStack → routeur → security
groups → Floating IP / point d'entrée → NGINX Ingress → API`

L'Ingress route vers :

- `identity-api` ;
- `orders-api`.

Ce flux est le seul chemin public fonctionnel représenté pour les applications.

### 6.2 Flux applicatifs et de données

| Source | Destination | Objet |
|---|---|---|
| `identity-api` | PostgreSQL | Données d'identité |
| `orders-api` | PostgreSQL | Données de commandes |
| `orders-api` | Redis partagé | Données temporaires ou échanges |
| `notifications-worker` | PostgreSQL | Données persistantes nécessaires |
| `notifications-worker` | Redis partagé | Traitement asynchrone partagé |

Les ports précis et les règles source/destination ne sont pas inventés ici. Ils
seront formalisés pendant le design réseau M04.

### 6.3 Flux de livraison

1. Les développeurs poussent le code vers les dépôts Git.
2. Des runners CI externes ou partagés exécutent les pipelines.
3. `identity-api` suit un pipeline build/push sans scan.
4. `orders-api` suit un pipeline tests/build/push sans SBOM.
5. `notifications-worker` suit un build et un déploiement manuels.
6. Les images sont publiées dans le registre.
7. Le control plane et les workers récupèrent les images nécessaires.
8. Les pipelines produisent seulement des artefacts partiels.

### 6.4 Flux d'administration

`Équipe Platform/DevOps ou Sécurité/Audit → VPN / réseau d'entreprise →
bastion → control plane, workers ou PostgreSQL`

Le diagramme n'autorise pas d'administration directe depuis Internet. Les règles
détaillées seront définies après inventaire du cloud.

### 6.5 Flux de sécurité et d'audit

- l'équipe Sécurité/Audit inspecte manuellement les dépôts Git ;
- elle inspecte manuellement le registre ;
- elle passe par le bastion pour revoir manifests et RBAC sur Kubernetes.

Ces contrôles sont ponctuels et ne constituent pas une policy-as-code homogène.

### 6.6 Flux d'observabilité

- les trois workloads publient des métriques complètes ou partielles vers
  Prometheus ;
- control plane et workers publient leurs métriques de nœud ou de contrôle ;
- Prometheus alimente Grafana ;
- les logs applicatifs sont principalement consultés manuellement.

La flèche vers Prometheus indique une intention de collecte, pas une couverture
complète garantie.

### 6.7 Flux de sauvegarde

`PostgreSQL → stockage objet`

Les sauvegardes sont irrégulières et aucune restauration testée n'est démontrée
en phase 1.

## 7. Dettes et limites figées

| Dette ou limite | Manifestation dans l'architecture |
|---|---|
| CI/CD hétérogène | Pipelines et déploiement manuel différents |
| Absence de golden path | Trois méthodes de livraison |
| Absence de GitOps commun | Déploiements directs possibles |
| Sécurité Kubernetes incomplète | RBAC partiel, peu de NetworkPolicies, aucune policy-as-code |
| Observabilité partielle | Pas de SLO ni alerting homogène, logs non centralisés |
| Reprise non démontrée | Sauvegardes présentes, restauration non testée |
| Haute disponibilité absente | Control plane et PostgreSQL uniques |
| Limite du lab | 5 instances, 9 vCPU et 17 Go pour la baseline |

Ces points doivent rester visibles jusqu'à l'audit M16. Les décrire ne signifie
pas les corriger pendant la phase 1.

## 8. Points reportés aux missions suivantes

Ce document ne fixe pas :

- les noms réels de flavors et d'images OpenStack ;
- le réseau externe réellement accessible ;
- la disponibilité effective des Floating IP et d'Octavia ;
- les CIDR et ports détaillés ;
- les implémentations Terraform, Ansible ou Kubernetes.

M03 remplace les hypothèses OpenStack par un inventaire. M04 utilisera cet
inventaire pour concevoir les réseaux et les security groups.
