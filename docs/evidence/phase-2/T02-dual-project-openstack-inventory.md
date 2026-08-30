# Preuve T02 — Inventaire dual-project OpenStack

## Métadonnées

- **Date d'ouverture :** 2026-08-30
- **Mission :** T02
- **Statut :** terminée
- **Périmètre actuel :** inventaires live, capacité et préparation du probe
- **Runtime modifié :** non

## Objectif

Réinventorier les capacités et consommations réelles des deux projets, tester
leur connectivité, puis choisir leurs rôles, le sizing et la cible logique des
sauvegardes sans extrapoler l'inventaire M03.

## Inspection locale observée

```bash
openstack --version
terraform -chdir=infra/terraform/openstack state list
env | cut -d= -f1 | rg '^OS_' | sort
git status --short --branch
```

Résultats :

- client `openstack 6.6.0` disponible ;
- state Terraform local : 39 objets, dont les cinq VM/ports/SG attendus ;
- aucun contexte `OS_*` chargé dans l'environnement Codex ; les deux collectes
  authentifiées ont été exécutées par l'opérateur avec des OpenRC séparés ;
- quatre fichiers AS-IS préexistants restent hors périmètre T02.

Le state local et les preuves M03/M06 sont historiques : ils ne remplacent pas
les sorties live exigées par cette mission.

## Livrables préparés

- `scripts/t02-collect-openstack-inventory.sh` ;
- `docs/phase-2-to-be/07-dual-project-openstack-inventory.md` ;
- `docs/phase-2-to-be/08-t02-inventory-runbook.md` ;
- `infra/terraform/openstack-t02-probe/` ;
- cette preuve en cours.

## Résultats live neutralisés

Les deux collectes authentifiées datées du 30 août 2026 réussissent sur les
sections cœur.

| Capacité | Source | Secondaire |
|---|---:|---:|
| Instances | 5/8 | 2/4 |
| vCPU | 9/10 | 4/4 |
| RAM | 17/20 Go | 8/8 Go |
| Ports | 5/500 | 2/500 |
| Security groups | 8/10 | 1/10 |
| Règles SG | 37/100 | 4/100 |
| AZ compute | `nova` uniquement | `nova` uniquement |

Constats supplémentaires :

- mêmes flavors, image Ubuntu 24.04 et réseau provider partagé dans les deux
  projets ;
- aucune capacité L3/router ou Floating IP, appels HTTP 404 ;
- catalogue limité à Network, Placement, Identity, Image et Compute ;
- aucun endpoint Cinder, Swift, Octavia ou Designate ;
- config-drive confirmé sur les cinq VM source, non utilisé par les deux VM du
  second projet ;
- le second projet est occupé par deux VM CKA et ne possède actuellement plus
  aucun vCPU ou RAM libre.

La déclaration antérieure de 10 vCPU/20 Go pour le second compte est réfutée
par le quota authentifié : 4 vCPU/8 Go. Un cluster green complet n'y tient pas,
même vide. Le rôle retenu sous condition est un staging léger à deux nœuds ; la
production lab reste dans le projet source avec transformation progressive.

Le cloud ne fournit aucune cible de sauvegarde durable indépendante. Une cible
externe à cet OpenStack doit être décidée en T03.

Le 30 août 2026, le propriétaire a déclaré `cka-cp` et `cka-worker1` jetables,
a accepté la perte de leurs disques root et a autorisé leur suppression. Cette
décision valide CAP-05 et le futur rôle de staging léger du second projet ; elle
ne valait pas encore preuve de suppression.

L'opérateur a ensuite indiqué avoir supprimé toutes les ressources du second
projet. Cette suppression rend le probe positif impossible dans T02.

Le contrôle authentifié post-suppression confirme :

```text
servers=0
instances=0/4
cores=0/4
ram_mb=0/8192
ports=0/500
security_groups=1/10
security_group_rules=4/100
```

La liste des serveurs et des ports est vide. Seul le security group `default`
subsiste, avec ses quatre règles. Aucun identifiant n'est reproduit dans cette
preuve.

## Validations déjà exécutées

