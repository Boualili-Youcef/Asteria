# Conception réseau OpenStack — Provider-network-only

## 1. Objectif et résultat

Ce design remplace la première conception multi-réseaux devenue inexécutable
après les tests M05.

Résultat retenu :

- `prive` (`172.28.0.0/16`) comme underlay unique ;
- cinq ports Neutron gérés par Terraform ;
- zones de confiance par security groups ;
- overlay K3s pour Pods et Services ;
- NodePort privé depuis le bastion ;
- aucun réseau, sous-réseau ou routeur créé par Asteria.

La décision complète est consignée dans ADR-001.

## 2. Capacités réelles du tenant

| Capacité | État |
|---|---|
| Réseau provider `prive` | Disponible, partagé, actif |
| Ports Neutron | Disponibles, quota 500 |
| Port security | Activée sur `prive`, attribut explicite interdit à la création d'un port |
| Security groups | Disponibles, quota 10 |
| Réseaux self-service | Indisponibles, création HTTP 503 |
| Routeur/L3 | Extension absente, API HTTP 404 |
| Floating IP | API HTTP 404 |
| Octavia | Non confirmé |

Le quota nominal de réseaux n'implique pas la disponibilité d'un segment
provider/VLAN/VXLAN pour les projets.

## 3. Underlay OpenStack

Toutes les VMs utilisent le même réseau :

| Propriété | Valeur |
|---|---|
| Nom | `prive` |
| CIDR | `172.28.0.0/16` |
| Passerelle | `172.28.0.1` |
| DHCP | Activé |
| Port security | Activée |
| MTU | 1500 |

Terraform lit ce réseau comme data source et laisse Neutron allouer une adresse
dans son pool. Aucune adresse fixe n'est codée en dur.

## 4. Ports Neutron

| Port Terraform | VM future | Security groups |
|---|---|---|
| `asteria-bastion-port` | `bastion-admin-01` | bastion |
| `asteria-control-plane-port` | `k8s-control-plane-01` | control-plane |
| `asteria-worker-01-port` | `k8s-worker-01` | workers + ingress |
| `asteria-worker-02-port` | `k8s-worker-02` | workers + ingress |
| `asteria-postgres-port` | `db-postgres-01` | postgres |

Les ports sont créés pendant M05 et attachés aux instances pendant M06. Cela
évite l'application implicite du SG `default` et rend les IP/SG traçables.
La configuration ne renseigne pas `port_security_enabled` : la policy Neutron
du tenant l'interdit en HTTP 403. Neutron détermine la valeur effective à partir
du réseau et des SG demandés ; elle doit être confirmée avec
`openstack port show` après l'apply.

## 5. Zones de confiance logiques

| Zone | Matérialisation |
|---|---|
| Management | Port et SG bastion |
| Control plane | Port et SG control-plane |
| Workers/application | Deux ports avec SG workers |
| Ingress/DMZ logique | SG ingress additionnel sur les workers |
| Data | Port et SG postgres |

Il n'existe aucune isolation L2 entre ces zones. La sécurité dépend des règles
stateful des ports ; cette dépendance est une limite AS-IS explicite.

## 6. Overlay Kubernetes

| Plan | CIDR | Implémentation |
|---|---|---|
| Nœuds | `172.28.0.0/16` | Réseau provider OpenStack |
| Pods | `10.42.0.0/16` | K3s Flannel VXLAN |
| Services | `10.43.0.0/16` | Kubernetes Services |

UDP/8472 est autorisé uniquement entre control plane et workers. Il n'est
jamais ouvert à un CIDR externe.

Les NetworkPolicies resteront partielles en phase 1, conformément à l'AS-IS.

## 7. Exposition

Le flux démontrable est :

`Administrateur → SSH bastion → NodePort worker → ingress-nginx → API`

Les NodePorts sont :

- 30080/TCP pour HTTP ;
- 30443/TCP pour HTTPS.

Le SG ingress accepte uniquement le SG bastion. Il n'existe ni Floating IP, ni
load balancer, ni DMZ Neutron réelle.

Le flux public B2B reste une référence d'entreprise et non une affirmation sur
le lab.

## 8. Matrice de flux

| Source | Destination | Port | Résultat |
|---|---|---:|---|
| CIDR administrateur strict | Bastion | 22/TCP | Autorisé |
| CIDR administrateur | Control plane/workers/DB | 22/TCP | Refusé |
| Bastion | Control plane/workers/DB | 22/TCP | Autorisé |
| Bastion | Control plane | 6443/TCP | Autorisé |
| Workers | Control plane | 6443/TCP | Autorisé |
| Nœuds Kubernetes | Nœuds Kubernetes | 10250/TCP | Autorisé selon rôle |
| Nœuds Kubernetes | Nœuds Kubernetes | 8472/UDP | Autorisé selon rôle |
| Bastion | Workers | 30080/30443 TCP | Autorisé |
| Autre source | Workers | 30080/30443 TCP | Refusé |
| Workers | PostgreSQL | 5432/TCP | Autorisé |
| Control plane/autre source | PostgreSQL | 5432/TCP | Refusé |

## 9. Sorties

Chaque SG autorise encore l'egress IPv4 large. Ce choix facilite mises à jour,
DNS, registre et dépendances, mais constitue une dette AS-IS à auditer en phase
2.

## 10. CIDR administrateur

`172.28.0.0/16` est interdit comme source SSH : il ouvrirait le bastion à tout
le réseau partagé.

`admin_cidrs` doit contenir :

- idéalement l'adresse stable de l'administrateur en `/32` ;
- sinon le plus petit CIDR VPN documenté.

`0.0.0.0/0` reste interdit par validation Terraform.

## 11. Critères d'acceptation

- plan : cinq ports, aucun réseau/sous-réseau/routeur ;
- `prive` uniquement lu ;
- SG existants conservés sans destruction ;
- SG explicites sur chaque port ;
- port security déterminée par Neutron et vérifiée après création ;
- IP attribuées par Neutron et exposées en outputs ;
- NodePorts limités au bastion ;
- tests positifs et négatifs planifiés pour M06/M10.
