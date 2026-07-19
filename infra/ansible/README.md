# Automatisation Ansible Asteria

## But de M07

Cette automatisation transforme `bastion-admin-01` en point
d'administration reproductible sans modifier l'architecture AS-IS. Ansible est
exécuté depuis le poste administrateur. Les autres VMs sont atteintes par un
tunnel SSH `ProxyJump` passant par le bastion et leur serveur SSH refuse la
source administrateur directe.

La clé privée reste sur le poste local. Aucun OpenRC, `clouds.yaml`, mot de
passe, token ou kubeconfig n'est copié automatiquement sur le bastion.

## Fichiers

- `ansible.cfg` : paramètres SSH communs et inventaire par défaut ;
- `inventory/terraform_inventory.sh` : inventaire dynamique construit depuis
  l'output Terraform `compute_instances` ;
- `group_vars/all.yml` : versions contrôlées des outils téléchargés ;
- `playbooks/m07-bastion.yml` : configuration idempotente du bastion et du
  chemin SSH des VMs internes.

## Prérequis locaux

Exécuter les commandes depuis la racine du dépôt :

```bash
test -f ~/.ssh/tp_cloud
chmod 600 ~/.ssh/tp_cloud
terraform -chdir=infra/terraform/openstack output compute_instances

python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install ansible-core==2.21.2

export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"
```

Le venv est ignoré par Git. Pour employer une autre clé ou un autre utilisateur
sans modifier les fichiers suivis :

```bash
export ASTERIA_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/autre-cle"
export ASTERIA_SSH_USER="ubuntu"
```

## Validation avant exécution

```bash
.venv/bin/ansible-inventory \
  -i infra/ansible/inventory/terraform_inventory.sh --graph

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m07-bastion.yml --syntax-check

.venv/bin/ansible bastion \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping
```

## Configuration du bastion

Cette commande installe les outils sur `bastion-admin-01`, puis applique sur les
quatre VMs internes une restriction SSH exigeant le passage par le bastion :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m07-bastion.yml
```

Le playbook installe OpenStack CLI, Terraform, Ansible, kubectl, Helm, psql,
Git, jq et curl. Il protège aussi l'accès SSH par clé et prépare des répertoires
vides pour les futures configurations OpenStack et Kubernetes.

La restriction SSH interne est un contrôle compensatoire du lab : M07 a
observé que le réseau provider acceptait une connexion directe depuis le poste
administrateur malgré la règle Neutron référant uniquement le SG bastion. Elle
n'ajoute ni règle Terraform, ni pare-feu applicatif anticipant M08/M09.

## Validations après exécution

Tester le bastion, puis les quatre VMs internes via ProxyJump :

```bash
.venv/bin/ansible all \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping

# Le même test sans ProxyJump doit être refusé par sshd sur la VM interne.
ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=4 \
  -i ~/.ssh/tp_cloud ubuntu@<IP_INTERNE> true

.venv/bin/ansible bastion \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.shell \
  -a 'terraform version; ansible --version; kubectl version --client; helm version --short; openstack --version; psql --version; git --version; jq --version; curl --version'
```

Rejouer enfin le playbook. Le récapitulatif attendu est `changed=0`. Un secret
OpenStack ne doit être injecté que ponctuellement dans une session autorisée,
jamais enregistré dans ce dépôt ni copié par ce playbook.

## M08 — PostgreSQL primaire hors cluster

### But et résultat attendu

`m08-postgres.yml` installe PostgreSQL 16 sur `db-postgres-01`, puis crée une
base et un compte distincts pour chacun des trois services :

| Service | Compte | Base |
|---|---|---|
| `identity-api` | `identity_app` | `identity_db` |
| `orders-api` | `orders_app` | `orders_db` |
| `notifications-worker` | `notifications_app` | `notifications_db` |

Les comptes ne sont ni superutilisateurs, ni autorisés à créer des rôles ou
des bases. PostgreSQL écoute sur la boucle locale et l'adresse privée de sa VM.
`pg_hba.conf` accepte en SCRAM-SHA-256 uniquement les bonnes combinaisons
compte/base depuis les deux adresses de workers, puis rejette toute autre
source. Ce contrôle complète les security groups du lab dont M07 a démontré la
limite sur le réseau provider partagé.

### Gestion des secrets

Au premier passage, Ansible génère trois mots de passe aléatoires persistants
dans `.secrets/m08-postgres/` sur le poste contrôleur. Le répertoire est ignoré
par Git, en mode `0700`, et chaque fichier est en mode `0600`. Aucun mot de
passe n'est affiché par le playbook ni copié dans une preuve.

Ces fichiers doivent être sauvegardés dans un gestionnaire de secrets autorisé
avant M13. Supprimer `.secrets/` sans sauvegarde rend les mots de passe
irrécupérables ; le playbook échouera alors aux tests au lieu de remplacer
silencieusement les identifiants en base.

Pour choisir un autre emplacement local protégé :

```bash
export ASTERIA_POSTGRES_SECRET_DIR="/chemin/protege/m08-postgres"
```

Une rotation intentionnelle utilise les valeurs déjà présentes dans ce
répertoire :

```bash
export ASTERIA_POSTGRES_ROTATE_PASSWORDS=true
```

Remettre cette variable à `false` après la rotation.

### Exécution et validation

Depuis la racine du dépôt, après les exports Ansible communs :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m08-postgres.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m08-postgres.yml
```