```bash
bash -n scripts/t02-collect-openstack-inventory.sh
./scripts/t02-collect-openstack-inventory.sh source /tmp/asteria-t02/source
```

- syntaxe Bash : succès ;
- test négatif sans OpenRC : refus avec code `78` avant toute commande cloud ;
- simulation complète : 35 sections enregistrées, zéro échec cœur ;
- simulation d'une absence Octavia : section marquée en erreur, collecte
  globale conservée avec code `0` ;
- simulation d'un échec du quota compute : arrêt final avec code `2` ;
- test de neutralisation : UUID avec ou sans tirets et URL factices absents du
  rapport produit ;
- sortie dans le dépôt : interdite par le script ;
- permissions des rapports : `umask 077` ;
- commandes de collecte : lecture seule ;
- UUID, endpoints et IDs de projet : neutralisés dans le rapport privé.

Écart détecté pendant l'analyse réelle : l'identifiant historique de projet
OpenStack utilise 32 caractères hexadécimaux sans tirets et n'était pas couvert
par le premier motif UUID. Il est resté exclusivement dans les rapports privés
`/tmp`, jamais dans Git. Le collecteur et le contrôle du runbook neutralisent
désormais aussi ce format. La revalidation avec trois valeurs factices produit
uniquement `[REDACTED_UUID]`, `[REDACTED_HEX_ID]` et
`[REDACTED_ENDPOINT]`. La preuve publique ne reproduit aucun identifiant.

Le module de connectivité a également passé :

```bash
terraform -chdir=infra/terraform/openstack-t02-probe fmt -check -recursive
terraform -chdir=infra/terraform/openstack-t02-probe init -backend=false
terraform -chdir=infra/terraform/openstack-t02-probe validate
```

- provider OpenStack verrouillé en `3.4.0` ;
- initialisation : succès ;
- validation statique : succès ;
- plan non exécuté, car aucun OpenRC cible n'est disponible dans
  l'environnement Codex.

Le contrôle réseau initial en lecture seule a ensuite donné :

```text
source_bastion_to_target_tcp22_rc=1
source_bastion_to_target_tcp6443_rc=1
```

- le bastion source est joignable par SSH avec sa clé et sa host key connues ;
- TCP/22 et TCP/6443 vers le control plane secondaire sont refusés avant ajout
  de la règle temporaire ;
- l'accès SSH direct au control plane secondaire depuis l'environnement Codex
  expire, donc le listener 6443 n'a pas encore pu être contrôlé séparément ;
- ce résultat prouve le refus initial, pas encore le fonctionnement du chemin
  après autorisation explicite.

## Écart et dette acceptée

Les endpoints cibles ont été supprimés avant le plan et l'apply du probe. Le
refus initial est observé, mais aucun succès après autorisation n'est prouvé.
Le module ne doit plus être appliqué dans T02 sans VM cible. T05 devra faire du
test TCP/22 positif, du refus d'un port non autorisé et du rollback de règle des
critères bloquants avant de déclarer le staging utilisable.

## Validation finale

- liste des serveurs : vide ;
- compute : 0/4 instance, 0/4 vCPU et 0/8 Go de RAM utilisés ;
- ports : 0/500 ;
- security groups : uniquement `default`, 1/10 ;
- règles de security group : 4/100 ;
- aucune capacité résiduelle ou ressource inattendue observée ;
- probe non appliqué et dette de connectivité transférée explicitement à T05.

## Impact, rollback et arrêt

Aucune ressource n'a été modifiée par Codex. L'opérateur a vidé le second projet
après avoir accepté la perte des deux VM CKA. Le probe préparé n'a pas été
appliqué et reste une base de test pour T05. L'inventaire post-suppression
confirme la libération de 2 instances, 4 vCPU, 8 Go et des deux ports compute.

## Conclusion provisoire

T02 est **terminée**. Le projet source conserve le lab principal ; le projet
secondaire vide est réservé à CAP-05, staging Kubernetes léger de deux nœuds.
Le test inter-projets non exécuté devient une dette bloquante de T05. T03 est
autorisée.
