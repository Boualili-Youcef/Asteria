# ADR-005 — Retenir Teleport avec un bastion break-glass

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T06/T17

## Contexte

Le chemin quotidien AS-IS repose sur une clé SSH durable, un bastion et un
kubeconfig administrateur. T01 exige identité forte, privilège court et audit,
tout en conservant un secours pendant la migration.

## Décision

- La référence entreprise utilise Teleport licencié avec OIDC/MFA, RBAC,
  certificats courts, enregistrement de sessions et déploiement HA.
- Le lab utilise **Teleport Community Edition**, GitHub SSO et MFA. L'OIDC
  générique n'est pas présenté comme une fonction gratuite : il relève de
  l'édition Enterprise.
- Une instance lab peut être placée sur le bastion actuel après mesure ; elle
  n'est ni HA ni un domaine de panne indépendant.
- La clé SSH actuelle et le kubeconfig admin deviennent break-glass : stockage
  local protégé, usage interdit au quotidien, test périodique et trace manuelle
  jusqu'à l'alerte automatisée T14.
- Le bootstrap Teleport n'abolit pas le break-glass avant test positif et
  négatif des accès SSH, Kubernetes et PostgreSQL.

## Alternatives et conséquences

Un bastion seulement durci conserve des clés longues. Boundary couvre bien les
sessions mais ajoute d'autres mécanismes pour Kubernetes et PostgreSQL. Un VPN
overlay ne fournit pas seul certificats courts, RBAC et audit de session.

Le lab dépend de GitHub pour le SSO quotidien et d'une instance Teleport unique.
Cette limite est documentée ; les rôles et TTL restent testables.

## Capacité, rollback et validation

T06 mesure CPU/RAM du bastion avant/après et s'arrête si le service dégrade le
chemin de secours. Rollback : arrêter Teleport, rétablir le chemin SSH actuel
et conserver les journaux. Tests : rôle autorisé réussi, rôle excessif refusé,
certificat expiré refusé, session retrouvée et exercice break-glass.

Traite `ASIS-004`, `ASIS-011`, `ASIS-018`, `ASIS-019` et `REQ-SVC-007`,
`REQ-SEC-002`, `REQ-SEC-010`.

## Sources

- [Teleport — configuration des méthodes d'authentification](https://goteleport.com/docs/reference/deployment/config/)
- [Teleport — matrice des éditions](https://goteleport.com/docs/feature-matrix/)
