# Inventaire et contraintes du lab OpenStack

## 1. Objet et provenance

Ce document transforme les sorties OpenStack capturées le 15 juillet 2026 en
contraintes utilisables pour la conception. Les commandes initiales ont été
exécutées par le propriétaire du tenant depuis un terminal authentifié puis
transmises pour documentation.

Les identifiants de ressources et de projet ne sont pas reproduits : ils ne sont
pas nécessaires aux décisions de M03. Aucun secret ni jeton d'authentification
n'a été fourni ou enregistré.

Des contrôles complémentaires ont été tentés depuis l'environnement local
Codex. Ils n'ont pas interrogé le cloud, car les variables d'authentification
OpenStack n'y sont pas chargées. Cette limite est documentée comme telle.

## 2. Faits observés et hypothèses

### 2.1 Faits observés

- les quotas maximums du tenant sont connus ;
- six flavors publics sont visibles ;
- huit images actives sont visibles ;
- un réseau de projet nommé `prive` est visible ;
- trois security groups existent ;
- `openstack floating ip list` retourne une erreur HTTP 404 de l'API Neutron ;
- l'extension Neutron `router`/L3 n'est pas exposée ;
- `openstack router list` retourne HTTP 404 ;
- la création de réseaux self-service retourne HTTP 503 ;
- `openstack network agent list` ne retourne aucun agent visible ;
- le client OpenStack local ne possède pas la commande Octavia
  `loadbalancer provider list`.

### 2.2 Éléments non observés

- la consommation actuelle des quotas compute et RAM ;
- les serveurs déjà présents dans le tenant ;
- un endpoint Octavia dans le catalogue du cloud ;
- le nombre de règles déjà consommées dans les security groups.

Ces éléments non observés ne sont pas transformés en faits. Ils deviennent des
contrôles préalables obligatoires avant tout `terraform apply`.

## 3. Quotas du tenant

### 3.1 Quotas structurants

| Ressource | Limite | Conséquence pour Asteria |
|---|---:|---|
| RAM | 20 480 Mo | 20 Go maximum sur le tenant |
| Instances | 8 | 5 instances prévues, sous réserve de l'usage existant |
| Cœurs | 10 | 9 vCPU prévus, marge nominale de 1 vCPU |
| Réseaux | 100 | capacité nominale suffisante |
| Sous-réseaux | 100 | capacité nominale suffisante |
| Ports | 500 | capacité nominale suffisante |
| Floating IP | 10 | quota déclaré, mais API Floating IP non fonctionnelle lors du test |
| Security groups | 10 | 3 existants, 7 emplacements nominaux restants |
| Règles de security group | 100 | consommation actuelle non capturée |
| Paires de clés | 10 | capacité nominale suffisante |
| Groupes de serveurs | 10 | non requis pour la baseline AS-IS |

Le quota indique une limite maximale, pas la capacité encore disponible. Tant
que l'usage actuel n'est pas capturé, la faisabilité reste nominale.

### 3.2 Autres limites observées

| Ressource | Limite |
|---|---:|
| Politiques RBAC | 10 |
| Pools de sous-réseaux | Illimité |
| Fixed IP | Illimité |
| Taille d'un fichier injecté | 10 240 octets |
| Taille d'un chemin injecté | 255 caractères |
| Fichiers injectés | 5 |
| Propriétés d'instance | 128 |
| Membres par groupe de serveurs | 10 |

## 4. Flavors disponibles

| Nom | vCPU | RAM | Disque | Usage envisagé |
|---|---:|---:|---:|---|
| `petite` | 1 | 512 Mo | 5 Go | Trop réduite pour la baseline |
| `normale` | 1 | 1 024 Mo | 10 Go | Bastion |
| `moyenne` | 1 | 2 048 Mo | 10 Go | Réserve, non prévue actuellement |
| `puissante` | 2 | 4 096 Mo | 20 Go | Control plane, workers et PostgreSQL |
| `tres puissante` | 4 | 8 192 Mo | 40 Go | Incompatible avec la baseline contrainte |
| `tres puissante avec stockage++` | 4 | 8 192 Mo | 60 Go | Incompatible avec la baseline contrainte |

