# Terraform T02 — Probe temporaire inter-projets

> **État après inventaire :** les VM cibles ont été supprimées avant le probe.
> Ne pas appliquer ce module sans nouvelle VM approuvée. Il est conservé comme
> contrat de test à reprendre lors de la création du staging en T05.

## 1. But et impact exact

Ce module ne crée ni VM, ni port, ni réseau. Il ajoute temporairement au
security group `default` du **projet secondaire** une seule règle :

```text
source = adresse /32 du bastion Asteria
destination = VM portant le SG default
protocole = TCP
port = 22
```

La règle sert à prouver un flux inter-projets autorisé. Le port Kubernetes API
`6443`, non ajouté, sert de refus attendu. Le module utilise un state séparé du
projet source et doit être supprimé après le test.

## 2. Prérequis privés

Récupérer l'adresse du bastion depuis le state source sans la placer dans Git :

```bash
terraform -chdir=../openstack output -json compute_instances \
  | jq -r '.bastion.access_ip_v4'
```

Copier `terraform.tfvars.example` vers `terraform.tfvars`, puis remplacer
l'adresse de documentation par `<IP_BASTION>/32`. Le fichier `.tfvars` est
ignoré par Git.

Charger ensuite **uniquement** l'OpenRC du projet secondaire et vérifier le
contexte sans afficher de token :

```bash
openstack token issue -f value -c expires
openstack quota show --network --usage
openstack security group list
```

Arrêter si le projet ne contient pas seulement le SG cible attendu ou si le
contexte chargé est ambigu.

## 3. Validation et plan

```bash
cd /home/youcef/Documents/Docs/M2/Asteria/infra/terraform/openstack-t02-probe
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=t02-connectivity-probe.tfplan
terraform show -no-color t02-connectivity-probe.tfplan
```

Plan attendu :

```text
Plan: 1 to add, 0 to change, 0 to destroy.
```

Le seul ajout doit être
`openstack_networking_secgroup_rule_v2.ssh_from_source_bastion`, sur TCP/22,
depuis un `/32`. Arrêter pour toute autre ressource, CIDR plus large,
modification ou destruction.

## 4. Apply et tests — après approbation explicite

Le baseline du 30 août 2026 refuse déjà TCP/22 et TCP/6443 depuis le bastion
source. Il doit rester refusé jusqu'à l'apply contrôlé ci-dessous.

```bash
terraform apply t02-connectivity-probe.tfplan
terraform output probe_contract
```

Depuis le bastion du projet source, vers l'IP privée du control plane CKA du
projet secondaire :

```bash
nc -zvw5 <IP_CONTROL_PLANE_SECONDAIRE> 22
nc -zvw5 <IP_CONTROL_PLANE_SECONDAIRE> 6443
```

Attendus :

- TCP/22 réussit ;
- TCP/6443 échoue depuis le bastion ;
- TCP/6443 est vérifié comme actif depuis la console du control plane ou une VM
  déjà autorisée du projet secondaire ; sinon le test négatif distant reste
  ambigu entre filtrage et service arrêté ;
- aucune autre règle n'est ajoutée ;
- aucun identifiant ou IP n'est copié dans la preuve publique.

Un succès TCP/22 prouve le chemin réseau et la règle autorisée. Le refus 6443
prouve que la visibilité du provider network ne crée pas un accès global.

## 5. Rollback obligatoire — après examen du plan

```bash
terraform plan -destroy -out=t02-connectivity-probe-destroy.tfplan
terraform show -no-color t02-connectivity-probe-destroy.tfplan
```

Le plan doit annoncer exactement `0 to add, 0 to change, 1 to destroy`. Après
approbation explicite :

```bash
terraform apply t02-connectivity-probe-destroy.tfplan
```

Rejouer ensuite :

```bash
nc -zvw5 <IP_CONTROL_PLANE_SECONDAIRE> 22
```

Attendu : échec, confirmant le retour à l'état initial. Conserver le state
local jusqu'à la preuve de suppression ; ne jamais supprimer seulement le
fichier state pour masquer une règle encore présente.
