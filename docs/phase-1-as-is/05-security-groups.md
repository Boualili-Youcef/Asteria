# Conception des security groups — Phase 1 AS-IS

## 1. Principes

Cinq security groups Asteria sont créés et suivis dans le state. Avec les trois
groupes observés en M03, le total est de huit sur un quota de dix.

Principes retenus :

- supprimer les règles par défaut lors de la création des groupes Asteria ;
- déclarer explicitement les sorties IPv4 ;
- utiliser les références de security groups pour les flux internes ;
- réserver les CIDR aux sources externes d'administration ;
- ne jamais réutiliser `default`, `moodle-lab-sg` ou `k8s_sg_defense` ;
- ne pas ouvrir les NodePorts au monde entier.

Les cinq VMs partagent `prive` : ces groupes constituent donc la principale
segmentation de l'underlay et doivent être attachés aux ports précréés, jamais
remplacés par le SG `default`.

Le diagramme Mermaid détaillé des flux autorisés est disponible dans
`docs/diagrams/as-is-internal-network-flows.mmd`. Il représente les règles
Terraform actuelles, et non une architecture cible de phase 2.

## 2. Groupes

| Nom | Attachement futur | Fonction |
|---|---|---|
| `asteria-bastion-sg` | Interfaces du bastion | Entrée administrative |
| `asteria-control-plane-sg` | Control plane | API et trafic Kubernetes |
| `asteria-workers-sg` | Workers | Kubelet, overlay et SSH interne |
| `asteria-ingress-sg` | Workers | NodePorts ingress-nginx |
| `asteria-postgres-sg` | VM PostgreSQL | Administration et accès DB |

## 3. Matrice des entrées

| SG destination | Source | Protocole/port | Justification |
|---|---|---|---|
| Bastion | CIDR administrateur explicite | TCP/22 | Accès SSH initial |
| Control plane | Bastion SG | TCP/22 | Administration |
| Control plane | Bastion SG | TCP/6443 | kubectl |
| Control plane | Workers SG | TCP/6443 | Agents Kubernetes vers API |
| Control plane | Workers SG | TCP/10250 | Kubelet entre nœuds |
| Control plane | Workers SG | UDP/8472 | Overlay Flannel VXLAN |
| Workers | Bastion SG | TCP/22 | Administration |
| Workers | Control plane SG | TCP/10250 | Kubelet piloté par le control plane |
| Workers | Control plane SG | UDP/8472 | Overlay vers les workers |
| Workers | Workers SG | UDP/8472 | Overlay entre workers |
| Ingress sur workers | Bastion SG | TCP/30080 | NodePort HTTP de validation |
| Ingress sur workers | Bastion SG | TCP/30443 | NodePort HTTPS de validation |
| PostgreSQL | Bastion SG | TCP/22 | Administration DB |
| PostgreSQL | Workers SG | TCP/5432 | Connexions des workloads applicatifs |

## 4. Sorties

Chaque SG autorise une sortie IPv4 vers `0.0.0.0/0`. Ce choix AS-IS permet :

- résolution DNS et mises à jour système ;
- récupération d'images et dépendances ;
- accès au registre et aux services externes.

Cette sortie large constitue une dette documentable pour la phase 2. Elle n'est
pas remplacée maintenant par un filtrage egress avancé.

## 5. Ports non ouverts

- `2379-2380/TCP` : inutiles avec un control plane unique K3s ;
- plage NodePort complète `30000-32767` : seuls 30080 et 30443 sont requis ;
- `5432/TCP` depuis management ou Internet : non autorisé ;
- SSH direct vers Kubernetes ou PostgreSQL depuis un CIDR externe : interdit ;
- ICMP entrant : non requis pour le fonctionnement et non ouvert par défaut ;
- ports Octavia ou Floating IP : aucune ressource correspondante.

## 6. Décompte nominal

Sans compter le nombre de CIDR administrateur :

- 5 règles egress ;
- 13 règles ingress utilisant des groupes distants ;
- 1 règle SSH par CIDR administrateur.

Avec un seul CIDR administrateur, Asteria consomme 19 règles. Le tenant resterait
nominalement sous le quota global de 100, sous réserve des règles existantes.

## 7. Risques et limites

- les règles SG sont stateful, mais le comportement exact dépend de Neutron ;
- UDP/8472 ne doit jamais être ouvert à une source externe ;
- le control plane doit rester sans workloads applicatifs pour que l'accès DB
  limité aux workers soit cohérent ;
- les CIDR administrateur doivent être précis, jamais `0.0.0.0/0` ;
- la limite globale doit être vérifiée avant apply.

## 8. Tests de validation

```bash
openstack security group list
openstack security group rule list
openstack quota show
openstack port list
```

Après apply, vérifier chaque groupe avec
`openstack security group rule list <nom-du-groupe>`.

Après M06, compléter avec des tests de connexion autorisés et refusés :

- administrateur vers bastion : succès ;
- administrateur vers nœuds/DB : refus ;
- bastion vers nœuds/DB : succès ;
- worker vers PostgreSQL : succès ;
- control plane vers PostgreSQL : refus ;
- source non-bastion vers NodePorts : refus.

## 9. Écart observé pendant M07

M07 a démontré qu'une connexion SSH directe depuis la source administrateur
atteignait le control plane, alors que le state Terraform confirmait à la fois
`port_security_enabled = true`, l'unique SG du control plane et une règle
TCP/22 dont la source est le SG bastion. La VM a vu la source administrateur
réelle : le test ne passait pas par un ProxyJump implicite.

La cause précise se situe dans le comportement effectif du réseau provider du
lab et ne peut pas être attribuée à la déclaration Terraform. Il ne faut donc
pas considérer les références inter-SG comme une frontière suffisante sur cet
underlay sans test fonctionnel.

M07 ajoute un contrôle compensatoire limité à l'administration SSH : les quatre
VMs internes autorisent l'utilisateur cloud seulement depuis l'adresse du
bastion. Les contrôles propres à PostgreSQL et Kubernetes seront validés dans
M08 et M09, sans prétendre que cet écart Neutron est corrigé globalement.

## 10. Écart observé pendant M10

Le premier test fonctionnel M10 a montré que TCP/30080 et TCP/30443 restaient
joignables directement depuis le poste administrateur sur les deux workers,
alors que `asteria-ingress-sg` référence seulement le SG du bastion. Ce résultat
confirme que, sur le réseau provider du lab, la référence inter-SG ne suffit pas
à démontrer l'isolement attendu. Une réponse HTTP, y compris une erreur de
protocole sur le port TLS, constitue ici une preuve que le port est joignable.

M10 ajoute donc sur chaque worker une chaîne `iptables` dans la table `raw`,
avant la DNAT Kubernetes : les NodePorts 30080 et 30443 acceptent uniquement
l'adresse `/32` du bastion et rejettent les autres sources. Le service systemd
`asteria-nodeport-firewall.service` rend ce contrôle persistant et le playbook
le réapplique de manière idempotente.

Après cette compensation, les quatre chemins HTTP/HTTPS depuis le bastion ont
répondu avec l'endpoint M10, tandis que les quatre tentatives directes depuis le
poste administrateur ont expiré. Ce contrôle est limité aux deux NodePorts
M10 ; il ne constitue ni une correction générale de Neutron, ni la conception
d'un pare-feu cible de phase 2.
