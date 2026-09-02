# ADR-014 — Répéter sur staging puis reconstruire le source sous contrôle

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T04 à T18

## Contexte

La référence entreprise préfère blue/green, mais T02 démontre qu'un green
équivalent n'entre pas dans le second projet. Une conversion CNI en place et
une bascule de données non répétée rendraient le rollback incertain.

## Décision

1. T04 stabilise temps, inventaires, backups, state et break-glass.
2. T05 crée le staging CAP-05 avec state/credentials séparés et prouve le réseau.
3. T06 à T16 construisent et répètent accès, plateforme, données synthétiques,
   promotion, observabilité et restauration sur staging.
4. Le source AS-IS reste le chemin de production-like ; aucune bascule n'est
   implicite dans ces missions.
5. Après T15 et les tests T17, une fenêtre approuvée reconstruit le cluster
   source avec la fondation validée. PostgreSQL reste sur sa VM et suit son plan
   PITR séparé. Les applications sont redéployées par digest/GitOps.
6. L'ancien chemin n'est retiré qu'après smoke, sécurité, intégrité, SLO et
   période d'observation. T18 enregistre les risques acceptés.

La référence entreprise conserve un vrai blue/green dans des projets et
domaines capables d'héberger simultanément les deux piles.

## Alternatives et conséquences

Blue/green lab est rejeté par quota. Une mutation progressive Flannel→Cilium
sur le source est rejetée car elle mélange preuve et production-like. Ne rien
reconstruire laisserait `ASIS-003` et le CNI cible non démontrés.

Le lab accepte une fenêtre de maintenance et ne prétend pas au SLO entreprise
pendant cette reconstruction. Toute donnée staging est synthétique.

## Arrêt, backup et rollback

Arrêt immédiat si backup/checksum absent, restauration non répétée, réseau ou
policy plus ouvert, plan avec destruction inattendue, RPO déjà dépassé ou test
fonctionnel incohérent. Rollback : stopper la bascule, restaurer K3s SQLite +
token avec la version sauvegardée, réappliquer le chemin d'entrée précédent et
vérifier JRN-01/02/03. Aucune destruction AS-IS avant acceptation T18.

Traite ou prépare les 22 constats ; particulièrement `ASIS-003`, `ASIS-005`,
`ASIS-012`, `ASIS-020`, `ASIS-022` et `REQ-SEC-009`, `REQ-SEC-012`,
`REQ-DATA-010`.
