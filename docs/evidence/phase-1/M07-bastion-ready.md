# Preuve M07 — Bastion d'administration prêt

## Métadonnées

- **Date :** 2026-07-19
- **Mission :** M07
- **Statut :** réussi

## Objectif et résultat attendu

Configurer `bastion-admin-01` de façon reproductible, y installer les outils
d'administration exigés et démontrer que les VMs internes sont administrables
via le bastion sans exposition SSH directe imprévue.

## Dépendances et faits vérifiés

- M06 est terminée ;
- les cinq VMs sont actives avec `config_drive = true` ;
- l'accès SSH au bastion avec la clé locale est fonctionnel ;
- les adresses des VMs proviennent de l'output Terraform M06 ;
- le bastion est la seule VM dont SSH accepte la source administrateur ;
- la clé privée, les identifiants OpenStack et les futurs kubeconfigs restent
  hors du dépôt.

## Hypothèses contrôlées par l'automatisation

- l'image M06 est Ubuntu sur architecture amd64 ;
- l'utilisateur cloud est `ubuntu` et dispose de `sudo` ;
- le bastion possède une sortie HTTPS pour les dépôts Ubuntu et les sources
  officielles des binaires.

Le playbook échoue explicitement si la distribution ou l'architecture ne
correspond pas.

## Décisions

- Ansible s'exécute depuis le poste administrateur, pas depuis le bastion ;
- l'inventaire est dérivé du state Terraform et ne duplique pas les IPs ;
- SSH ProxyJump donne accès aux nœuds internes sans copier la clé privée ;
- aucune nouvelle règle réseau ni exposition publique n'est créée en M07 ;
- une règle `AllowUsers` sur les VMs internes compense la source inter-SG non
  filtrée par le réseau provider pendant le test fonctionnel ;
- Terraform, kubectl et Helm sont installés dans des chemins versionnés ;
- les configurations OpenStack et Kubernetes sont laissées vides pour éviter
  toute persistance involontaire de secrets.

Ces choix reconstruisent le bastion AS-IS. Une éventuelle architecture Zero
Trust reste une étude de phase 2.

## Fichiers livrés

- `infra/ansible/ansible.cfg` ;
- `infra/ansible/inventory/terraform_inventory.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/playbooks/m07-bastion.yml` ;
- `infra/ansible/README.md`.

## Écart détecté avant clôture

Le premier test négatif a produit un succès SSH direct vers le control plane.
Le test a été rejoué sans fichier de configuration SSH local et la VM a confirmé
voir la source administrateur réelle, donc aucun ProxyJump implicite.

Le state Terraform confirme pourtant :

- `port_security_enabled = true` sur le port ;
- un seul SG attaché au control plane ;
- TCP/22 autorisé avec le SG bastion comme groupe distant.

L'écart est documenté dans `docs/phase-1-as-is/05-security-groups.md`. Le
playbook M07 impose désormais sur les quatre VMs internes
`AllowUsers ubuntu@<IP_BASTION>`. Ce contrôle ne prétend pas réparer Neutron ;
il protège le chemin d'administration réellement utilisé.

## Commandes de validation

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install ansible-core==2.21.2
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

.venv/bin/ansible-inventory \
  -i infra/ansible/inventory/terraform_inventory.sh --graph
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m07-bastion.yml --syntax-check
.venv/bin/ansible bastion \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping
```

## Exécution et résultat

Une première exécution a installé les paquets Ubuntu puis s'est arrêtée avant
les binaires versionnés : `terraform_version` n'était pas chargée depuis le
répertoire `group_vars`. Le playbook charge désormais explicitement ce fichier
avec `vars_files`. La relance a repris sans recréer les paquets présents et
s'est terminée avec `failed=0`.

Le test fonctionnel SSH a ensuite révélé l'écart Neutron décrit plus haut. Le
contrôle compensatoire `AllowUsers` a été appliqué aux quatre VMs internes, une
machine à la fois (`serial: 1`), sans perdre le chemin ProxyJump.

Commandes finales :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m07-bastion.yml

.venv/bin/ansible all \
  -i infra/ansible/inventory/terraform_inventory.sh \
  -m ansible.builtin.ping
```

Les versions suivantes ont été relevées sans donnée sensible : Terraform,
Ansible, kubectl, Helm, OpenStack CLI, psql, Git, jq et curl.

## Versions observées sur le bastion

| Outil | Version observée |
|---|---|
| Terraform | 1.15.8 |
| Ansible | core 2.16.3 |
| kubectl | 1.35.6 |
| Helm | 4.2.0 |
| OpenStack CLI | 6.6.0 |
| psql | 16.14 |
| Git | 2.43.0 |
| jq | 1.7 |
| curl | 8.5.0 |

Le contrôleur local reproductible utilise `ansible-core 2.21.2` dans `.venv`,
ignoré par Git. La version Ansible du bastion provient des dépôts Ubuntu de
l'image M06.

## Contrôles d'accès et de sécurité

Résultats observés :

- `ansible-inventory --graph` contient un bastion et quatre hôtes internes ;
- `ansible all -m ping` retourne `SUCCESS` et `pong` pour les cinq VMs ;
- le SSH direct vers le control plane, exécuté avec `ssh -F /dev/null`, retourne
  `Permission denied` après application du contrôle compensatoire ;
- `sshd -T` sur le bastion confirme `PermitRootLogin no`,
  `PasswordAuthentication no`, `KbdInteractiveAuthentication no` et
  `PubkeyAuthentication yes` ;
- `/home/ubuntu/.kube` et `/home/ubuntu/.config/openstack` appartiennent à
  `ubuntu:ubuntu`, sont en mode `0700` et restent vides ;
- aucune ressource Terraform ni règle Neutron n'a été modifiée par M07.

## Preuve d'idempotence

Le dernier passage complet donne `failed=0` et `changed=0` pour :

- `bastion-admin-01` ;
- `k8s-control-plane-01` ;
- `k8s-worker-01` ;
- `k8s-worker-02` ;
- `db-postgres-01`.

## Critères d'acceptation

- inventaire et syntaxe Ansible valides ;
- playbook réussi puis idempotent ;
- les neuf outils exigés répondent ;
- bastion accessible depuis la source d'administration autorisée ;
- VMs internes joignables en SSH seulement via ProxyJump ;
- aucune clé privée ou configuration d'authentification suivie par Git ;
- aucune règle réseau modifiée par M07.

## Risques et erreurs fréquentes

- lancer Ansible depuis un poste extérieur au CIDR autorisé ;
- supprimer ou remplacer le state Terraform utilisé par l'inventaire ;
- copier la clé privée sur le bastion ;
- commiter un OpenRC, `clouds.yaml` ou kubeconfig ;
- confondre la présence d'OpenStack CLI avec une authentification persistante.

## Conclusion

M07 est terminée. Le bastion fournit les neuf outils demandés, l'automatisation
est reproductible et idempotente, et les quatre VMs internes restent
administrables via ProxyJump tout en refusant la source SSH directe. M08 et M09
sont désormais autorisées ; l'ordre chronologique retient M08 en premier.
