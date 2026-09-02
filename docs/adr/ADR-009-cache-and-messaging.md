# ADR-009 — Séparer Valkey cache et NATS JetStream

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T10/T11/T17

## Contexte

Redis est à la fois cache et liste d'événements, sans mot de passe, TLS,
réplication, DLQ ou politique réseau. La perte totale du cache est acceptable,
mais pas celle d'un événement acquitté.

## Décision

- **Valkey** est réservé au cache, avec ACL, TLS, ServiceAccount et policy
  réseau dédiés. Sa donnée reste reconstructible.
- **NATS JetStream** porte les événements, avec streams persistants, comptes et
  permissions distincts, TLS, consommateurs durables, retries bornés et DLQ.
- La référence entreprise utilise au moins trois nœuds JetStream répartis sur
  des domaines prouvés. Le lab utilise un nœud et un volume local, sans HA,
  pour démontrer durabilité logique, outbox, rejeu et DLQ.
- Orders écrit une outbox transactionnelle ; un relay publie ; Notifications
  est idempotent avant tout acquittement.

## Alternatives et conséquences

RabbitMQ est robuste mais plus lourd pour le lab. Kafka dépasse le besoin et le
budget. Continuer avec une liste Redis ne fournit pas les garanties et outils
de reprise demandés.

## Capacité, rollback et validation

Déploiement parallèle ; Redis reste chemin actif jusqu'au rapprochement des
événements. Rollback : revenir au producteur/consommateur précédent sans purger
JetStream. Tests : purge cache sans perte métier, panne broker, reprise backlog,
DLQ, rejeu idempotent et message non autorisé refusé.

Traite `ASIS-007`, `ASIS-009`, `ASIS-020` et `REQ-SVC-004`, `REQ-SVC-005`,
`REQ-DATA-005`, `REQ-DATA-006`.
