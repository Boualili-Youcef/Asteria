# Architecture AS-IS de référence

## 1. Objet et statut

Ce document explique l'architecture AS-IS que la phase 1 reconstruit. Il ne
décrit pas une architecture cible.

Le diagramme courant est `docs/diagrams/as-is-architecture.mmd`, synchronisé
avec `archi.md`. Le PDF racine représente la conception initiale et reste un
artefact historique depuis la décision ADR-001.

## 2. Deux niveaux d'architecture

### 2.1 Référence d'entreprise

La PME SaaS de référence utilise OpenStack privé et disposerait réellement de
zones DMZ, management, application et data segmentées, d'un chemin HTTPS public
et de plusieurs environnements.

Cette référence reste utile pour expliquer les frontières souhaitées et mesurer
l'écart du lab. Elle n'est pas présentée comme déployée.

### 2.2 Implémentation réelle du lab

Le tenant universitaire fournit un seul réseau provider partagé, `prive`
(`172.28.0.0/16`), mais pas les fonctions nécessaires aux réseaux self-service,
routeurs L3, Floating IP ou Octavia.

Le lab utilise donc :

- un underlay OpenStack plat et partagé ;
- cinq ports Neutron précréés avec Terraform ;
- cinq security groups pour matérialiser les zones de confiance ;
- un overlay K3s Flannel VXLAN pour le trafic Pods ;
- les Services Kubernetes pour la découverte interne ;
- des NodePorts accessibles seulement depuis le bastion pour valider l'Ingress.

Cette adaptation est formalisée dans
`docs/adr/ADR-001-provider-network-fallback.md`.

## 3. Empreinte du lab

| Machine | Rôle | Taille | Port et frontières |
|---|---|---:|---|
| `bastion-admin-01` | Administration | 1 vCPU / 1 Go | Port sur `prive`, SG bastion |
| `k8s-control-plane-01` | Control plane non HA | 2 vCPU / 4 Go | Port sur `prive`, SG control-plane |
| `k8s-worker-01` | Workloads | 2 vCPU / 4 Go | Port sur `prive`, SG workers + ingress |
| `k8s-worker-02` | Workloads | 2 vCPU / 4 Go | Port sur `prive`, SG workers + ingress |
| `db-postgres-01` | PostgreSQL primaire | 2 vCPU / 4 Go | Port sur `prive`, SG postgres |

Total : 5 instances, 9 vCPU et 17 Go de RAM. Le control plane et PostgreSQL
restent volontairement non HA.

## 4. Frontières logiques

### 4.1 Management

Le bastion est l'unique point SSH depuis un CIDR administrateur strict. Il porte
Terraform, Ansible, OpenStack CLI, kubectl et le client PostgreSQL.

Les autres VMs acceptent SSH uniquement depuis le port portant le SG bastion.

### 4.2 Application

Le control plane et les workers partagent l'underlay mais possèdent des SG
distincts. Les règles autorisent seulement :

- API Kubernetes 6443/TCP ;
- kubelet 10250/TCP ;
- Flannel VXLAN 8472/UDP ;
- SSH depuis le bastion.

Les Pods utilisent `10.42.0.0/16` et les Services `10.43.0.0/16`.

### 4.3 Ingress

Les workers portent également le SG ingress. Les NodePorts 30080/TCP et
30443/TCP n'acceptent que le SG bastion.

Le flux public B2B de la référence entreprise n'est pas reproduit. Les tests se
font depuis le bastion ou avec un tunnel SSH.

### 4.4 Data

PostgreSQL accepte :

- SSH depuis le bastion ;
- 5432/TCP depuis les workers.

Le control plane et les sources externes ne disposent pas d'un accès direct à
la base.

## 5. Composants Kubernetes

| Namespace | Workload | Dépendances | Déploiement |
|---|---|---|---|
| `team-identity` | `identity-api` | PostgreSQL | YAML brut |
| `team-orders` | `orders-api` | PostgreSQL et Redis | Helm interne |
| `team-notifications` | `notifications-worker` | PostgreSQL et Redis | `kubectl apply` manuel |
| `shared` | Redis | Orders et notifications | Composant partagé |
| `monitoring` | Prometheus/Grafana | Métriques partielles | Dashboards manuels |
| `ingress-nginx` | NGINX Ingress | APIs publiques | NodePort privé |

