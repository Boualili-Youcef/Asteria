# ADR-006 — Retenir Keycloak pour les identités applicatives OIDC

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T09/T11/T14

## Contexte

Les APIs sont anonymes et aucun tenant n'est contrôlé. Les besoins applicatifs
ne doivent pas être confondus avec l'accès privilégié Teleport.

## Décision

- La référence entreprise utilise un IdP OIDC supporté par l'organisation ;
  Keycloak est l'implémentation de référence Asteria, opérée en HA avec une
  base PostgreSQL dédiée.
- Le lab déploie Keycloak en instance unique, avec données synthétiques,
  realms/clients déclaratifs, MFA pour les rôles humains et clients séparés
  pour applications, Grafana et Argo CD.
- Les APIs valident issuer, audience, expiration et rôle ; le tenant est une
  autorisation métier explicite, pas seulement un claim accepté aveuglément.
- Teleport Community utilise GitHub SSO selon ADR-005 ; cette exception évite
  de prétendre que l'OIDC générique est inclus dans cette édition.

## Alternatives et conséquences

GitHub seul ne représente pas des clients B2B ni des tenants applicatifs. Dex
est un broker utile mais ne fournit pas le cycle de vie utilisateur attendu.
Un IdP SaaS simplifierait l'exploitation, au prix de la souveraineté simulée et
d'une dépendance externe supplémentaire.

## Capacité, rollback et validation

Le lab plafonne ressources et base, exporte la configuration et conserve les
comptes de test reproductibles. Rollback applicatif : conserver l'entrée privée
AS-IS jusqu'aux tests, puis retirer les routes non authentifiées seulement après
2xx/401/403 et mauvais tenant. Aucun compte ou donnée client réel n'est importé.

Traite `ASIS-010`, `ASIS-018` et `REQ-SVC-006`, `REQ-DATA-009`,
`REQ-SEC-001`, `REQ-SEC-002`.
