# Redis partagé — état AS-IS

## But

Ce répertoire représente le Redis unique utilisé par `orders-api` et
`notifications-worker`. Il est déployé dans le namespace `shared` et joignable
dans le cluster à l'adresse :

```text
redis-shared.shared.svc.cluster.local:6379
```

## Déploiement

Le playbook M11 applique `redis.yaml`, attend le PVC et le Deployment, puis
teste la connexion depuis `team-orders` et `team-notifications` :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m11-redis.yml
```

## Dette volontairement conservée

Redis est un singleton avec un volume `local-path` lié à un nœud. Il n'a ni
réplication, ni Sentinel, ni TLS, ni mot de passe/ACL par équipe. Aucune
NetworkPolicy ne sépare les consommateurs : tout Pod capable de joindre le
Service peut utiliser le compte `default` sans authentification. La persistance
AOF est activée, mais aucune sauvegarde ni restauration n'est automatisée ou
testée.

Le Service est toutefois limité à `ClusterIP` : le port 6379 n'est pas publié
en NodePort et n'est pas exposé sur l'underlay OpenStack. Ces défauts rendent
l'isolation faible observable sans exposer Redis hors du cluster. Leur
correction appartient à la phase 2.
