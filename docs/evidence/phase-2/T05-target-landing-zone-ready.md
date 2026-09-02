# Preuve T05 — Landing zone et staging CAP-05 prêts

## Résultat

- **Date :** 31 août 2026
- **Mission :** T05
- **Statut :** terminée
- **Traite/prépare :** `ASIS-020`, `ASIS-001`, `ASIS-022`, `REQ-SEC-012`,
  `REQ-DATA-009`, `REQ-SVC-011`
- **Dépendances :** T02, ADR-002, ADR-004, ADR-014 et T04 terminées

Le projet OpenStack secondaire héberge un staging isolé de deux VM actives. Le
budget de 4 vCPU et 8192 Mo est entièrement consommé, sans prétention HA, DR,
backup ou green de production. Le projet source reste opérationnel avec ses cinq
VM historiques.

## Faits vérifiés

- plan final : `14 added, 0 changed, 0 destroyed` ;
- control-plane et worker : Ubuntu 24.04, flavor 2 vCPU/4 Go, config-drive ;
- state indépendant en mode `0600`, 14 ressources gérées et 4 data sources ;
- accès Ansible réussi uniquement via le bastion ; SSH direct refusé, puis TCP/22
  direct bloqué après activation du pare-feu hôte ;
- `NTPSynchronized=yes`, config-drive `config-2`, root/password SSH interdits ;
- UFW actif avec politique entrante `deny` et sorties autorisées ;
- second passage Ansible : `changed=0`, `unreachable=0`, `failed=0` sur les deux
  VM ;
- probe TCP/18080 : refus initial, succès limité au bastion, contrôleur refusé,
  règle supprimée, refus final et listener arrêté ;
- `connectivity_probe_enabled=false` dans le state final.

## Hypothèses et limites

La référence entreprise conserve des projets production/staging/services
partagés, de la marge, du stockage durable et des domaines de panne. Le lab est
un staging non-HA à données synthétiques, sans Cinder/objet/LB/DNS et sans marge
CPU/RAM. T07 devra étendre explicitement le pare-feu aux flux K3s/Cilium retenus.

Le réseau provider ne respecte pas l'isolation attendue des security groups pour
un port écouté non déclaré. Ce résultat live interdit de présenter Neutron comme
contrôle suffisant. UFW est le contrôle compensatoire lab ; l'entreprise doit
conserver une segmentation réseau effectivement appliquée et vérifiée.

## Incident, rollback et correction de source

Le premier plan, pourtant limité à 14 créations, a été exécuté avec l'OpenRC du
projet source. Les deux VM ont échoué sur ses quotas après la création de 12
ressources partielles : deux SG, sept règles, deux ports et une keypair. Aucune
VM ni donnée staging n'a été créée.

Le state partiel et le plan de nettoyage ont été sauvegardés hors Git. Un plan
de rollback exact (`0 added, 0 changed, 12 destroyed`) a été inspecté puis
appliqué. Le state est revenu vide et le source à ses cinq VM initiales.

La correction empêche une répétition :

- `expected_project_id` est obligatoire et force le `tenant_id` du provider ;
- le scope Keystone authentifié doit correspondre à cet ID, sans stocker le
  token dans le state ;
- `scripts/t05-provision-staging.sh` exige le profil CAP-05 exact, un projet vide
  et un plan de 14 créations sans autre action ;
- le data source de limites Terraform n'est pas retenu, car la policy du lab
  refuse sa requête avec `tenant_id` en `403`; le pré-check CLI autorisé assure
  ce contrôle avant le plan.

## Commandes et résultats observables

```bash
scripts/t05-provision-staging.sh <OPENRC_SECONDAIRE> --apply
# GATE T05 PASS
# Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/staging_terraform_inventory.sh \
  infra/ansible/playbooks/t05-staging-foundations.yml
# chaque VM : changed=0, unreachable=0, failed=0 au dernier passage

scripts/t05-probe-connectivity.sh --run
# PASS: refus initial depuis le bastion et le contrôleur.
# PASS: succès limité au bastion pendant la règle temporaire.
# PASS: refus initial, succès contrôlé et refus après rollback sur TCP/18080.

scripts/t05-protect-terraform-state.sh \
  /home/youcef/.local/share/asteria/backups/t05-20260831-closure
# state serial 46, 14 ressources gérées, 4 data sources
```

La sauvegarde privée contient le state, le lockfile, les métadonnées et un
catalogue SHA-256. Chaque fichier est en mode `0600` et les checksums passent.
Le fichier `known_hosts` staging est séparé du fichier global afin de traiter la
réutilisation d'adresses IP OpenStack sans supprimer une ancienne empreinte.

## Acceptation et suite

| Gate | Résultat |
|---|---|
| projet secondaire et state séparés | validé |
| plan sans destruction du source | validé après rollback documenté |
| budget CAP-05 et deux config-drives | validé |
| ProxyJump, NTP, SSH et UFW | validé |
| test négatif, positif et rollback réseau | validé |
| idempotence `changed=0` | validé |
| state privé sauvegardé et checksums | validé |
| secrets absents du dépôt | validé |

T05 est terminée. La prochaine mission autorisée est T06, accès
d'administration Zero Trust ; le bastion reste le break-glass pendant cette
transition.
