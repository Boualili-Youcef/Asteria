# Applications Asteria — M13

## But

M13 fournit trois images indépendantes :

| Application | Fonction minimale | Dépendances |
|---|---|---|
| `identity-api` | créer et consulter des utilisateurs | PostgreSQL |
| `orders-api` | persister une commande et publier un événement | PostgreSQL, Redis |
| `notifications-worker` | consommer et archiver les événements | Redis, PostgreSQL |

Les deux APIs exposent `/health`, `/ready` et `/metrics`. Le worker fournit les
mêmes signaux opérationnels ainsi que `/status`, sans être exposé aux
utilisateurs.

## Tests locaux

```bash
./apps/test-all.sh
```

Le script crée `apps/.venv`, installe les versions figées et exécute chaque
suite séparément.

## Construction et smoke tests

```bash
./apps/build-all.sh
./apps/validate-images.sh
```

Les images produites sont :

```text
asteria/identity-api:m13
asteria/orders-api:m13
asteria/notifications-worker:m13
```

Les smoke tests démarrent chaque image sans dépendance, vérifient `/health`,
`/metrics` et l'utilisateur non-root `10001:10001`, puis suppriment les
conteneurs.

## Validation réelle des dépendances

Le test ouvre temporairement deux tunnels SSH vers un worker. PostgreSQL voit
donc une source autorisée par M08 et Redis reste joint par son ClusterIP M11 :

```bash
export ASTERIA_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/tp_cloud"
./apps/validate-dependencies.sh
```

Les mots de passe sont lus depuis `.secrets/m08-postgres/`, transmis uniquement
à l'environnement du conteneur et jamais affichés. Le test exécute un
`SELECT current_database(), current_user` et un `PING` Redis ; il ne crée ni
table ni donnée.

## Limites AS-IS

- les trois projets répètent une partie de leur code au lieu d'utiliser une
  bibliothèque commune ;
- aucune migration versionnée n'existe encore ;
- Orders persiste avant de publier dans Redis, sans outbox transactionnelle ;
- le worker utilise une liste Redis et non un bus durable ;
- aucune authentification applicative ou autorisation métier n'est implémentée ;
- les déploiements hétérogènes et la configuration Kubernetes appartiennent à
  M14, pas à M13.
