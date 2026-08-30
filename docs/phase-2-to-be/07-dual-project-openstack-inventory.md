# Inventaire dual-project OpenStack et décision de capacité

## 1. Statut de T02

**Mission terminée.** Les deux inventaires authentifiés ont été reçus le
30 août 2026. Les capacités et le sizing sont établis. Le propriétaire a
confirmé que les deux VM CKA étaient jetables, puis les a supprimées avant le
probe. Le contrôle live final confirme que le second projet est vide.

Le but de T02 est de remplacer les captures et déclarations historiques par un
état live horodaté des deux projets, avant tout nouveau sizing ou ADR T03.

## 2. Exigences et risques concernés

| Exigence T01 | Apport attendu de T02 |
|---|---|
| REQ-SVC-011 | quotas, usage réel et marge de capacité |
| REQ-SEC-003 | limites réseau et capacité d'isolation |
| REQ-SEC-009 | AZ, placement et ressources disponibles |
| REQ-SEC-012 | séparation des projets, credentials, states et chemin de migration |
| REQ-DATA-007 | domaine logique et cible possible des sauvegardes |
| REQ-DATA-010 | ressources nécessaires à une reconstruction séparée |

Constats principalement cadrés : `ASIS-001`, `ASIS-002`, `ASIS-003`,
`ASIS-005`, `ASIS-007`, `ASIS-020` et `ASIS-022`.

T02 ne ferme aucun de ces constats. Il vérifie les capacités sur lesquelles les
ADR et implémentations ultérieures pourront s'appuyer.

## 3. Faits actuellement vérifiés

- le state Terraform local contient 39 objets, dont cinq instances, cinq ports,
  cinq security groups et leurs règles ; ce state ne prouve pas l'état live ;
- aucun `OS_AUTH_URL` ou `OS_CLOUD` n'est chargé dans l'environnement Codex ;
- le client local est `python-openstackclient 6.6.0` ;
- les commandes locales Octavia `loadbalancer` et Designate `zone` ne sont pas
  installées ; cela décrit le client, pas le catalogue du cloud ;
- M03 avait observé sur le premier projet 8 instances, 10 vCPU et 20 480 Mo de
  RAM, avec `prive` comme réseau provider partagé ;
- M06 avait créé une empreinte AS-IS de 5 instances, 9 vCPU et 17 Go ;
- M03/M05 avaient observé l'absence de L3/Floating IP utilisable et
  l'impossibilité de créer des réseaux self-service ;
- l'utilisateur a indiqué disposer d'un second compte avec des capacités
  similaires ; l'inventaire live corrige cette déclaration : sa limite réelle
  est 4 instances, 4 vCPU et 8 Go de RAM.

Les données M03/M06 sont un point de comparaison historique, pas l'inventaire
courant exigé par T02.

## 4. Hypothèses à vérifier

| ID | Hypothèse | Résultat live |
|---|---|---|
| HYP-T02-01 | Les deux comptes ciblent des quotas indépendants. | Confirmée par deux authentifications et deux quotas différents. |
| HYP-T02-02 | Le second projet possède 8 instances, 10 vCPU et 20 Go. | **Réfutée** : 4 instances, 4 vCPU et 8 Go. |
| HYP-T02-03 | Les deux projets voient le même réseau provider `prive`. | Confirmée au niveau API : mêmes nom, CIDR, pool, MTU et propriétés partagées. |
| HYP-T02-04 | Des VMs des deux projets communiquent sur les flux autorisés. | Non résolue : refus TCP/22 et 6443 observé avant règle, puis toutes les VM cibles ont été supprimées. Test positif reporté à T05. |
| HYP-T02-05 | Cinder fournit volumes et snapshots. | Réfutée : aucun service volume au catalogue, endpoints absents. |
| HYP-T02-06 | Swift ou S3 fournit une cible de sauvegarde. | Réfutée pour Swift ; S3 non annoncé et non démontré. |
| HYP-T02-07 | Plusieurs AZ représentent des domaines de panne distincts. | Réfutée : une seule AZ `nova` observable. |
| HYP-T02-08 | Config-drive fonctionne dans le projet cible. | Non vérifiée : les deux VM cibles existantes n'utilisent pas config-drive ; fonctionnement confirmé seulement sur les cinq VM source. |
| HYP-T02-09 | Octavia ou Designate sont utilisables. | Réfutée dans le catalogue ; plugins CLI également absents. |

## 5. Matrice d'inventaire validée

