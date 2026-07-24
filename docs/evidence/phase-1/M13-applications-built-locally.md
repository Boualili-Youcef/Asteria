# Preuve M13 — Applications construites localement

## Métadonnées

- **Date :** 2026-07-23
- **Mission :** M13
- **Statut :** réussi

## Objectif et résultat attendu

Produire `identity-api`, `orders-api` et `notifications-worker` avec le minimum
fonctionnel nécessaire à la reconstruction AS-IS. Chaque application doit
posséder du code, des dépendances figées, des tests et une image
conteneurisable. Les signaux de santé, disponibilité et métriques doivent être
présents, les dépendances réelles accessibles et aucun secret ne doit être
embarqué.

## Dépendances et prérequis vérifiés

- M08 fournit trois bases et trois rôles PostgreSQL distincts ;
- M11 fournit le Redis partagé dans le namespace `shared` ;
- le VPN permet l'accès au bastion et aux deux workers ;
- Docker 29.6.2 est disponible sur le poste local ;
- les versions directes ont été vérifiées auprès des sources officielles le
  23 juillet 2026 : Python 3.14.6, FastAPI 0.139.2, Uvicorn 0.51.0,
  Psycopg 3.3.4, redis-py 8.0.1, prometheus-client 0.25.0, pytest 9.1.1
  et httpx 0.28.1.

## Faits, hypothèses et décisions

| Application | Fonction minimale | Dépendances |
|---|---|---|
| `identity-api` | créer et consulter des utilisateurs | `identity_db` |
| `orders-api` | persister une commande puis publier un événement | `orders_db`, Redis |
| `notifications-worker` | consommer puis archiver un événement | Redis, `notifications_db` |

Les APIs exposent `/health`, `/ready` et `/metrics`. Le worker exécute sa boucle
en arrière-plan et expose aussi `/status`. Sa surface HTTP sert aux sondes et à
Prometheus ; elle n'est pas destinée aux utilisateurs.

Les schémas sont créés au premier besoin par chaque application. Cette solution
simple conserve l'immaturité AS-IS : aucune migration versionnée n'existe.
Orders persiste avant de publier dans Redis, sans outbox transactionnelle, et le
worker consomme une liste Redis non durable.

## Fichiers livrés

Chaque répertoire `apps/identity-api/`, `apps/orders-api/` et
`apps/notifications-worker/` contient :

- le paquet Python sous `app/` ;
- les tests sous `tests/` ;
- les dépendances d'exécution et de test figées ;
- un `Dockerfile`, un `.dockerignore` et un guide local.

Les commandes communes sont fournies par :

- `apps/test-all.sh` ;
- `apps/build-all.sh` ;
- `apps/validate-images.sh` ;
- `apps/validate-dependencies.sh` ;
- `apps/README.md`.

## Commandes exécutées

```bash
./apps/test-all.sh
./apps/build-all.sh
./apps/validate-images.sh

export ASTERIA_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/tp_cloud"
./apps/validate-dependencies.sh
```

Le dernier script dérive les adresses depuis les outputs Terraform, récupère
le ClusterIP Redis avec `kubectl`, puis ouvre deux tunnels SSH temporaires via
le bastion et `worker_01`. Aucun port permanent n'est créé.

## Résultats des tests locaux

| Suite | Résultat |
|---|---:|
| `identity-api` | 5 tests réussis |
| `orders-api` | 5 tests réussis |
| `notifications-worker` | 6 tests réussis |
| **Total** | **16 tests réussis** |

Les tests couvrent notamment santé, disponibilité positive et négative,
métriques, routes fonctionnelles, absence de détail sensible dans les erreurs
et traitement d'un événement par le worker.

Les trois suites émettent un avertissement de dépréciation Starlette concernant
le client de test httpx. Il n'affecte pas le résultat, mais doit être réévalué
à la prochaine mise à jour des dépendances.

## Résultats des images

| Image | Identifiant local | Taille | Utilisateur |
|---|---|---:|---|
| `asteria/identity-api:m13` | `sha256:ea357df3e3ad7b37fb109bdee609f7f03bbe73a0ed238f42fc4bfa42ad23c17c` | 54 825 346 octets | `10001:10001` |
| `asteria/orders-api:m13` | `sha256:dd01b15048aa11e511c70ff2ac2f67080a37f515e36017c4c8ce9bdeb2a1d978` | 56 369 463 octets | `10001:10001` |
| `asteria/notifications-worker:m13` | `sha256:1d1618971b321c694f9b655dd1ba0ac08c97db4b8b27ebd4466ca49ccef8f45f` | 56 369 697 octets | `10001:10001` |

Chaque conteneur a répondu sur `/health` et `/metrics`. Le résultat synthétique
est :

```text
identity-api image: health, metrics and non-root user validated
orders-api image: health, metrics and non-root user validated
notifications-worker image: health, metrics and non-root user validated
M13 container smoke tests passed
```

## Accès réel aux dépendances

Les vérifications sont volontairement en lecture seule : requête
`current_database()/current_user` dans PostgreSQL et `PING` dans Redis. Aucun
schéma ni donnée de validation n'a été laissé.

```text
{"postgres": {"database": "identity_db", "role": "identity_app"}, "service": "identity-api"}
{"postgres": {"database": "orders_db", "role": "orders_app"}, "redis": {"ping": true}, "service": "orders-api"}
{"postgres": {"database": "notifications_db", "role": "notifications_app"}, "redis": {"ping": true}, "service": "notifications-worker"}
M13 real dependency checks passed
```

## Contrôle des secrets

- aucun mot de passe, token, kubeconfig ou clé privée n'est présent sous
  `apps/` ;
- les images ne déclarent aucune variable `POSTGRES_PASSWORD` ni autre valeur
  sensible dans `Config.Env` ;
- chaque contexte de build est limité au répertoire de son application et ne
  peut donc pas inclure `.secrets/` situé à la racine ;
- les mots de passe M08 sont lus à l'exécution depuis le répertoire Git-ignoré
  `.secrets/m08-postgres/`, passés uniquement à l'environnement du conteneur et
  jamais affichés ;
- Redis conserve volontairement le modèle M11 sans authentification.

## Critères d'acceptation

- 16 tests locaux réussis ;
- trois images construites sans erreur ;
- trois conteneurs validés sur santé, métriques et utilisateur non-root ;
- Identity connecté à son PostgreSQL réel ;
- Orders et Notifications connectés à leurs PostgreSQL et au Redis partagé ;
- aucun secret embarqué dans le code, les contextes ou la configuration des
  images ;
- limites applicatives AS-IS explicitement documentées.

## Risques, limites et erreurs fréquentes

- `/health` atteste seulement que le processus répond ; `/ready` vérifie les
  dépendances ;
- la création de schéma au démarrage ne remplace pas des migrations ;
- une panne Redis après l'écriture d'une commande peut perdre l'événement ;
- `BLPOP` ne fournit ni reprise robuste, ni dead-letter queue, ni garantie de
  livraison ;
- les trois projets dupliquent volontairement une partie du code ;
- aucune authentification ou autorisation métier n'est encore présente ;
- les images sont locales et ne sont ni publiées ni déployées par M13.

## Conclusion et prochaine mission

M13 est **Terminée**. Les trois applications sont testées, conteneurisables et
capables de joindre leurs dépendances réelles sans secret embarqué.

M14 — déployer les applications de manière hétérogène — est la prochaine
mission autorisée. Elle n'est pas démarrée par M13.
