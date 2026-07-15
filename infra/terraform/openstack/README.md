# Terraform OpenStack — Réseau Asteria

## Périmètre

Cette configuration :

- référence le réseau externe existant `prive` ;
- crée quatre réseaux et sous-réseaux internes ;
- crée `asteria-router` et ses quatre interfaces ;
- crée cinq security groups et leurs règles ;
- n'alloue aucune Floating IP ;
- ne crée ni Octavia ni VM.

Le provider OpenStack est contraint à la série 3.4.

## Prérequis

- Terraform >= 1.6 et < 2.0 ;
- OpenStack CLI authentifié ;
- variables `OS_*` ou `OS_CLOUD` configurées hors du dépôt ;
- quotas et CIDR revérifiés ;
- droit d'utiliser `prive` comme gateway ;
- CIDR administrateur précis et DNS du lab.

Ne jamais copier `clouds.yaml`, mot de passe, token ou clé privée ici.

## 1. Préparer les variables

```bash
cd infra/terraform/openstack
cp terraform.tfvars.example terraform.tfvars
```

Remplacer les adresses d'exemple. `terraform.tfvars` est ignoré par Git.

## 2. Préflight OpenStack

```bash
openstack limits show --absolute
openstack server list
openstack subnet list
openstack router list
openstack security group list
openstack security group rule list
openstack network show prive
```

Arrêter si les quotas, droits ou CIDR ne correspondent plus à M03/M04.

## 3. Initialiser et valider

```bash
terraform init
terraform fmt -check -recursive
terraform validate
```

Relire puis commiter le `.terraform.lock.hcl` généré.

## 4. Construire et examiner le plan

```bash
terraform plan -out=m05-network.tfplan
terraform show -no-color m05-network.tfplan
```

Plan attendu : 4 réseaux, 4 sous-réseaux, 1 routeur, 4 interfaces, 5 security
groups, 19 règles avec un CIDR administrateur, et aucune VM/FIP/Octavia.

Ne pas appliquer si Terraform prévoit de modifier ou détruire `prive` ou une
ressource existante.

## 5. Apply réservé à l'utilisateur

Codex ne lance pas cette commande. Après validation humaine :

```bash
terraform apply m05-network.tfplan
```

## 6. Contrôles après apply

```bash
terraform output
openstack network list
openstack subnet list
openstack router show asteria-router
openstack security group list
openstack security group rule list asteria-bastion-sg
openstack security group rule list asteria-control-plane-sg
openstack security group rule list asteria-workers-sg
openstack security group rule list asteria-ingress-sg
openstack security group rule list asteria-postgres-sg
```

Neutraliser les sorties avant de compléter la preuve M05.

## 7. Clôturer M05

Après apply et contrôles :

1. compléter `docs/evidence/phase-1/M05-terraform-network-apply.md` ;
2. ajouter le lockfile ;
3. passer M05 à `Terminée` ;
4. seulement ensuite commencer M06.
