# Asteria

> **[Ouvrir la démo publique](https://boualili-youcef.github.io/Asteria/)** —
> [Parcours en 5 minutes](docs/demo-v1/DEMO-5-MINUTES.md) ·
> [Preuves datées](docs/demo-v1/EVIDENCE.md) · [Architecture](docs/demo-v1/ARCHITECTURE.md) ·
> [Limites](docs/demo-v1/LIMITATIONS.md).
> Présentation statique et replay d'un test Docker réel, sans VPN ni compte.
> Le parcours live K3s et son rollback restent à valider.

Asteria est un projet de Platform Engineering qui simule l'évolution de
l'architecture d'une PME SaaS européenne d'environ 100 à 500 employés.

La phase 1 a reconstruit un état existant (AS-IS) réaliste, fonctionnel mais
volontairement imparfait, sur un lab OpenStack à ressources limitées. La phase
2 transforme maintenant cet état vers une architecture TO-BE guidée par les
risques, les objectifs de service et des preuves de migration.

## Documents de pilotage

- `PROJECT_CONTEXT.md` : contexte, périmètre et décisions structurantes ;
- `AGENTS.md` : règles de contribution et d'exploitation ;
- `PHASE_1_BACKLOG.md` : missions chronologiques de la phase 1 ;
- `PHASE_2_BACKLOG.md` : missions chronologiques de transformation TO-BE ;
- `archi.md` : diagramme Mermaid de l'architecture AS-IS validée ;
- `contexte.md` : matériau de réflexion initial et historique de cadrage.

## Phase actuelle

M00 à M16 sont terminées et la phase 1 AS-IS est clôturée. L'infrastructure
comprend les cinq VM, PostgreSQL, le cluster K3s, ingress-nginx, Redis partagé
et une observabilité partielle. Les trois applications minimales sont déployées
dans Kubernetes par trois méthodes volontairement différentes. Leur livraison
utilise deux workflows GitHub Actions distincts et un chemin opérateur manuel.

L'audit final se trouve dans :

- `docs/phase-1-as-is/06-deployment-methods.md` ;
- `docs/phase-1-as-is/07-observability-as-is.md` ;
- `docs/phase-1-as-is/08-as-is-known-issues.md` ;
- `docs/evidence/phase-1/M16-as-is-audit-complete.md`.

La phase 2 TO-BE est ouverte depuis le 30 août 2026. T00 à T07 sont terminées :
charte, exigences/SLO/RTO/RPO, inventaire des deux projets OpenStack, treize ADR
approuvées, temps synchronisé, state protégé, backups initiaux et break-glass
validé, puis staging CAP-05 séparé avec deux VM, fondations idempotentes et
pare-feu hôte compensatoire. T06 fournit GitHub SSO, WebAuthn par session, RBAC,
certificats courts, accès SSH/Kubernetes/PostgreSQL audités et break-glass
conservé. T07 ajoute sur le staging K3s/Cilium/Hubble, default-deny, RBAC
minimal, Pod Security Admission, quotas et stockage synthétique validé. Le
source K3s/Flannel reste intact. Ces résultats sont historiques : le second
compte n'est désormais plus accessible. L'extension Demo v1 utilise seulement
le source ou Docker local ; T08–T18 nécessitent une requalification des
dépendances selon [ADR-015](docs/adr/ADR-015-demo-v1-source-only.md).

Parcours de lecture recommandé :

1. `PHASE_2_BACKLOG.md` pour l'état et l'ordre des missions ;
2. `docs/phase-2-to-be/09-target-architecture-decisions.md` pour la cible ;
3. `docs/phase-2-to-be/13-t07-kubernetes-foundation-runbook.md`, puis la preuve
   `docs/evidence/phase-2/T07-target-kubernetes-foundation.md` ;
4. les ADR seulement pour comprendre un arbitrage ;
5. `docs/evidence/phase-2/` seulement pour auditer les résultats.

Les propositions historiques et matrices détaillées restent utiles comme
références, mais ne font pas partie du parcours de lecture quotidien.
