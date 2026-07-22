# Preuve M11 — Redis partagé déployé

## Métadonnées

- **Date :** 2026-07-20
- **Mission :** M11
- **Statut :** réussi

## Objectif et résultat attendu

Déployer dans Kubernetes le Redis commun à `orders-api` et
`notifications-worker`, puis rendre observable son isolation faible AS-IS. Le
résultat attendu est un Redis disponible derrière un Service interne, joignable
depuis les deux namespaces consommateurs, sans masquer les dettes retenues.

## Dépendances et prérequis vérifiés

- M10 est terminée ; `shared`, `team-orders` et `team-notifications` sont
  `Active` ;
- les trois nœuds M09 sont `Ready` ;
- le StorageClass K3s `local-path` est disponible ;
- les applications M13 n'existent pas encore : deux Pods Redis clients
  éphémères représentent donc leurs futurs contextes réseau respectifs.

## Faits, hypothèses et décisions

Le lab exécute un singleton Redis `8.8.0` sur un worker. Un PVC RWO de 1 Gi
conserve l'AOF sur le stockage `local-path`. Le Service
`redis-shared.shared.svc.cluster.local:6379` est de type `ClusterIP` et ne
publie aucun NodePort.

Les choix suivants rendent l'AS-IS faible explicitement observable :

- compte Redis `default` actif avec `nopass` et `+@all` ;
- trafic Redis non chiffré ;
- aucune ACL distincte entre Orders et Notifications ;
- aucune NetworkPolicy dans `shared` ;
- une même clé écrite depuis `team-orders` peut être lue depuis
  `team-notifications`.

Le Pod reste non-root, sans élévation de privilèges et sans token de Service
Account monté. Ces protections locales ne transforment pas le composant en
architecture cible et n'effacent pas la dette de partage.

## Fichiers livrés

- `k8s/current-state/redis/redis.yaml` ;
- `k8s/current-state/redis/README.md` ;
- `infra/ansible/playbooks/m11-redis.yml` ;
- `infra/ansible/scripts/m11-validate-redis.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/README.md`.

## Commandes exécutées

```bash
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

bash -n infra/ansible/scripts/m11-validate-redis.sh

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m11-redis.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m11-redis.yml
```

Le playbook exécute aussi `kubectl apply --dry-run=server` avant l'application.
Il a été rejoué intégralement pour contrôler l'idempotence.

## Résultats observés

### Ressources persistantes

| Ressource | État observé | Détail |
|---|---|---|
| Deployment `redis-shared` | `1/1` disponible | image `redis:8.8.0-alpine3.23` |
| Pod Redis | `1/1 Running` | 0 redémarrage, placé sur un worker |
| Service `redis-shared` | `ClusterIP` | TCP/6379, aucune IP externe |
| PVC `redis-shared-data` | `Bound` | 1 Gi, RWO, `local-path` |

La commande `redis-cli ping` retourne `PONG`. Redis expose la version `8.8.0`
et `CONFIG GET appendonly` retourne `yes`.

### Partage et isolation faible

La sortie de l'ACL observée est :

```text
user default on nopass sanitize-payload ~* &* +@all
```

`kubectl -n shared get networkpolicy -o name` ne retourne aucune ressource.
Le test fonctionnel inter-namespaces produit :

```text
team-orders: PONG and shared key written
team-notifications: PONG and shared key read
M11 shared Redis checks passed
```

Le test écrit `m11:shared-connectivity` depuis `team-orders`, lit sa valeur
depuis `team-notifications`, puis supprime la clé et les Pods clients. Le
contrôle final confirme que les Pods de test sont absents.

## Preuve d'idempotence

Le second passage complet donne :

| Hôte | `changed` | `failed` |
|---|---:|---:|
| `bastion-admin-01` | 0 | 0 |

Les ressources persistantes sont `unchanged`. Les Pods clients et la clé de
test restent éphémères et sont nettoyés à chaque passage.

## Critères d'acceptation

- manifest accepté par l'API Kubernetes ;
- Redis `1/1` disponible et `PING` égal à `PONG` ;
- PVC lié et AOF activée ;
- Service interne TCP/6379, sans NodePort ;
- connexion et partage de clé démontrés depuis les deux namespaces prévus ;
- absence d'authentification et de NetworkPolicy observée/documentée ;
- nettoyage des ressources de test et second passage `changed=0`.

## Risques, limites et erreurs fréquentes

- Redis est un point unique de panne, sans réplication ni bascule ;
- `local-path` lie les données au nœud et n'est pas un stockage hautement
  disponible ;
- l'AOF ne remplace pas une sauvegarde ; aucune restauration n'a été testée ;
- toute compromission d'un Pod joignant le Service donne un accès Redis complet
  sans mot de passe ;
- les données circulent sans TLS à l'intérieur de l'overlay ;
- la limite mémoire du conteneur n'est pas associée à une politique Redis
  `maxmemory`, ce qui peut provoquer un arrêt OOM sous charge ;
- corriger ces dettes maintenant masquerait l'AS-IS ; leur traitement appartient
  à l'audit M16 puis à la phase 2.

## Conclusion et prochaine mission

M11 est **Terminée**. Redis partagé est disponible et ses deux consommateurs
prévus peuvent utiliser le même espace de données, avec l'isolation faible
explicitement démontrée. M12 — déployer l'observabilité partielle — est la
prochaine mission autorisée, mais reste `À faire`.