Les noms de flavors sont des faits observés. Leur association aux rôles est une
décision de baseline à confirmer dans M04, pas une ressource déjà créée.

## 5. Images disponibles

Les images suivantes ont été observées avec le statut `active` :

- `ISN 2021 Projet` ;
- `PHYLOGENY_CPOUX_BILILLE_2021_03` ;
- `PopGenomics_D4` ;
- `RNA-seq_SLEGRAND` ;
- `debian-12-custom` ;
- `debian13` ;
- `debian_custom` ;
- `ubuntu24.04`.

`ubuntu24.04` constitue le candidat le plus lisible pour une baseline homogène,
mais M03 ne crée aucune VM et ne transforme pas ce candidat en sélection
Terraform définitive. M04 documentera le choix d'image et ses implications.

## 6. Réseaux et exposition

### 6.1 Réseau observé

Le réseau `prive` a été inspecté avec `openstack network show prive`.

| Propriété | Valeur observée |
|---|---|
| Statut | `ACTIVE` |
| État administratif | `UP` |
| Réseau externe | Oui |
| Partagé | Oui |
| Sécurité des ports | Activée |
| MTU | 1500 |
| Zone de disponibilité | `nova` |

Le réseau appartient à l'infrastructure partagée du cloud et ne doit pas être
créé, modifié ou détruit par Terraform Asteria. Il devra être référencé comme
une source de données existante.

### 6.2 Réseau externe

`prive` est confirmé comme réseau externe partagé accessible au tenant. Son
sous-réseau, également nommé `prive`, possède les propriétés suivantes :

| Propriété | Valeur observée |
|---|---|
| CIDR | `172.28.0.0/16` |
| Passerelle | `172.28.0.1` |
| Pool d'allocation | `172.28.100.0` à `172.28.200.255` |
| DHCP | Activé |
| Version IP | IPv4 |
| Routes additionnelles | Aucune |
| DNS | Deux résolveurs fournis par l'infrastructure |

Décision de M03 : Terraform pourra rechercher le réseau externe par son nom
`prive`, mais uniquement comme ressource existante non gérée. Les réseaux
internes initialement envisagés ne sont pas créables sur ce tenant.

### 6.3 Réseaux self-service et routage

Les extensions exposées comprennent `external-net`, `security-group`,
`port-security` et `binding`, mais pas `router`. Les appels confirment :

- création des réseaux internes : HTTP 503 ;
- liste/création des routeurs : HTTP 404 ;
- création d'un port avec `port_security_enabled` explicite : HTTP 403 ;
- aucun agent réseau visible avec `openstack network agent list`.

Le 403 ne signifie pas que la port security est désactivée. `prive` l'active
au niveau du réseau ; la policy interdit au projet de fixer lui-même cet
attribut. Terraform doit donc l'omettre et contrôler la valeur effective sur
les ports créés.

Le quota `networks = 100` est une limite comptable, pas la preuve qu'un segment
tenant soit disponible. Le lab est traité comme provider-network-only.

### 6.4 Floating IP

La limite de quota annonce dix Floating IP, mais
`openstack floating ip list` retourne une erreur `ResourceNotFound 404` sur la
ressource Neutron. Un quota présent ne garantit donc pas que l'API soit exposée
ou utilisable dans ce cloud.

La confirmation du réseau externe ne résout pas ce 404 : réseau externe visible
et API Floating IP utilisable sont deux capacités différentes.

Décision de M03 : la Floating IP n'appartient pas à la baseline exécutable tant
que ce 404 n'est pas résolu. Le design M04 doit prévoir le chemin NodePort
autorisé par l'architecture, accessible depuis le contexte réseau du lab.

### 6.5 Octavia

