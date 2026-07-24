# notifications-worker

Worker minimal de notifications. Une boucle de fond lit
`asteria:notifications` dans Redis et archive chaque événement dans PostgreSQL.
Les endpoints HTTP sont uniquement opérationnels :

- `GET /health` ;
- `GET /ready` ;
- `GET /status` ;
- `GET /metrics`.

Variables obligatoires :

```text
POSTGRES_HOST
POSTGRES_DATABASE=notifications_db
POSTGRES_USER=notifications_app
POSTGRES_PASSWORD
REDIS_HOST
```

`RUN_WORKER=false` désactive la boucle pour les tests ou le diagnostic. Aucun
endpoint métier n'est destiné aux utilisateurs finaux.
