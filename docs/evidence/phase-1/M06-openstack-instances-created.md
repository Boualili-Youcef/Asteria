# Preuve M06 — Instances OpenStack créées

## Métadonnées

- **Début :** 2026-07-15
- **Clôture :** 2026-07-19
- **Mission :** M06
- **Résultat :** réussi après correction config-drive

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

L'apply utilisateur a créé la keypair et les cinq instances. Horizon et le
state Terraform confirment :

- cinq instances `active` ;
- image `ubuntu24.04` pour les cinq ;
- flavor `normale` pour le bastion ;
- flavor `puissante` pour les quatre autres ;
- keypair `asteria-admin-key` pour les cinq ;
- exactement un port M05 attaché à chaque instance.

Les adresses et UUID ne sont pas reproduits dans cette preuve.

## Validation SSH et écart bloquant

Le test suivant a été exécuté depuis la source administrateur autorisée :

```bash
ssh -i ~/.ssh/tp_cloud ubuntu@<IP_BASTION> 'hostname; cloud-init status'
```

Résultat : connexion réseau et serveur SSH disponibles, mais authentification
refusée avec `Permission denied (publickey)`.

Contrôles complémentaires :

- utilisateurs `ubuntu`, `debian`, `cloud-user` et `root` refusés ;
- empreinte de la keypair OpenStack identique à `tp_cloud.pub` ;
- clé privée correspondante confirmée ;
- propriété Glance `os_admin_user = ubuntu`.

La VM a donc reçu la référence de keypair côté Nova, mais la clé n'est pas
utilisable dans le guest. Aucun mot de passe ni contenu de clé n'a été exposé.

## Correction config-drive

Terraform demande maintenant `config_drive = true` sur les cinq instances.
Selon Nova, ce disque fournit localement les métadonnées normalement servies
par le metadata service et peut être consommé automatiquement par cloud-init.

Le provider traite ce changement comme un remplacement de serveur. Un nouveau
plan `m06-compute-v3.tfplan` doit donc être examiné avant toute action. Il doit
remplacer uniquement les cinq instances et conserver les ports, SG et keypair.

## Apply config-drive et validation finale

L'utilisateur a appliqué le plan `m06-compute-v3.tfplan`, qui remplaçait
uniquement les cinq instances. Le state final confirme pour chacune :

- `power_state = active` ;
- `config_drive = true` ;
- image et flavor attendus ;
- adresse du port M05 conservée.

Le test administratif final a réussi :

```text
$ ssh -i ~/.ssh/tp_cloud ubuntu@<IP_BASTION> \
    'hostname; cloud-init status'
bastion-admin-01
status: done
```

La clé publique est donc injectée, le chemin SSH autorisé fonctionne et
cloud-init est terminé. Aucun UUID, IP ou secret n'est publié dans la preuve.

## Critère de clôture

M06 est terminée : les cinq instances sont actives et conformes à la baseline,
leurs ports M05 sont conservés et l'accès SSH au bastion est validé. M07 est
maintenant autorisée.
