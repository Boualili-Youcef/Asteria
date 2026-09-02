# ADR-004 — Séparer production lab et staging entre deux projets OpenStack

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T05/T17

## Contexte et faits

Le projet source porte cinq VM, 9 vCPU et 17 Go. Le second projet vide fournit
4 VM, 4 vCPU et 8 Go. Les deux voient `prive`, une seule AZ `nova`, aucun
Cinder/Swift/S3/L3/Octavia/Designate. Le succès réseau inter-projets n'est pas
encore démontré.

## Décision

- le projet source reste la production-like du lab et conserve l'AS-IS pendant
  la transformation ;
- le second projet devient un staging K3s compact CAP-05 à deux VM ;
- chaque projet possède credentials, variables, state Terraform, RBAC et
  inventaire séparés ; aucun state ne gère une ressource de l'autre projet ;
- le staging n'héberge que des données synthétiques ;
- le second projet n'est ni green de production, ni backup, ni DR ;
- la référence entreprise conserve production, staging et services partagés
  dans des projets et domaines de panne distincts.

## Alternatives et conséquences

Un green complet est impossible avec 4 vCPU/8 Go. Utiliser le second projet
comme stockage est rejeté car aucun stockage durable n'existe. Tout regrouper
dans le source supprimerait la preuve d'isolation et de promotion.

CAP-05 consomme 100 % des quotas CPU/RAM du projet ; l'exception à la marge de
20 % est acceptée pour le staging, avec requests/limits et mesure de charge.

## Gates et rollback

T05 doit prouver config-drive, TCP autorisé, port interdit, retour arrière de
la règle et plan Terraform sans destruction. Échec de connectivité : ROLE-04,
tests isolés sans dépendance inter-projets. Rollback : détruire uniquement le
staging avec son state après autorisation explicite ; le source reste intact.

## Traçabilité

Prépare `ASIS-001`, `ASIS-020`, `ASIS-022` et répond à `REQ-SEC-012`,
`REQ-DATA-009`, `REQ-SVC-011`.