| Capacité | Projet source | Projet secondaire | Décision T02 |
|---|---|---|---|
| authentification | succès | succès | deux collectes séparées et horodatées |
| instances | 5/8, libre 3 | 2/4, libre comptable 2 | le secondaire reste bloqué par CPU/RAM |
| vCPU | 9/10, libre 1 | 4/4, libre 0 | aucun nouveau compute actuellement |
| RAM | 17/20 Go, libre 3 Go | 8/8 Go, libre 0 | aucun nouveau compute actuellement |
| ports | 5/500 | 2/500 | non structurant |
| security groups | 8/10 | 1/10 | source : seulement 2 SG libres ; cible : 9 |
| règles SG | 37/100 | 4/100 | marge suffisante, à budgéter par design |
| keypairs observées | 6/10 | 5/10 | marge limitée mais suffisante ; préférer certificats courts ultérieurement |
| flavors/images | six flavors ; Ubuntu 24.04 actif | mêmes six flavors et image | baseline homogène possible |
| compute AZ | une AZ `nova` | une AZ `nova` | aucune HA de zone revendicable |
| config-drive | vrai sur les cinq VM | vide sur les deux VM | support cible à prouver lors d'une création contrôlée |
| réseau | `prive`, partagé/externe, MTU 1500 | mêmes propriétés | aucun réseau self-service ; même domaine logique visible |
| subnet/DHCP/DNS resolver | même `/16`, DHCP et résolveurs | identique | pas de collision ; pas de DNS autoritatif OpenStack |
| L3/router | API 404 | API 404 | indisponible |
| Floating IP | API 404 | API 404 | indisponible malgré quota historique |
| agents réseau | aucun visible | aucun visible | aucune topologie agent à exploiter |
| Cinder/snapshots/backups | aucun endpoint | aucun endpoint | indisponible |
| Swift/S3 | aucun endpoint Swift ; S3 non annoncé | identique | cible backup externe à OpenStack requise |
| Octavia | absent du catalogue ; plugin absent | identique | indisponible |
| Designate | absent du catalogue ; plugin absent | identique | indisponible |
| connectivité inter-projets | bastion source joignable | endpoints supprimés avant probe | test positif obligatoire à la création T05 |

## 6. Résultat de capacité consolidé

### 6.1 Avant libération

| Portefeuille actuel | Limite | Utilisé | Libre |
|---|---:|---:|---:|
| Instances, deux projets | 12 | 7 | 5 |
| vCPU, deux projets | 14 | 13 | 1 |
| RAM, deux projets | 28 Go | 25 Go | 3 Go |

### 6.2 Après libération vérifiée

| Projet secondaire après suppression | Limite | Utilisé | Libre |
|---|---:|---:|---:|
| Instances | 4 | 0 | 4 |
| vCPU | 4 | 0 | 4 |
| RAM | 8 Go | 0 | 8 Go |
| Ports | 500 | 0 | 500 |
| Security groups | 10 | 1 | 9 |
| Règles SG | 100 | 4 | 96 |

Après suppression, la marge combinée non mutualisable est de 7 instances,
5 vCPU et 11 Go. Le second projet conserve seulement son security group
`default` et ses quatre règles par défaut ; il ne possède plus de port compute.

Les quotas ne forment pas un pool unique : une ressource ne peut pas consommer
la marge d'un autre projet. Même si les deux VM CKA sont libérées, le second
projet restera limité à 4 vCPU/8 Go, insuffisant pour CAP-02 ou CAP-03.

Il n'existe aucune cible de sauvegarde durable fournie par ce cloud : pas de
Cinder, snapshot volume, Swift ou S3 observé. Les images Glance et disques root
Nova ne sont pas assimilés à un stockage objet indépendant ou à un DR.

## 7. Scénarios de sizing après collecte

Les flavors et limites ci-dessous sont confirmés par les deux inventaires live.
Le choix architectural entre les scénarios appartient encore aux ADR T03.

| Scénario | Composition | Instances | vCPU | RAM | Lecture provisoire |
|---|---|---:|---:|---:|---|
| CAP-01 | AS-IS : accès 1/1, CP 2/4, 2 workers 2/4, PostgreSQL 2/4 | 5 | 9 | 17 Go | déployé sur source ; marge 1 vCPU/3 Go |
| CAP-02 | cible compacte identique dans le secondaire | 5 | 9 | 17 Go | **impossible**, dépasse 4 instances/4 vCPU/8 Go |
| CAP-03 | cible 3 workers réduits : accès 1/1, CP 2/4, 3 workers 1/2, PostgreSQL 2/4 | 6 | 8 | 15 Go | possible seulement après reconstruction dans le projet source ; pas en parallèle |
| CAP-04 | cible 3 workers `puissante` | 6 | 11 | 21 Go | impossible dans les deux projets |
| CAP-05 | staging secondaire : CP 2/4 + worker 2/4 | 2 | 4 | 8 Go | tient exactement après libération/recréation des deux VM ; aucune marge ni data externe |

