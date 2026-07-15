# Preuve M06 — Instances OpenStack créées

## Métadonnées

- **Début :** 2026-07-15
- **Mission :** M06
- **Résultat :** en cours

## Objectif

Créer cinq VMs avec Terraform dans la baseline de 9 vCPU et 17 Go, en les
attachant aux cinq ports M05 sans modifier les frontières réseau existantes.

## Dépendances validées

- M05 terminée ;
- cinq ports précréés présents dans le state ;
- port security effective sur les cinq ports ;
- un SG sur bastion, control plane et PostgreSQL ;
- deux SG sur chaque worker ;
- clé publique locale `tp_cloud.pub` disponible ;
- clé privée correspondante présente avec le mode `0600`.

### Faits et limite de vérification

- l'utilisateur confirme avoir libéré les ressources compute préexistantes ;
- le shell Codex ne reçoit pas les variables `OS_*` de son terminal ;
- le fichier OpenRC local demande le mot de passe de façon interactive ;
- Codex ne lit ni ne demande ce mot de passe.

Les quotas libres, serveurs et keypairs doivent donc être contrôlés dans la
session authentifiée avant le plan et l'apply. L'affirmation de capacité libre
reste une information utilisateur tant que ces sorties ne sont pas observées.

L'empreinte de la clé peut être conservée ; son contenu et la clé privée ne
doivent jamais être copiés dans cette preuve.

## Configuration préparée

| Rôle | Nom | Flavor | Port M05 |
|---|---|---|---|
| Bastion | `bastion-admin-01` | `normale` | bastion |
| Control plane | `k8s-control-plane-01` | `puissante` | control plane |
| Worker | `k8s-worker-01` | `puissante` | worker 01 |
| Worker | `k8s-worker-02` | `puissante` | worker 02 |
| PostgreSQL | `db-postgres-01` | `puissante` | postgres |

Image commune : `ubuntu24.04`.

## Autorisation

L'utilisateur a explicitement autorisé Codex à créer les VMs M06. Cette
autorisation ne couvre que la keypair et les cinq instances du plan validé ;
elle ne couvre aucune destruction ou modification des ressources M05.

## Validations à exécuter

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
terraform plan -out=m06-compute-v2.tfplan
terraform show -no-color m06-compute-v2.tfplan
```

Plan acceptable : six ajouts, aucune modification et aucune destruction.

## Première tentative de plan

Le premier plan a correctement calculé :

- une keypair et cinq instances à créer ;
- zéro modification et zéro destruction ;
- l'image, les flavors, les noms et les cinq ports attendus ;
- aucune modification d'une ressource M05.

Terraform a toutefois terminé en erreur avant l'apply : l'output
`compute_instances` référençait `instance.status`, attribut non exposé par la
ressource du provider 3.4.0. La valeur est corrigée vers
`instance.power_state`.

Aucune ressource n'a été créée par cette tentative. L'ancien plan ne doit pas
être réutilisé ; un nouveau fichier `m06-compute-v2.tfplan` est requis.

## Apply et résultats

À compléter après l'apply.

## Critère de clôture

M06 reste `En cours` jusqu'à ce que les cinq instances soient `ACTIVE`, avec
les flavors, image, ports et accès attendus. M07 reste interdite jusque-là.
