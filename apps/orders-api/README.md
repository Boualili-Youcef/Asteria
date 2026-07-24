# orders-api

API minimale de commandes. Elle expose :

- `GET /health`, `GET /ready` et `GET /metrics` ;
- `POST /api/v1/orders` et `GET /api/v1/orders/{id}`.

Une création persiste la commande dans PostgreSQL puis pousse un événement
`order.created` dans la liste Redis `asteria:notifications`.

Variables obligatoires :

```text
POSTGRES_HOST
POSTGRES_DATABASE=orders_db
POSTGRES_USER=orders_app
POSTGRES_PASSWORD
REDIS_HOST
```

Redis conserve volontairement le modèle M11 sans authentification. Aucun secret
n'est inclus dans l'image.
