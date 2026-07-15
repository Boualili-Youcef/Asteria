# ADR-001 — Adapter le lab à un réseau provider unique

- **Statut :** accepté
- **Date :** 2026-07-15
- **Portée :** phase 1 AS-IS, missions M02 à M06

## Contexte

La conception initiale prévoyait quatre réseaux Neutron privés, un routeur L3,
une passerelle vers `prive` et une exposition par Floating IP ou Octavia.

L'inventaire et le premier apply M05 ont démontré :

- un réseau provider partagé `prive` sur `172.28.0.0/16` ;
- les ports, security groups et règles stateful ;
- aucune extension Neutron `router`/L3 utilisable ;
- aucune Floating IP fonctionnelle ni service Octavia confirmé ;
- création des réseaux self-service en échec HTTP 503 ;
- création des routeurs en échec HTTP 404.

Les cinq security groups et leurs règles ont été créés avec succès. Les réseaux
et le routeur en échec ne sont pas entrés dans le state Terraform.

## Décision

Le lab utilisera une topologie **provider-network-only** :

1. les cinq VMs seront raccordées directement à `prive` ;
2. Terraform précréera un port Neutron par VM ;
3. chaque port recevra uniquement les security groups de son rôle ;
4. management, application, ingress et data deviennent des zones de confiance
   logiques, et non des sous-réseaux Neutron ;
5. K3s utilisera Flannel VXLAN avec les CIDR Pods `10.42.0.0/16` et Services
   `10.43.0.0/16` ;
6. ingress-nginx sera validé via NodePort depuis le bastion ;
7. aucun réseau, sous-réseau, routeur, Floating IP ou Octavia ne sera créé.

La référence d'entreprise conserve une segmentation plus riche. Le diagramme
distingue explicitement cette référence de l'implémentation réduite du lab.

## Conséquences positives

- architecture réellement déployable sur le cloud disponible ;
- security groups et ports Neutron gérés avec Terraform ;
- frontières et flux testables par contrôles positifs et négatifs ;
- véritable plan réseau applicatif avec l'overlay Kubernetes ;
- adaptation traçable et défendable en entretien.

## Conséquences négatives

- toutes les VMs partagent le même domaine d'adressage OpenStack ;
- aucune isolation L2 par réseau de projet ni DMZ Neutron réelle ;
- le bastion n'est plus multi-homed ;
- une erreur de security group aurait un impact plus important ;
- le flux public B2B de référence n'est pas reproduit dans le lab.

## Compensations

- security groups dédiés par rôle et appliqués aux ports ;
- SSH direct interdit vers les nœuds et PostgreSQL ;
- PostgreSQL accessible uniquement depuis les workers ;
- UDP/8472 limité aux nœuds Kubernetes ;
- NodePorts 30080/30443 accessibles uniquement depuis le bastion ;
- CIDR administrateur limité à un `/32` ou au plus petit réseau VPN possible ;
- preuves de flux autorisés et interdits ;
- NetworkPolicies partielles conservées sans anticiper la cible TO-BE.

## Alternatives rejetées

### Attendre une évolution du cloud

Dépendance externe non maîtrisée. L'ADR pourra être réévalué si les fonctions
L3/self-service sont activées.

### Ajouter pfSense, OPNsense ou VyOS

La marge restante n'est que de 1 vCPU et 3 Go. Une appliance ajouterait un point
de panne et une complexité éloignée du but principal.

### Construire des bridges/VLAN/VXLAN manuels entre VMs

Solution fragile, difficile à reproduire sur plusieurs hyperviseurs et trop
centrée sur le réseau pour la phase 1.

### Remplacer OpenStack

Rejeté : le diagnostic et l'adaptation à un cloud contraint font partie de la
valeur du projet.

## Critères de validation

- aucun réseau, sous-réseau ou routeur dans le plan Terraform ;
- `prive` apparaît uniquement comme data source ;
- cinq ports Neutron sont créés ;
- aucun security group existant n'est détruit ;
- aucun apply sans examen du plan ;
- flux autorisés et refusés démontrés après M06.
