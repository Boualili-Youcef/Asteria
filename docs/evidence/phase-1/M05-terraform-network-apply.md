# Preuve M05 — Terraform réseau OpenStack

## Métadonnées

- **Préparation initiale :** 2026-07-15
- **Révision ADR-001 :** 2026-07-15
- **Mission :** M05
- **Résultat :** en cours — nouvel apply réservé à l'utilisateur

## Objectif révisé

Référencer `prive` et créer de façon reproductible cinq ports Neutron et cinq
frontières SG, sans dépendre des fonctions L3 absentes.

## Premier apply et diagnostic

### Ressources créées

- cinq `openstack_networking_secgroup_v2` ;
- les règles associées ;
- state cohérent avec ces ressources.

### Ressources en échec

- quatre réseaux : HTTP 503 ;
- routeur : HTTP 404 ;
- sous-réseaux/interfaces non créés par dépendance.

Un plan de contrôle après l'échec annonçait 13 créations restantes et aucune
modification/destruction. Cela confirme que les SG réussis sont correctement
suivis et que les ressources réseau échouées ne sont pas dans le state.

### Capacités confirmées

- réseau provider `prive` disponible ;
- ports et port security disponibles ;
- security groups disponibles ;
- extension routeur/L3 absente ;
- réseau self-service indisponible ;
- Floating IP et Octavia indisponibles/non confirmés.

## Adaptation Terraform

- suppression des ressources network/subnet/router/interface ;
- conservation de `prive` comme data source ;
- conservation de tous les SG/règles existants ;
- ajout de cinq `openstack_networking_port_v2` ;
- IP attribuées par DHCP/IPAM Neutron ;
- outputs des IDs et IPs ;
- lockfile provider 3.4.0 ajouté au dépôt.

## Revue statique Codex

Commandes exécutées :

```bash
rg -n '^resource "openstack_networking_port_v2"' \
  infra/terraform/openstack/ports.tf
rg -n '^resource "openstack_networking_(network|subnet|router)' \
  infra/terraform/openstack -g '*.tf'
rg -n 'floatingip|loadbalancer|compute_instance' \
  infra/terraform/openstack -g '*.tf'
git diff --check
```

Résultat attendu :

- cinq ports ;
- aucune ressource réseau/sous-réseau/routeur ;
- aucune FIP/Octavia/VM ;
- aucun secret.

Résultat observé :

- exactement cinq ressources `openstack_networking_port_v2` ;
- aucune ressource `network_v2`, `subnet_v2` ou `router_v2` gérée ;
- aucune ressource Floating IP, load balancer ou compute ;
- `terraform.tfvars`, le state, `.terraform/` et les plans sont ignorés ;
- `.terraform.lock.hcl` est volontairement versionné ;
- `git diff --check` ne signale aucune erreur.

## Validation Terraform Codex

Commandes exécutées sans plan ni apply :

```bash
terraform version
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
```

Résultat observé :

- Terraform `1.15.8` ;
- provider OpenStack `3.4.0` réutilisé depuis le lockfile ;
- initialisation réussie ;
- formatage conforme ;
- configuration valide ;
- avertissement local : l'ancien `terraform.tfvars` contient encore la
  variable supprimée `dns_nameservers`.

Le fichier local n'a pas été lu ni modifié par Codex. L'utilisateur doit
retirer cette variable et remplacer le CIDR administrateur trop large avant le
plan.

## Validation utilisateur requise

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=m05-provider-ports.tfplan
terraform show -no-color m05-provider-ports.tfplan
```

Plan attendu avec le state actuel :

- cinq ports à ajouter ;
- éventuellement remplacement de la règle SSH si `admin_cidrs` est réduit ;
- aucune destruction de SG ;
- aucune autre ressource.

Après examen seulement :

```bash
terraform apply m05-provider-ports.tfplan
```

## Résultats à reporter

- résumé add/change/destroy ;
- confirmation de zéro réseau/sous-réseau/routeur ;
- confirmation de zéro destruction de SG ;
- cinq ports et leurs SG ;
- sorties OpenStack neutralisées ;
- éventuels écarts.

## Critère de clôture

M05 reste `En cours` jusqu'au nouvel apply et aux contrôles de ports. M06 reste
interdite jusque-là.
