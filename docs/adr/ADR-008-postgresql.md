# ADR-008 — Conserver PostgreSQL sur VM dans le lab

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T10/T15/T17

## Contexte

PostgreSQL 16 est un primaire VM unique, sans TLS imposé, réplica, sauvegarde
hors VM ou restauration. T02 ne trouve ni Cinder, ni multi-AZ, ni capacité pour
trois nœuds data indépendants.

## Décision

- La référence entreprise utilise PostgreSQL HA sur VMs avec Patroni ou un
  service managé qualifié, trois domaines de panne, TLS, réplication, pgBackRest,
  WAL/PITR et sauvegarde objet indépendante.
- Le lab conserve la VM PostgreSQL source : TLS avec vérification des pairs,
  rôles minimaux, pgBackRest, archivage WAL vers une cible S3 externe et tests
  PITR. Il ne revendique pas de HA.
- CloudNativePG est rejeté dans ce lab : le stockage `local-path`, l'unique AZ et
  les quotas ne fournissent pas les domaines de panne nécessaires.
- Une réplication lab éventuelle est pédagogique ; elle ne devient pas une
  preuve HA sans stockage et placement indépendants.

## Alternatives et conséquences

CloudNativePG reste une bonne cible si un futur cloud fournit CSI durable et
trois nœuds. Un `pg_dump` quotidien seul ne respecte pas le RPO Orders de 5 min.
PostgreSQL dans le staging est interdit avec des données réelles.

## Rollback et validation

Avant TLS/WAL : dump, contrôle d'intégrité, mesure disque et configuration
exportée. Rollback : restaurer la configuration précédente et les règles
réseau, sans supprimer l'archive WAL. Tests : TLS valide accepté, clair et
mauvais rôle refusés, PITR isolé, rapprochement fonctionnel et RTO/RPO mesurés.

Traite `ASIS-005`, `ASIS-006`, `ASIS-009`, `ASIS-022` et `REQ-DATA-002`,
`REQ-DATA-004`, `REQ-DATA-007`.
