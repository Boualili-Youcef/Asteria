# Preuve M08 — PostgreSQL sur VM séparée

## Métadonnées

- **Date :** 2026-07-19
- **Mission :** M08
- **Statut :** réussi

## Objectif et résultat attendu

Installer un primaire PostgreSQL unique et non HA sur `db-postgres-01`, avec
une base et un compte séparés pour `identity-api`, `orders-api` et
`notifications-worker`. Les connexions applicatives doivent réussir depuis les
deux workers et être refusées depuis le bastion, le control plane et les autres
sources.

## Dépendances et faits vérifiés

- M07 est documentée comme terminée dans
  `docs/evidence/phase-1/M07-bastion-ready.md` ;
- l'inventaire reste dérivé de l'output Terraform M06 ;
- l'output local contient toujours une VM PostgreSQL, un control plane et deux
  workers ;
- le design M04 autorise TCP/5432 uniquement depuis le SG workers ;
- M07 a démontré que les références inter-SG du réseau provider ne suffisent
  pas seules comme frontière observable.

## Hypothèses contrôlées par l'automatisation

- les quatre VMs concernées utilisent Ubuntu 24.04 amd64 ;
- Ubuntu fournit PostgreSQL 16 ;
- la VM PostgreSQL et les nœuds Kubernetes disposent d'une sortie vers les
  dépôts Ubuntu ;
- les adresses de l'inventaire Terraform correspondent encore aux VMs actives.

Le playbook échoue explicitement si la plateforme, la version majeure ou la
topologie ne correspondent pas.

## Décisions

- PostgreSQL reste un primaire unique sans réplication ;
- les trois services utilisent des bases et rôles distincts, sans privilèges
  d'administration ;
- l'authentification distante utilise SCRAM-SHA-256 ;
- `pg_hba.conf` autorise chaque couple compte/base seulement depuis les deux
  IPs de workers puis rejette toute autre source ;
- les mots de passe sont générés localement dans `.secrets/m08-postgres/`,
  ignoré par Git, et ne sont jamais affichés ;
- la sauvegarde initiale reste locale et manuelle, sans test de restauration,
  afin de conserver la dette AS-IS visible.

## Fichiers livrés

- `infra/ansible/playbooks/m08-postgres.yml` ;
- `infra/ansible/scripts/m08-postgres-backup.sh` ;
- `infra/ansible/inventory/terraform_inventory.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/README.md` ;
- `.gitignore`.

## Validations locales exécutées

```bash
git diff --check
bash -n infra/ansible/inventory/terraform_inventory.sh
bash -n infra/ansible/scripts/m08-postgres-backup.sh
.venv/bin/ansible-inventory \
  -i infra/ansible/inventory/terraform_inventory.sh --graph
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m08-postgres.yml --syntax-check
```

Résultats : aucune erreur ; l'inventaire expose un groupe `postgres`, un
`control_plane` et exactement deux `workers`.

## Exécution distante et incident transitoire

Les contrôles SSH du 19 juillet 2026 expirent avant authentification :

```text
ssh: connect to host <IP_BASTION> port 22: Connection timed out
```

Le diagnostic local ne montrait alors aucune route ou interface VPN dédiée au
CIDR `172.28.0.0/16`. Après rétablissement de l'accès par l'utilisateur, SSH
vers le bastion et `ansible all -m ping` ont réussi sur les cinq VMs. Le
blocage était donc extérieur à l'automatisation M08.

La première capture Ansible s'est interrompue à l'écran pendant la tâche APT.
Un contrôle indépendant a ensuite confirmé PostgreSQL 16 installé, son cluster
`main` actif et l'absence de processus APT/dpkg résiduel. Le passage complet
suivant a démontré que les rôles, bases, fichiers et sauvegarde avaient été
créés, puis s'est terminé avec `failed=0` et `changed=0`.

## Commandes exécutées

```bash
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

.venv/bin/ansible all \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m08-postgres.yml
```

## Résultats observés

- PostgreSQL `16.14` est `active` et le test d'écoute TCP/5432 réussit ;
- `identity_db` appartient à `identity_app` ;
- `orders_db` appartient à `orders_app` ;
- `notifications_db` appartient à `notifications_app` ;
- six règles HBA utilisent SCRAM-SHA-256 : trois couples compte/base pour
  chacun des deux workers ;
- les six connexions positives réussissent : trois comptes depuis chacun des
  deux workers ;
- le même compte valide est refusé depuis le bastion et le control plane ;
- la sauvegarde initiale contient `globals.sql.gz`, les trois dumps et un
  fichier `SHA256SUMS` ;
- le répertoire distant de sauvegarde appartient à `postgres:postgres` en
  mode `0700`, et le fichier HBA en mode `0640` ;
- `.secrets/m08-postgres/` est en mode `0700`, les trois mots de passe en
  `0600` et l'ensemble apparaît seulement comme ignoré dans Git.

## Preuve d'idempotence

Le passage complet final donne :

| Hôte | `changed` | `failed` | Résultat fonctionnel |
|---|---:|---:|---|
| `db-postgres-01` | 0 | 0 | service, bases, HBA et sauvegarde conformes |
| `k8s-worker-01` | 0 | 0 | trois connexions autorisées réussies |
| `k8s-worker-02` | 0 | 0 | trois connexions autorisées réussies |
| `k8s-control-plane-01` | 0 | 0 | connexion valide refusée par sa source |
| `bastion-admin-01` | 0 | 0 | connexion valide refusée par sa source |

## Risques, limites et erreurs fréquentes

- SCRAM-SHA-256 protège l'authentification mais M08 n'impose pas TLS au trafic
  PostgreSQL ; ce risque reste une dette AS-IS pour M16 et la phase 2 ;
- la VM, les données et les sauvegardes initiales résident sur un primaire
  unique sans réplication ;
- la sauvegarde contient des données et des vérificateurs de mots de passe :
  son répertoire distant en mode `0700` ne doit jamais être copié dans Git ;
- aucune restauration n'est testée et aucune copie objet n'est automatisée ;
- supprimer les fichiers locaux `.secrets/m08-postgres/` sans sauvegarde
  empêche de retrouver les mots de passe courants ;
- utiliser un CIDR global à la place des deux IPs workers élargirait
  silencieusement l'accès à la base sur le réseau provider partagé.

## Conclusion

M08 est **Terminée**. PostgreSQL fonctionne sur sa VM séparée avec les trois
bases et comptes attendus, les flux positifs et négatifs sont démontrés, une
sauvegarde basique existe et l'automatisation est idempotente. M09 est
maintenant autorisée.
