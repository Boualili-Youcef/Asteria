# Preuve M09 — Cluster Kubernetes prêt

## Métadonnées

- **Date :** 2026-07-19
- **Mission :** M09
- **Statut :** réussi

## Objectif et résultat attendu

Installer le cluster Kubernetes réduit de la baseline : un control plane K3s
non HA et deux workers, sur l'underlay provider OpenStack existant. Le cluster
doit être administrable uniquement depuis le bastion avec un kubeconfig
protégé, et les flux API, DNS, Flannel et PostgreSQL requis doivent fonctionner.

## Dépendances et prérequis vérifiés

- M07 fournit le bastion et le chemin SSH ProxyJump ;
- M08 est terminée et PostgreSQL accepte TCP/5432 depuis les workers ;
- les cinq VMs répondent avec `ansible all -m ping` ;
- l'inventaire Terraform contient exactement un control plane et deux workers ;
- les trois nœuds utilisent Ubuntu 24.04 amd64 et aucun swap n'est actif ;
- les SG M04 autorisent TCP/6443, TCP/10250 et UDP/8472 selon les rôles.

## Faits et hypothèses

Faits observés avant installation : trois nœuds accessibles, sortie HTTPS
fonctionnelle et aucun service K3s existant. La version stable publiée a été
vérifiée le 19 juillet 2026 avec l'API GitHub officielle.

Hypothèses contrôlées par le playbook : interface de routage par défaut adaptée
à Flannel, modules noyau `overlay` et `br_netfilter` disponibles, et accès aux
sources officielles K3s. Le playbook échoue si la plateforme, le swap ou la
topologie divergent.

## Décisions

- K3s est figé à `v1.36.2+k3s1` ;
- le script `install.sh` provient du tag Git de cette version et son SHA-256 est
  vérifié avant exécution ;
- le cluster conserve un seul serveur K3s et son datastore local par défaut ;
- Flannel utilise VXLAN avec `10.42.0.0/16` pour les Pods ;
- les Services utilisent `10.43.0.0/16` ;
- Traefik et ServiceLB sont désactivés pour laisser ingress-nginx et les
  NodePorts à M10 ;
- le control plane porte une taint `NoSchedule` pour les futures applications ;
- les composants système K3s peuvent conserver leurs tolérations et s'exécuter
  sur le control plane ;
- le token agent n'est jamais écrit dans Git ou dans une sortie Ansible ;
- le kubeconfig est transféré directement au bastion et n'est pas conservé sur
  le contrôleur local.

## Fichiers livrés

- `infra/ansible/playbooks/m09-k3s.yml` ;
- `infra/ansible/scripts/m09-validate-overlay.sh` ;
- `infra/ansible/inventory/terraform_inventory.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/README.md`.

## Commandes exécutées

```bash
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m09-k3s.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m09-k3s.yml
```

Le playbook a ensuite été rejoué intégralement pour l'idempotence.

## Résultats observés

### Nœuds et services

| Nœud | Rôle observé | État | Version |
|---|---|---|---|
| `k8s-control-plane-01` | `control-plane` | `Ready` | `v1.36.2+k3s1` |
| `k8s-worker-01` | agent/worker | `Ready` | `v1.36.2+k3s1` |
| `k8s-worker-02` | agent/worker | `Ready` | `v1.36.2+k3s1` |

`k3s.service` est actif sur le control plane. `k3s-agent.service` est actif sur
les deux workers. Aucun nœud ne porte d'adresse externe Kubernetes.

### Pods système

Les composants suivants sont `Running` et `Ready` dans `kube-system` :

- CoreDNS ;
- local-path-provisioner ;
- metrics-server.

Aucun Pod Traefik ou `svclb` n'est présent. Le control plane porte la taint
`NoSchedule` attendue ; les Pods système la tolèrent, mais les futures
applications ordinaires seront dirigées vers les workers.

### Secrets et kubeconfig

- `/etc/rancher/k3s/config.yaml` est `root:root` en mode `0600` sur chaque
  nœud ;
- les fichiers de token copiés sur les workers sont `root:root` en `0600` ;
- le lien `agent-token` du serveur résout vers le token K3s `root:root` en
  `0600` ;
- `/home/ubuntu/.kube` est `ubuntu:ubuntu` en `0700` sur le bastion ;
- `/home/ubuntu/.kube/config` est `ubuntu:ubuntu` en `0600` ;
- aucun token ou kubeconfig n'apparaît dans `git status`.

## Tests de connectivité

Le script `/usr/local/sbin/asteria-m09-validate-overlay` a été exécuté depuis le
bastion par le playbook. Il crée temporairement un Pod BusyBox sur chaque
worker, puis contrôle :

1. la résolution de `kubernetes.default.svc.cluster.local` ;
2. le ping entre deux IPs de Pods situés sur des workers différents ;
3. l'ouverture TCP/5432 depuis un Pod vers la VM PostgreSQL ;
4. la suppression du namespace `m09-connectivity`, même après une erreur.

Le script est sorti avec le code `0` pendant les deux passages. Le contrôle
final confirme que le namespace temporaire est absent.

Les commandes exigées par le backlog ont également réussi depuis le bastion :

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

## Preuve d'idempotence

Le second passage complet donne :

| Hôte | `changed` | `failed` |
|---|---:|---:|
| `bastion-admin-01` | 0 | 0 |
| `k8s-control-plane-01` | 0 | 0 |
| `k8s-worker-01` | 0 | 0 |
| `k8s-worker-02` | 0 | 0 |

Les tâches d'installation sont ignorées car la version et les services attendus
existent. Le test éphémère est recréé puis nettoyé sans modifier la
configuration persistante.

## Critères d'acceptation

- automatisation syntaxiquement valide et exécution sans échec ;
- un control plane non HA et exactement deux workers `Ready` ;
- services K3s actifs et même version sur les trois nœuds ;
- kubeconfig utilisable depuis le bastion et protégé en `0600` ;
- Pods système fonctionnels ;
- DNS, overlay inter-workers et accès PostgreSQL testés ;
- Traefik/ServiceLB non anticipés ;
- second passage sans changement persistant.

## Risques, limites et erreurs fréquentes

- le control plane et le datastore K3s local ne sont pas hautement disponibles ;
- le kubeconfig du bastion donne des privilèges d'administration larges et sa
  rotation n'est pas automatisée ;
- aucun mécanisme de sauvegarde/restauration K3s n'est testé en M09 ;
- les NetworkPolicies et le RBAC restent incomplets conformément à l'AS-IS ;
- l'egress des nœuds reste large ;
- UDP/8472 ne doit jamais être ouvert au-delà des nœuds Kubernetes ;
- changer les CIDR Pods/Services ou la version sur un cluster existant demande
  un plan de migration et ne doit pas être tenté par simple relance.

## Conclusion et prochaine mission

M09 est **Terminée**. Le cluster réduit est fonctionnel, reproductible et
administrable depuis le bastion, avec les flux requis démontrés. M10 — installer
ingress-nginx et préparer les namespaces — est maintenant la prochaine mission
autorisée.
