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
