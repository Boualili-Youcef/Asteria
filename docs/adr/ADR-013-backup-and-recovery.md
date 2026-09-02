# ADR-013 — Séparer les mécanismes de sauvegarde et imposer la restauration

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T04/T15/T17

## Contexte

Le cloud ne fournit ni volume, snapshot ni objet. Une sauvegarde PostgreSQL
initiale reste sur la VM ; K3s SQLite, Redis et la plateforme ne sont pas
restaurés. Le second projet partage le site et n'est pas un DR.

## Décision

- La référence entreprise utilise un stockage objet versionné, chiffré et
  protégé contre l'altération dans un domaine de panne distinct.
- Le lab exige avant T15 une cible **S3-compatible externe à cet OpenStack** ;
  son fournisseur n'est pas inventé par T03.
- PostgreSQL utilise pgBackRest + WAL/PITR ; K3s sauvegarde objets et volumes
  avec Velero/Kopia vers S3 ; OpenBao produit des snapshots Raft ; Git conserve
  l'état déclaratif ; chaque catalogue contient checksum, version et rétention.
- Tant que le source reste SQLite, son répertoire
  `/var/lib/rancher/k3s/server/db` et son token serveur sont sauvegardés ensemble.
- T04 produit une copie de sécurité locale protégée sur le poste opérateur ;
  elle n'est ni un backup final, ni un DR, ni une preuve de restauration.

## Alternatives et conséquences

Le second projet et les disques root Nova sont rejetés comme cible durable. Un
seul `pg_dump` ne satisfait pas les RPO. Velero FSB couvre les volumes locaux
mais exécute un node-agent privilégié et sa cohérence applicative est limitée ;
les datastores utilisent donc leurs outils natifs.

## Rollback et validation

La mise en place n'efface aucun backup antérieur. Changement de repository ou
clé : conserver l'ancienne chaîne jusqu'à restauration du nouveau point. Tests
T15 : restauration isolée, checksums, requêtes fonctionnelles, chronométrage
RTO/RPO et refus d'accès non autorisé.

Traite `ASIS-003`, `ASIS-005`, `ASIS-007`, `ASIS-011`, `ASIS-022` et
`REQ-DATA-004`, `REQ-DATA-007`, `REQ-DATA-010`, `REQ-SEC-011`.

## Sources

- [K3s — backup SQLite et token](https://docs.k3s.io/datastore/backup-restore)
- [Velero — File System Backup](https://velero.io/docs/v1.17/file-system-backup/)