Les NetworkPolicies restent peu nombreuses en phase 1. Cette dette ne doit pas
être masquée par une modernisation prématurée.

## 6. Services externes

| Service | Rôle |
|---|---|
| DNS public | Référence du flux entreprise, non raccordé publiquement au lab |
| Dépôts Git | Sources applicatives et infra |
| Runners CI | GitHub Actions pour Identity et Orders |
| Registre | GHCR pour les images M15 Identity et Orders |
| Artefacts CI | Rapports et packages partiels |
| Stockage objet | Référence entreprise, non déployée dans le lab |

## 7. Inventaire des flux

### 7.1 Utilisateur

Référence entreprise :

`Client B2B → DNS → entrée HTTPS → Ingress → identity/orders`

Lab réellement démontrable :

`Opérateur → bastion → NodePort worker → Ingress → identity/orders`

### 7.2 Administration

`Équipe Platform/Sécurité → réseau entreprise ou VPN → bastion → nœuds/DB`

Aucun SSH direct vers Kubernetes ou PostgreSQL n'est autorisé depuis une source
administrateur externe.

### 7.3 Kubernetes

| Source | Destination | Port | Rôle |
|---|---|---:|---|
| Bastion | Control plane | 6443/TCP | kubectl |
| Workers | Control plane | 6443/TCP | Agents vers API |
| Nœuds | Nœuds | 10250/TCP | Kubelet |
| Nœuds | Nœuds | 8472/UDP | Flannel VXLAN |
| Bastion | Workers | 30080/30443 TCP | Tests Ingress |

### 7.4 Applicatif et données

- `identity-api → PostgreSQL` ;
- `orders-api → PostgreSQL` ;
- `orders-api → Redis` ;
- `notifications-worker → PostgreSQL` ;
- `notifications-worker → Redis`.

Les connexions PostgreSQL sortent des Pods par les workers, seuls ports
OpenStack autorisés sur 5432/TCP.

### 7.5 Livraison

- identity : build/push sans scan ;
- orders : tests/build/push sans SBOM ;
- notifications : build local et déploiement manuel ;
- les images M13 sont importées manuellement sur les nœuds ;
- les images GHCR M15 ne mettent pas à jour les workloads M14.

### 7.6 Sécurité et audit

L'équipe Sécurité/Audit inspecte manuellement Git, le registre, les manifests et
le RBAC. Les security groups sont explicites, mais aucune policy-as-code
généralisée n'existe.

### 7.7 Observabilité

Prometheus collecte partiellement applications et nœuds, Grafana affiche des
dashboards manuels, et les logs sont souvent lus avec `kubectl logs`.

### 7.8 Sauvegarde

Le lab possède une sauvegarde PostgreSQL initiale locale sur la VM. Aucune
planification, copie vers un stockage objet ou restauration n'est démontrée.

## 8. Dettes et limitations

| Élément | État AS-IS |
|---|---|
| Underlay | Réseau provider partagé, aucune isolation L2 par projet |
| Segmentation | SG par rôle, dépendance forte à leur exactitude |
| Exposition | NodePort privé, aucun flux public réel |
| Kubernetes | Control plane unique, NetworkPolicies partielles |
| Données | PostgreSQL unique et Redis partagé |
| Livraison | Méthodes hétérogènes, aucun GitOps commun |
| Observabilité | Métriques partielles, logs non centralisés |
| Reprise | sauvegarde DB initiale locale, zéro snapshot K3s, restores non testés |

## 9. Tests attendus

Après M06/M09/M10 :

- SSH administrateur vers bastion : autorisé ;
- SSH administrateur direct vers nœuds/DB : refusé ;
- bastion vers nœuds/DB en SSH : autorisé ;
- workers vers PostgreSQL 5432 : autorisé ;
- control plane vers PostgreSQL 5432 : refusé ;
- VXLAN 8472 entre nœuds uniquement : autorisé ;
- bastion vers NodePorts : autorisé ;
- source non-bastion vers NodePorts : refusée.

Ces preuves démontrent les frontières malgré l'underlay plat.
