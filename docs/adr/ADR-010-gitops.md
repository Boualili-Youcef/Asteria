# ADR-010 — Retenir Argo CD comme source de réconciliation

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T13/T16/T17

## Contexte

Trois méthodes de déploiement coexistent et les images GHCR ne sont pas celles
du runtime. Il n'existe ni source de vérité CD, ni drift, ni rollback commun.

## Décision

- Argo CD réconcilie des manifests versionnés ; les images sont promues par
  digest, jamais reconstruites par environnement.
- `AppProject`, comptes de cluster et permissions séparent staging, production
  lab et équipes. L'auto-sync commence en staging ; production exige promotion
  revue, fenêtre et contrôles de santé.
- Le lab utilise l'installation non-HA dimensionnée et placée sur staging ; la
  référence entreprise utilise le bundle HA sur au moins trois nœuds.
- Les changements d'urgence sont documentés puis réconciliés dans Git.

## Alternatives et conséquences

Flux est plus léger et entièrement CLI, mais Argo CD rend santé, historique et
RBAC plus visibles pour les équipes. Les deux sont valides ; le coût mémoire
d'Argo CD impose un budget et un nombre borné d'Applications.

## Rollback et validation

Bootstrap minimal hors GitOps, documenté et rejouable. Rollback : revert du
commit/digest, sync et smoke tests ; le `kubectl apply` direct n'est qu'un
break-glass temporaire. Tests : drift détecté puis réconcilié, ressource hors
projet refusée, même digest observé et rollback inférieur à 15 min.

Traite `ASIS-012`, `ASIS-015` et `REQ-SVC-008`, `REQ-SEC-008`,
`REQ-DATA-010`.

## Sources

- [Argo CD — modes d'installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Argo CD — haute disponibilité](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/)
