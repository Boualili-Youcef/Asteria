# T05 — Landing zone et staging CAP-05

## But et statut

Créer dans le projet OpenStack secondaire un staging isolé de deux VM, sans
modifier le source. T05 est **en cours** : le code est préparé, mais aucun plan
authentifié ni apply n'est encore autorisé.

T05 traite `ASIS-020` et prépare `ASIS-001`, `ASIS-022`, `REQ-SEC-012`,
`REQ-DATA-009` et `REQ-SVC-011`. T04 est revalidée ; ADR-002, ADR-004 et ADR-014
gouvernent le périmètre.

## Faits, hypothèses et cible

Faits vérifiés par T02 : le secondaire est vide, limité à 4 instances, 4 vCPU
et 8 Go ; il voit `prive`, Ubuntu 24.04, le flavor `puissante`, une seule AZ et
aucun volume, objet, L3, LB ou DNS. CAP-05 consomme exactement 4 vCPU/8 Go avec
un control-plane et un worker de 2 vCPU/4 Go chacun.

Hypothèses bloquantes à revérifier avant apply : le bon OpenRC secondaire est
chargé, le projet reste vide, les quotas n'ont pas changé, la clé publique est
valide et le chemin source-bastion → staging fonctionne.

La référence entreprise sépare production, staging et services partagés avec
stockage durable et marge. Le lab crée seulement un staging non-HA, à données
synthétiques, sur disques root Nova. Il n'est ni green, ni backup, ni DR.

## Livrables et impact prévu

- `infra/terraform/openstack-staging/` : state et ressources du secondaire ;
- `infra/ansible/inventory/staging_terraform_inventory.sh` : inventaire source
  bastion + deux VM staging ;
- `infra/ansible/playbooks/t05-staging-foundations.yml` : NTP, config-drive et
  SSH limité au bastion ;
- ce runbook ; la preuve T05 ne sera créée qu'après résultats live.

Le plan nominal doit ajouter deux SG, deux ports, deux VM, une keypair et les
règles minimales. `config_drive=true`, `data_class=synthetic-only` et la règle
de probe est désactivée. Aucune ressource source n'est adressable par ce state.

## Pré-check et plan sans mutation

Charger l'OpenRC secondaire dans un terminal privé. Ne jamais transmettre le
mot de passe dans le chat ou le dépôt.

```bash
openstack token issue
openstack server list
openstack port list
openstack limits show --absolute

export TF_VAR_source_bastion_cidr='<IP_BASTION_SOURCE>/32'
export TF_VAR_expected_project_id="${OS_PROJECT_ID}"

terraform -chdir=infra/terraform/openstack-staging init
terraform -chdir=infra/terraform/openstack-staging fmt -check
terraform -chdir=infra/terraform/openstack-staging validate
terraform -chdir=infra/terraform/openstack-staging plan \
  -input=false -out=t05-staging.tfplan
terraform -chdir=infra/terraform/openstack-staging show \
  -json t05-staging.tfplan > /tmp/asteria-t05-plan.json
jq -e '[.resource_changes[].change.actions[]] | index("delete") == null' \
  /tmp/asteria-t05-plan.json
```

Arrêter si le projet n'est pas le secondaire attendu, si une VM/port compute
inattendu existe, si le quota libre est inférieur à CAP-05, si le plan contient
delete/replace, si le probe est actif ou si une ressource source apparaît.

Le provider est forcé sur `expected_project_id` et le scope Keystone doit
correspondre. Le script opérateur vérifie en plus, avant le plan, le profil
CAP-05 exact (4 VM, 4 vCPU, 8192 Mo), sa disponibilité et l'absence de VM/port.
Le data source Terraform `openstack_compute_limits_v2` n'est pas utilisé : la
policy du lab refuse sa requête `/limits?tenant_id=...` en `403`, tandis que la
commande CLI courante sans ce paramètre est autorisée.

Un apply exige une validation explicite du résumé exact du plan. Le fichier de
plan devient invalide dès que code, state ou inventaire cloud change.

Pour l'exécution opérateur approuvée de la création initiale, le script suivant
regroupe ces gates, refuse le mauvais profil de quotas, exige un projet vide et
n'applique que le plan exact de 14 créations :

```bash
scripts/t05-provision-staging.sh \
  /chemin/prive/compte-secondaire-openrc.sh \
  --apply
```

## Après apply autorisé

```bash
.venv/bin/ansible-inventory \
  -i infra/ansible/inventory/staging_terraform_inventory.sh --graph
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/staging_terraform_inventory.sh \
  infra/ansible/playbooks/t05-staging-foundations.yml --check --diff
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/staging_terraform_inventory.sh \
  infra/ansible/playbooks/t05-staging-foundations.yml
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/staging_terraform_inventory.sh \
  infra/ansible/playbooks/t05-staging-foundations.yml
```

Attendus : deux VM actives, config-drive présent, NTP synchronisé, ProxyJump
réussi, SSH direct refusé par `AllowUsers`, puis `changed=0` au second passage.

## Probe réseau et rollback de règle

Le test live a montré que le réseau provider du lab laisse atteindre un port
écouté malgré l'absence de règle Neutron correspondante. La règle Terraform de
probe reste donc désactivée : elle ne constituerait pas une preuve d'isolation.
T05 active UFW comme contrôle hôte compensatoire, avec entrée fermée par défaut.

Le script démarre un listener systemd transitoire borné, vérifie le refus depuis
le bastion et le contrôleur, ajoute uniquement une règle UFW depuis le bastion,
prouve le succès et le refus du contrôleur, supprime cette règle, vérifie le
nouveau refus puis arrête le listener :

```bash
scripts/t05-probe-connectivity.sh --run
```

## State, backup et rollback

Le state reste local au répertoire staging, ignoré par Git et en mode `0600`.
Après apply, l'exporter avec checksum hors Git :

```bash
scripts/t05-protect-terraform-state.sh \
  /home/youcef/.local/share/asteria/backups/t05-<timestamp>
```

Le rollback normal corrige la source puis recrée uniquement une ressource cible.
La destruction complète du staging est possible grâce à son state séparé, mais
exige un plan `-destroy`, la preuve qu'aucune donnée réelle n'existe et une
autorisation explicite. Le source et les backups T04 ne sont jamais touchés.

## Critères de clôture

T05 sera terminée seulement avec plan sans impact source, budget CAP-05 exact,
deux VM/config-drives validés, NTP/SSH idempotents, probe positif/négatif et
rollback de règle observés, state sauvegardé hors Git, scan secrets propre et
preuve `T05-target-landing-zone-ready.md`. Alors seulement T06 sera autorisée.

Ces critères ont été satisfaits le 31 août 2026. T05 est terminée ; T06 est la
prochaine mission autorisée.