Décision de capacité : conserver deux workers `puissante` pendant la migration.
CAP-03 pourra être comparé en T03 comme reconstruction future du projet source,
mais pas comme blue/green. CAP-05 est le seul rôle Kubernetes réaliste pour le
second projet et reste un staging non HA, sans stockage cloud durable.

## 8. Décision de rôle

| Option | Projet source | Projet candidat | Conditions minimales | État |
|---|---|---|---|---|
| ROLE-01 | AS-IS puis staging | green/production lab | 9 vCPU/17 Go dans le secondaire | Rejetée : quota insuffisant |
| ROLE-02 | production lab transformée progressivement | staging Kubernetes léger | projet vidé et test réseau à la création | **Retenue ; capacité libérée et vérifiée** |
| ROLE-03 | workloads cible | stockage/backups partagés | stockage objet/volume disponible | Rejetée : aucun service de stockage |
| ROLE-04 | production lab | projet de tests isolés sans dépendance | connectivité impossible ou VM CKA conservées | Repli accepté |

Le projet source conserve l'AS-IS et portera une transformation progressive
avec sauvegarde et rollback. Le propriétaire a confirmé le 30 août 2026 que
les deux VM CKA étaient jetables, puis a déclaré le projet entièrement vidé.
Le second projet devient donc la capacité réservée au futur staging géré par un
state Terraform distinct à partir de T05. Il ne devient ni production, ni
backup, ni DR.

La stratégie blue/green de cluster T00 est abandonnée pour le lab, car la
capacité ne la permet pas. La référence entreprise conserve blue/green ; le lab
démontrera staging séparé, promotions applicatives progressives et rollback.

## 9. Portes de validation

| Gate | Condition observable | Statut |
|---|---|---|
| GATE-T02-01 | deux rapports authentifiés et horodatés | Validée |
| GATE-T02-02 | quotas **et usages** compute/network/volume connus | Validée après suppression : compute/ports à zéro |
| GATE-T02-03 | flavors, images, AZ et config-drive évalués | Validée avec config-drive cible reporté au test de création |
| GATE-T02-04 | réseau, L3, Floating IP, Octavia et DNS classés en disponible/absent/refusé/plugin manquant | Validée |
| GATE-T02-05 | Cinder, snapshots, Swift/S3 et cible backup évalués | Validée : absents, cible externe requise |
| GATE-T02-06 | connectivité positive/négative testée, ou report explicitement accepté | Acceptée avec dette : endpoints supprimés ; test bloquant reporté à T05 |
| GATE-T02-07 | scénario et rôles décidés ; marge quantifiée et acceptée | Validée : CAP-05 retenu, absence de marge explicitement acceptée |
| GATE-T02-08 | preuve neutralisée, sans UUID, endpoint ni secret | Validée : preuve publique propre et trois formats factices revalidés |

Les huit gates sont closes. La dette de test de GATE-T02-06 est acceptée mais
devient un critère bloquant explicite de T05 ; elle ne constitue pas une preuve
de connectivité. T03 est maintenant autorisée.

## 10. Impact, rollback et critères d'arrêt

La collecte fournie par `scripts/t02-collect-openstack-inventory.sh` est en
lecture seule. Elle ne crée, ne modifie et ne supprime aucune ressource.

La suppression autorisée de `cka-cp` et `cka-worker1` détruit définitivement
leurs disques root éphémères et l'état etcd qu'ils portent. Le propriétaire les
a déclarés jetables puis a indiqué avoir vidé le projet : aucun backup n'était
requis pour ces deux VM. Le rollback est une recréation ultérieure, pas une
restauration de leurs données.

- backup runtime : non applicable à la collecte ;
- rollback : suppression locale des rapports temporaires dans `/tmp` ;
- arrêt immédiat : mauvais projet chargé, sortie contenant un secret, quota ou
  usage inaccessible, commande destructive, ou tentative de créer un probe
  sans plan et approbation explicite.

Le contrôle final confirme la libération de 2 instances, 4 vCPU et 8 Go ainsi
que l'absence de port compute. Aucune suppression complémentaire n'est requise.
