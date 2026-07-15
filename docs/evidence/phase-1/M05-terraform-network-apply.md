# Preuve M05 — Terraform réseau OpenStack

## Métadonnées

- **Date de préparation :** 2026-07-15
- **Mission :** M05
- **Résultat :** en cours — apply réservé à l'utilisateur

## Objectif

Créer reproductiblement les réseaux, sous-réseaux, routeur et security groups
définis par M04, sans gérer `prive` et sans Floating IP ni Octavia.

## Livrables préparés

- `versions.tf` et `provider.tf` ;
- `variables.tf` et `terraform.tfvars.example` ;
- `locals.tf`, `network.tf` et `security-groups.tf` ;
- `outputs.tf` et le README opératoire.

## Contrôles exécutés par Codex

```text
terraform version
→ bash: command not found: terraform
```

Terraform n'est pas installé dans l'environnement Codex. Donc :

- fmt, init et validate ne sont pas présentés comme réussis ;
- aucun provider n'a été téléchargé ;
- aucun plan et aucun apply n'ont été exécutés ;
- aucune ressource OpenStack n'a été modifiée.

## Revue statique

Commandes exécutées :

```bash
rg -n '^resource |^data ' infra/terraform/openstack/*.tf
rg -c '^resource "openstack_networking_secgroup_v2"' \
  infra/terraform/openstack/security-groups.tf
rg -c '^resource "openstack_networking_secgroup_rule_v2"' \
  infra/terraform/openstack/security-groups.tf
rg -n 'floatingip|loadbalancer|compute_instance' \
  infra/terraform/openstack -g '*.tf'
git check-ignore -v infra/terraform/openstack/terraform.tfvars
git check-ignore -v infra/terraform/openstack/m05-network.tfplan
git diff --check
```

Résultats observés :

- cinq blocs de création de security groups ;
- quinze blocs de règles, dont deux utilisent `for_each` : cinq règles egress
  et une règle SSH par CIDR administrateur ;
- aucun type de ressource Floating IP, load balancer ou compute ;
- tfvars et plans correctement ignorés ;
- aucune erreur de whitespace dans le diff.

- `prive` est uniquement une data source ;
- quatre réseaux/sous-réseaux, un routeur et quatre interfaces sont déclarés ;
- cinq security groups sont déclarés ;
- NodePort 30080/30443 est limité au bastion ;
- aucune ressource Floating IP, Octavia ou compute n'existe ;
- tfvars et plans sont ignorés par Git ;
- aucun secret n'est versionné.

## Validation réservée à l'utilisateur

```bash
cp terraform.tfvars.example terraform.tfvars
# Remplacer les valeurs d'exemple.
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=m05-network.tfplan
terraform show -no-color m05-network.tfplan
# Après examen explicite seulement :
terraform apply m05-network.tfplan
```

## Résultats à reporter

- versions Terraform et provider ;
- résumé add/change/destroy ;
- confirmation que `prive` est seulement lu ;
- confirmation des quatre réseaux et cinq SG ;
- contrôles OpenStack neutralisés ;
- écarts éventuels.

## Critère de clôture

M05 reste `En cours` tant que init, fmt, validate, plan, apply et contrôles
OpenStack ne sont pas observés. M06 reste interdite jusque-là.
