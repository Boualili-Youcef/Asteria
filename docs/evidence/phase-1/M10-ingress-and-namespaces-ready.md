# Preuve M10 — Ingress et namespaces prêts

## Métadonnées

- **Date :** 2026-07-20
- **Mission :** M10
- **Statut :** réussi

## Objectif et résultat attendu

Créer l'entrée commune AS-IS du cluster et son découpage logique. Le résultat
attendu est un contrôleur ingress-nginx disponible sur les deux workers, les
cinq namespaces métier/plateforme demandés, et un endpoint accessible par le
chemin provider/NodePort autorisé sans créer de LoadBalancer cloud.

## Dépendances et prérequis vérifiés

- M09 est terminée ; le control plane et les deux workers sont `Ready` ;
- Traefik et ServiceLB K3s sont désactivés ;
- le kubeconfig protégé du bastion fonctionne ;
- les NodePorts 30080 et 30443 ont été réservés par M04 ;
- le chart ingress-nginx `4.15.1` est compatible avec Kubernetes 1.36 et rend
  le contrôleur `v1.15.1`.

## Faits, hypothèses et décisions

Le lab ne fournit ici ni Octavia ni Floating IP dédiée à l'Ingress. Le chemin
réel retenu est donc : bastion sur le réseau provider, adresse du worker, puis
NodePort 30080/30443. Ce choix décrit l'AS-IS et ne préjuge pas de la cible.

Décisions appliquées :

- deux contrôleurs en `Deployment`, contraints sur des workers différents ;
- Service `NodePort`, sans IP externe ni état LoadBalancer ;
- `externalTrafficPolicy: Local` ;
- admission webhook actif et annotations snippets désactivées ;
- endpoint BusyBox dédié à la validation, sans secret ni exposition métier ;
- six namespaces suivis par manifest : `ingress-nginx`, `team-identity`,
  `team-orders`, `team-notifications`, `shared` et `monitoring` ;
- filtrage compensatoire des NodePorts sur les workers, limité à la source
  `/32` du bastion.

Le dépôt officiel ingress-nginx est archivé depuis mars 2026. La version est
figée pour reproduire l'architecture AS-IS ; son remplacement est une dette de
phase 2 et non un changement autorisé dans M10.

## Fichiers livrés

- `k8s/current-state/ingress-nginx/namespaces.yaml` ;
- `k8s/current-state/ingress-nginx/values.yaml` ;
- `k8s/current-state/ingress-nginx/test-endpoint.yaml` ;
- `infra/ansible/playbooks/m10-ingress.yml` ;
- `infra/ansible/scripts/m10-nodeport-firewall.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/README.md` ;
- `docs/phase-1-as-is/05-security-groups.md`.

## Commandes exécutées

```bash
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

bash -n infra/ansible/scripts/m10-nodeport-firewall.sh

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m10-ingress.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m10-ingress.yml
```

Le playbook complet a ensuite été rejoué pour vérifier l'idempotence.

## Résultats observés

### Contrôleur et endpoint

| Ressource | État observé | Placement/exposition |
|---|---|---|
| `ingress-nginx-controller` | `2/2` disponibles | un Pod sur chaque worker |
| `m10-test-endpoint` | `1/1` disponible | Service `ClusterIP` |
| Ingress `m10-test-endpoint` | classe `nginx` | hôte `m10.asteria.local` |

L'image observée du contrôleur est
`registry.k8s.io/ingress-nginx/controller:v1.15.1` avec digest. Les deux Pods
sont `Running`, sans redémarrage.

Le Service du contrôleur montre :

```text
type=NodePort externalIP= loadBalancer= ports=http:30080 https:30443
```

Il n'existe donc ni IP externe Kubernetes ni ressource LoadBalancer attachée à
ce Service.

### Namespaces

Les six namespaces attendus sont `Active` :

```text
ingress-nginx
team-identity
team-orders
team-notifications
shared
monitoring
```

### Chemins réseau positif et négatif

Depuis le bastion, les requêtes HTTP et HTTPS sur chacun des deux workers ont
répondu avec le statut 200 et le contenu :

```text
M10 ingress endpoint ready
```

Le premier test depuis le poste administrateur a révélé que les NodePorts
étaient joignables malgré la référence au SG bastion. Après installation du
contrôle compensatoire, les quatre tests directs ont échoué par timeout :

```text
worker-01:30080 rc=28
worker-01:30443 rc=28
worker-02:30080 rc=28
worker-02:30443 rc=28
```

Sur les deux workers, `asteria-nodeport-firewall.service` est `active` et
`enabled`. La table `raw` contient une règle PREROUTING pour 30080/30443, une
autorisation du bastion `/32`, puis un rejet des autres sources.

## Preuve d'idempotence

Le second passage complet donne :

| Hôte | `changed` | `failed` |
|---|---:|---:|
| `bastion-admin-01` | 0 | 0 |
| `k8s-worker-01` | 0 | 0 |
| `k8s-worker-02` | 0 | 0 |

Le rendu du chart est recalculé mais sa réapplication est ignorée lorsque la
version et le checksum des valeurs correspondent à l'état enregistré.

## Critères d'acceptation

- chart et manifests rendus/appliqués sans LoadBalancer cloud ;
- deux contrôleurs disponibles sur deux workers distincts ;
- cinq namespaces demandés et namespace technique `ingress-nginx` actifs ;
- NodePorts 30080/30443 observés ;
- endpoint HTTP/HTTPS accessible depuis le bastion sur les deux workers ;
- accès direct hors bastion refusé après compensation ;
- second passage sans changement persistant.

## Risques, limites et erreurs fréquentes

- ingress-nginx est archivé et n'offre plus une trajectoire de maintenance
  satisfaisante ; ce risque AS-IS doit être traité en phase 2 ;
- le HTTPS de test utilise le certificat par défaut du contrôleur, pas un
  certificat DNS de production ;
- l'entrée dépend d'adresses de workers et de NodePorts, sans VIP ni haute
  disponibilité externe ;
- le filtrage host compense un comportement observé de Neutron, mais ne corrige
  pas globalement le réseau provider ;
- les NetworkPolicies et le RBAC restent incomplets conformément à l'AS-IS ;
- une erreur HTTP sur le port HTTPS ne prouve pas un refus réseau : seul un
  échec de connexion a été accepté comme test négatif ;
- le checksum déclenche une nouvelle application lors d'un changement de chart
  ou de valeurs, mais ne constitue pas à lui seul une détection complète des
  dérives manuelles ; les contrôles fonctionnels restent exécutés à chaque
  passage.

## Conclusion et prochaine mission

M10 est **Terminée**. L'entrée commune, les namespaces et le chemin
bastion/provider/NodePort sont démontrés par des tests positifs et négatifs.
M11 — déployer Redis partagé — est maintenant la seule mission en cours.