Le playbook vérifie lui-même :

- le service et l'écoute TCP/5432 ;
- la connexion de chaque compte à sa base depuis chaque worker ;
- le refus d'un compte pourtant valide depuis le bastion et le control plane ;
- les propriétaires des bases et les permissions locales des secrets ;
- la création d'une sauvegarde initiale.

Le script `/usr/local/sbin/asteria-postgres-backup` produit localement les
globals et trois dumps dans `/var/backups/asteria-postgresql/`. Il est manuel,
sans copie objet, alerte, rotation ou test de restauration : cette limite AS-IS
reste volontairement visible.

M08 n'impose pas TLS aux connexions PostgreSQL : SCRAM protège
l'authentification, mais ne chiffre pas à lui seul tout le trafic applicatif.
Ce risque sur l'underlay privé plat doit rester visible pour l'audit M16 et une
éventuelle correction en phase 2 ; il ne justifie pas d'anticiper une PKI dans
la phase courante.

Rejouer le playbook avec les mêmes secrets. Les tâches persistantes attendues
doivent indiquer `changed=0`.

## M09 — Cluster K3s réduit

### But et décisions

`m09-k3s.yml` installe un cluster K3s à trois nœuds : un control plane non HA
et exactement deux workers, conformément à la baseline M03/M04. La version
stable vérifiée le 19 juillet 2026 est figée à `v1.36.2+k3s1`. Le script
d'installation provient du tag Git correspondant et sa somme SHA-256 est
contrôlée avant exécution.

La configuration conserve Flannel VXLAN avec les CIDR validés
`10.42.0.0/16` pour les Pods et `10.43.0.0/16` pour les Services. Traefik et
ServiceLB sont désactivés : ingress-nginx et les NodePorts 30080/30443 restent
le travail de M10. Le control plane reçoit une taint pour que les futures
applications restent sur les workers autorisés à joindre PostgreSQL.

Le token agent reste dans des fichiers root `0600` sur les nœuds. Le
kubeconfig administrateur est copié directement par Ansible du control plane
vers `/home/ubuntu/.kube/config` sur le bastion, en mode `0600`. Aucun token ou
kubeconfig n'est écrit dans le dépôt.

Ce kubeconfig conserve des privilèges d'administration larges, sans rotation
automatisée. Le control plane, le datastore K3s et le kubeconfig n'ont aucune
redondance : ce sont des limites AS-IS à auditer, pas des caractéristiques de
la future architecture TO-BE.

### Exécution

M08 doit être terminée avant de suivre l'ordre chronologique retenu, même si
M09 dépend techniquement de M07 dans le backlog :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m09-k3s.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m09-k3s.yml
```

Le playbook attend les trois nœuds `Ready`, relève les nœuds et Pods, puis
exécute un test éphémère. Deux Pods BusyBox sont placés sur des workers
différents ; le test contrôle DNS, l'overlay inter-workers et TCP/5432 depuis
un Pod vers la VM PostgreSQL. Le namespace `m09-connectivity` est supprimé
automatiquement, y compris après une erreur.

### Procédure opératoire depuis le bastion

```bash
ssh -i ~/.ssh/tp_cloud ubuntu@<IP_BASTION>

stat -c '%U:%G %a %n' ~/.kube ~/.kube/config
kubectl get nodes -o wide
kubectl get pods -A -o wide
sudo /usr/local/sbin/asteria-m09-validate-overlay
```

Résultat attendu : un control plane et deux workers `Ready`, les composants
système K3s fonctionnels, aucun Traefik/ServiceLB, et le message
`M09 connectivity checks passed`. Rejouer enfin le playbook ; hors test
éphémère nettoyé, la configuration persistante attendue est idempotente.
