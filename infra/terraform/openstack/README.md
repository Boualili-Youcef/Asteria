# Terraform OpenStack — Underlay et ports Asteria

## 1. Périmètre révisé

Cette configuration applique ADR-001 :

- lit le réseau provider existant `prive` ;
- conserve cinq security groups et leurs règles ;
- crée cinq ports Neutron, un par future VM ;
- laisse Neutron attribuer les adresses IP ;
- ne crée aucun réseau, sous-réseau, routeur, Floating IP, load balancer ou VM.

Le provider est verrouillé en version 3.4.0 par `.terraform.lock.hcl`.

## 2. État après le premier apply

Le premier apply de la conception multi-réseaux a produit un état partiel :

- cinq SG et leurs règles ont été créés avec succès ;
- quatre réseaux ont échoué en HTTP 503 ;
- le routeur a échoué en HTTP 404 ;
- aucun réseau, sous-réseau, interface ou routeur n'est présent dans le state.

Ne pas exécuter `terraform destroy` et ne pas retirer les SG du state.

## 3. Préparer les variables

Le fichier `terraform.tfvars` est local et ignoré par Git.

Il doit uniquement contenir les variables encore déclarées :

```hcl
admin_cidrs = [
  "203.0.113.10/32"
]

external_network_name = "prive"
name_prefix           = "asteria"
```

Remplacer l'IP de documentation par :

- idéalement l'IP stable de l'administrateur en `/32` ;
- sinon le plus petit CIDR VPN justifié.

Interdits :

- `0.0.0.0/0` ;
- `172.28.0.0/16`, trop large pour un accès SSH ;
- tout secret OpenStack.

Supprimer de l'ancien `terraform.tfvars` la variable `dns_nameservers`, devenue
inutile puisque le sous-réseau `prive` fournit DHCP et DNS.

## 4. Vérifier le state existant

```bash
cd infra/terraform/openstack
terraform state list
```

Le state doit contenir :

- la data source `prive` ;
- cinq `openstack_networking_secgroup_v2` ;
- leurs règles `openstack_networking_secgroup_rule_v2` ;
- aucun `network_v2`, `subnet_v2` ou `router_v2` géré.

## 5. Formater et valider

```bash
terraform init
terraform fmt -recursive
terraform fmt -check -recursive
terraform validate
```

## 6. Produire le nouveau plan

```bash
terraform plan -out=m05-provider-ports.tfplan
terraform show -no-color m05-provider-ports.tfplan
```

Avec le state actuel, le plan attendu est :

- 5 ports à créer ;
- 0 réseau ;
- 0 sous-réseau ;
- 0 routeur/interface ;
- 0 Floating IP ;
- 0 load balancer ;
- 0 VM ;
- 0 destruction de security group.

Si `admin_cidrs` est réduit, Terraform doit remplacer uniquement la règle SSH
du bastion devenue trop large. Cette modification est attendue.

Arrêter si le plan contient :

- une destruction de SG ;
- une modification de `prive` ;
- un réseau, sous-réseau ou routeur ;
- une adresse IP codée en dur.

## 7. Apply réservé à l'utilisateur

Après examen explicite :

```bash
terraform apply m05-provider-ports.tfplan
```

Codex ne lance pas cet apply.

## 8. Contrôles après apply

```bash
terraform output
openstack port list --network prive
openstack port show asteria-bastion-port
openstack port show asteria-control-plane-port
openstack port show asteria-worker-01-port
openstack port show asteria-worker-02-port
openstack port show asteria-postgres-port
openstack security group list
```

Pour chaque port, vérifier :

- réseau `prive` ;
- `port_security_enabled = true` ;
- SG correspondant au rôle ;
- workers avec les deux SG `workers` et `ingress` ;
- aucune application implicite du SG `default`.

Neutraliser UUID et IP propres au tenant avant de compléter la preuve publique.

## 9. Clôturer M05

Après plan, apply et contrôles :

1. compléter `docs/evidence/phase-1/M05-terraform-network-apply.md` ;
2. passer M05 à `Terminée` ;
3. committer la preuve ;
4. commencer M06 en attachant les VMs aux ports existants.
