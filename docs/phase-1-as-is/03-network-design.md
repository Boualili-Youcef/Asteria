# Conception réseau OpenStack — Phase 1 AS-IS

## 1. Objectif et résultat attendu

Cette conception définit les réseaux, le routage et le mécanisme d'exposition
avant leur création. Elle traduit l'architecture figée en M02 en un plan
compatible avec l'inventaire OpenStack M03.

Résultat attendu : quatre réseaux internes isolés, raccordés à un routeur dont
la passerelle externe référence le réseau partagé `prive`. Aucun élément de ce
document ne représente une ressource déjà créée.

## 2. Faits issus de M03

- réseau externe partagé : `prive` ;
- CIDR externe : `172.28.0.0/16` ;
- passerelle externe : `172.28.0.1` ;
- sécurité des ports activée et MTU de 1500 ;
- Floating IP inutilisable lors de l'inventaire : HTTP 404 ;
- Octavia non confirmé ;
- quotas réseau largement suffisants pour quatre réseaux et sous-réseaux ;
- dix security groups maximum, dont trois déjà présents.

Le réseau `prive` est une dépendance existante. Terraform doit le rechercher par
son nom, sans le créer, le modifier ou le détruire.

## 3. Plan d'adressage

### 3.1 Réseaux OpenStack

| Zone | Nom OpenStack | CIDR | Passerelle | Pool DHCP | Usage |
|---|---|---|---|---|---|
| Management | `asteria-mgmt-net` | `10.20.10.0/24` | `10.20.10.1` | `10.20.10.20-10.20.10.199` | Bastion et administration |
| Application | `asteria-app-net` | `10.20.20.0/24` | `10.20.20.1` | `10.20.20.20-10.20.20.199` | Nœuds Kubernetes |
| Data | `asteria-data-net` | `10.20.30.0/24` | `10.20.30.1` | `10.20.30.20-10.20.30.199` | VM PostgreSQL |
| Public services / DMZ | `asteria-public-services-net` | `10.20.40.0/24` | `10.20.40.1` | `10.20.40.20-10.20.40.199` | Zone d'entrée logique AS-IS |

Les adresses `.2` à `.19` et `.200` à `.254` restent hors du pool DHCP pour de
futures adresses fixes ou besoins d'exploitation documentés.

### 3.2 Réseaux Kubernetes réservés

La future installation Kubernetes doit réserver :

| Usage Kubernetes | CIDR réservé |
|---|---|
| Pods | `10.42.0.0/16` |
| Services | `10.43.0.0/16` |

Ces CIDR correspondent au choix K3s envisagé dans l'AS-IS. M09 devra les
confirmer explicitement. Ils ne doivent pas être utilisés par Neutron.

### 3.3 Validation des collisions

Les quatre `/24` Asteria sont contenus dans `10.20.0.0/16`. Ils ne chevauchent :

- ni le réseau externe `172.28.0.0/16` ;
- ni le CIDR Pods `10.42.0.0/16` ;
- ni le CIDR Services `10.43.0.0/16` ;
- ni les trois autres réseaux internes.

M03 ne donne pas l'inventaire de tous les réseaux privés d'autres projets. Le
plan est donc valide dans le périmètre observable du tenant. Un contrôle
`openstack subnet list` reste obligatoire juste avant le plan Terraform.

## 4. Routage

Un routeur `asteria-router` doit :

1. utiliser `prive` comme passerelle externe existante ;
2. posséder une interface dans chacun des quatre sous-réseaux internes ;
3. permettre les sorties nécessaires aux mises à jour, au registre et aux
   services externes ;
4. laisser les security groups contrôler les entrées vers les instances.

Le routeur fournit du routage entre les sous-réseaux. Cette possibilité ne vaut
pas autorisation : les flux autorisés restent définis par les security groups.

La capacité de créer un routeur avec `prive` comme gateway doit être confirmée
par `terraform plan` puis par l'utilisateur avant l'apply.

## 5. Mécanisme d'exposition

### 5.1 Baseline exécutable

Le mode retenu est **NodePort privé via le bastion** :

1. le bastion possédera ultérieurement une interface sur `prive` et une sur
   `asteria-mgmt-net` ;
2. les workers restent uniquement sur `asteria-app-net` ;
3. ingress-nginx utilisera les NodePorts `30080/TCP` et `30443/TCP` ;
4. seuls les ports portant le security group du bastion peuvent joindre ces
   NodePorts ;
5. l'opérateur utilise un tunnel SSH via le bastion pour les validations.

Ce chemin permet de tester l'Ingress sans prétendre fournir le flux public
complet de l'entreprise réelle.

### 5.2 DMZ

`asteria-public-services-net` matérialise la zone DMZ du diagramme. Aucun port de
compute n'y est attaché pendant M05. Elle reste disponible pour représenter le
point d'entrée si la capacité Floating IP ou Octavia devient réellement
utilisable.

### 5.3 Capacités non retenues

- aucune Floating IP n'est créée tant que l'API retourne 404 ;
- aucune ressource Octavia n'est créée ;
- aucun NodePort n'est ouvert à `0.0.0.0/0` ;
- aucun réseau externe n'est géré par le state Terraform Asteria.

## 6. DNS et DHCP

DHCP est activé sur les quatre sous-réseaux. Les serveurs DNS seront fournis par
une variable Terraform et recopiés depuis les valeurs du cloud, sans les
inventer dans le code.

La variable devra contenir au moins un résolveur valide avant le plan destiné à
l'apply. Les valeurs locales sensibles ou spécifiques au lab sont placées dans
un fichier `terraform.tfvars` non suivi par Git.

## 7. Flux réseau attendus

| Source | Destination | Usage |
|---|---|---|
| Poste administrateur autorisé | Bastion sur `prive` | SSH d'administration |
| Bastion | Control plane, workers, PostgreSQL | Administration SSH |
| Bastion | API Kubernetes | kubectl sur 6443/TCP |
| Workers | API Kubernetes | Enregistrement et contrôle sur 6443/TCP |
| Nœuds Kubernetes | Nœuds Kubernetes | Overlay et kubelet |
| Bastion | NodePorts Ingress sur workers | Validation HTTP/HTTPS par tunnel |
| Workers | PostgreSQL | Accès applicatif sur 5432/TCP |
| Instances internes | Réseau externe via routeur | Mises à jour, images, registre |

Les flux applicatifs internes à l'overlay Kubernetes ne nécessitent pas une
règle Neutron par service. Ils utilisent le transport inter-nœuds autorisé.

## 8. Hypothèses à confirmer avant apply

- l'usage réel laisse assez de quotas pour le routeur, réseaux, ports et règles ;
- le tenant peut utiliser `prive` comme gateway de routeur ;
- les CIDR ne chevauchent aucun sous-réseau devenu visible depuis M03 ;
- au moins un CIDR administrateur est connu pour SSH ;
- les résolveurs DNS du lab sont fournis ;
- les règles existantes ne consomment pas déjà la limite de cent.

## 9. Critères d'acceptation

- aucun chevauchement de CIDR ;
- réseau externe référencé mais non géré ;
- quatre zones du diagramme représentées ;
- exposition NodePort limitée au bastion ;
- flux inter-zones explicitement justifiés ;
- aucune dépendance Floating IP ou Octavia cachée.
