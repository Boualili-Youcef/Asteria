# ADR-007 — Retenir OpenBao et External Secrets

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T09/T15/T17

## Contexte

Les mots de passe PostgreSQL passent par des fichiers locaux et des Secrets
Kubernetes créés manuellement, sans rotation ni révocation centralisée.

## Décision

- La référence entreprise opère OpenBao en HA avec stockage Raft, TLS, audit,
  unseal/recovery et sauvegardes hors domaine de panne.
- Le lab utilise OpenBao avec Raft mono-nœud, explicitement non HA, et External
  Secrets Operator (ESO).
- ESO et les workloads s'authentifient avec des ServiceAccounts et jetons
  Kubernetes courts ; aucun token global statique n'est versionné.
- Un chemin, une policy et un rôle sont dédiés à chaque service/environnement.
- Les secrets existants ne sont supprimés qu'après rotation réussie et test de
  révocation ; le break-glass OpenBao reste séparé de l'usage quotidien.

## Alternatives et conséquences

SOPS/age réduit l'exploitation mais conserve du secret chiffré dans Git et
répond moins bien à la rotation dynamique. Vault ajoute une dépendance de
licence/gouvernance inutile au lab. Le CSI direct évite des Secrets persistants
mais ne couvre pas tous les consommateurs retenus.

Une instance Raft unique ne prouve pas la HA. Elle rend obligatoire snapshot,
chiffrement, copie externe et restauration T15.

## Capacité, rollback et validation

Budget mesuré avant/après. Rollback : conserver temporairement l'ancien Secret
et sa version, revenir au manifeste précédent, puis révoquer seulement après
succès. Tests : secret injecté, namespace croisé refusé, ancien secret révoqué,
scan Git/logs propre et snapshot restauré isolément.

Traite `ASIS-004`, `ASIS-011`, `ASIS-014` et `REQ-DATA-003`, `REQ-SEC-006`,
`REQ-SEC-011`.

## Sources

- [OpenBao — authentification Kubernetes](https://openbao.org/docs/auth/kubernetes/)
- [OpenBao — stockage intégré Raft](https://openbao.org/docs/configuration/storage/raft/)
