# identity-api

API minimale d'identité. Elle expose :

- `GET /health` : vie du processus, sans dépendance ;
- `GET /ready` : requête réelle vers PostgreSQL ;
- `GET /metrics` : métriques Prometheus ;
- `POST /api/v1/users` et `GET /api/v1/users/{id}`.

Variables obligatoires :

```text
POSTGRES_HOST
POSTGRES_DATABASE=identity_db
POSTGRES_USER=identity_app
POSTGRES_PASSWORD
```

Le mot de passe doit être injecté au runtime. Aucun défaut ni fichier `.env`
contenant un secret n'est fourni.
