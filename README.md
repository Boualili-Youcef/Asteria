# Asteria

Asteria est un projet de Platform Engineering qui simule l'évolution de
l'architecture d'une PME SaaS européenne d'environ 100 à 500 employés.

La phase 1 a reconstruit un état existant (AS-IS) réaliste, fonctionnel mais
volontairement imparfait, sur un lab OpenStack à ressources limitées. La phase
2 transforme maintenant cet état vers une architecture TO-BE guidée par les
risques, les objectifs de service et des preuves de migration.

## Documents de pilotage

- `PROJECT_CONTEXT.md` : contexte, périmètre et décisions structurantes ;
- `AGENTS.md` : règles de travail applicables aux humains et agents IA ;
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

La phase 2 TO-BE est ouverte depuis le 30 août 2026. T00 initialise sa charte,
sa traçabilité et deux propositions d'architecture sans modifier le runtime.
La prochaine mission est T01 : définir les SLO, RTO/RPO et le modèle de menace.

Documents d'entrée de phase 2 :

- `docs/phase-2-to-be/00-transformation-charter.md` ;
- `docs/phase-2-to-be/01-target-architecture-proposal.md` ;
- `docs/phase-2-to-be/02-as-is-to-to-be-traceability.md` ;
- `docs/evidence/phase-2/T00-phase-2-initialized.md`.