La disponibilité du service Octavia côté cloud n'est pas démontrée. Le client
local ne reconnaît pas la commande `openstack loadbalancer`, ce qui prouve
seulement que son plugin n'est pas disponible dans cet environnement.

Décision de M03 : Octavia n'est pas retenu dans la baseline. Il pourra être
réévalué si le catalogue OpenStack et un client authentifié confirment le
service, sans bloquer le chemin NodePort de l'AS-IS.

## 7. Security groups

Trois security groups sont visibles :

- `default` ;
- `moodle-lab-sg` ;
- `k8s_sg_defense`.

Leur présence ne justifie pas leur réutilisation pour Asteria. Leurs règles
n'ont pas été inventoriées et deux groupes semblent appartenir à d'autres usages
du tenant.

Avec une limite de dix groupes, les cinq groupes logiques envisagés pour Asteria
restent nominalement possibles en plus des trois existants. M04 devra toutefois
vérifier les règles actuelles et rester sous la limite globale de cent règles.

## 8. Arbitrage de la baseline Kubernetes

### 8.1 Baseline à deux workers

| Rôle | Nombre | Flavor | vCPU total | RAM totale |
|---|---:|---|---:|---:|
| Bastion | 1 | `normale` | 1 | 1 Go |
| Control plane | 1 | `puissante` | 2 | 4 Go |
| Workers | 2 | `puissante` | 4 | 8 Go |
| PostgreSQL | 1 | `puissante` | 2 | 4 Go |
| **Total** | **5** | — | **9** | **17 Go** |

Cette baseline respecte nominalement les limites de 8 instances, 10 vCPU et
20 Go. Elle laisse 3 emplacements d'instance, 1 vCPU et 3 Go, avant prise en
compte de ressources déjà consommées.

### 8.2 Variante à trois workers

Ajouter un troisième worker `puissante` porterait le total à :

- 6 instances ;
- 11 vCPU ;
- 21 Go de RAM.

Cette variante dépasse les quotas de **1 vCPU et 1 Go**. Elle est donc rejetée
pour la phase 1, indépendamment de l'usage actuel du tenant.

### 8.3 Décision

La baseline de la phase 1 est définitivement fixée à **un control plane et deux
workers**, soit 5 instances, 9 vCPU et 17 Go. Une hausse future de quota ne doit
pas modifier silencieusement cet AS-IS.

## 9. Contrôles préalables avant création de ressources

Depuis un terminal OpenStack authentifié, exécuter et documenter avant M06 :

```bash
openstack limits show --absolute
openstack server list
openstack port list
openstack security group rule list
openstack catalog list
```

Si le plugin Octavia est installé et si le catalogue expose le service :

```bash
openstack loadbalancer provider list
```

Ces commandes ne remettent pas M03 en cause : elles constituent un garde-fou
contre la dérive entre l'inventaire documentaire et l'état du tenant au moment
d'un apply.

## 10. Risques et erreurs fréquentes

- confondre limites de quota et ressources réellement libres ;
- déduire qu'une Floating IP fonctionne parce qu'un quota est affiché ;
- tenter de gérer ou modifier le réseau externe partagé `prive` dans Terraform ;
- demander réseaux/routeurs parce que les quotas les affichent alors que le
  backend ne les fournit pas ;
- réutiliser un security group existant sans lire ses règles ;
- choisir un flavor de 4 vCPU qui rendrait la baseline impossible ;
- considérer l'absence du plugin Octavia local comme une preuve absolue de
  l'absence du service cloud ;
- enregistrer des fichiers d'authentification ou sorties sensibles dans Git.

## 11. Conclusion de M03

Les quotas, flavors, images, réseau provider et security groups sont
inventoriés. Les tests M05 confirment une topologie provider-network-only.
ADR-001 remplace les réseaux privés et le routeur par cinq ports sur `prive`,
des security groups par rôle et l'overlay K3s.

Aucun apply supplémentaire n'est autorisé sans un plan confirmant zéro réseau,
zéro sous-réseau, zéro routeur et zéro destruction des SG existants.
