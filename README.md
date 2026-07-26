# Asteria

Asteria est un projet de Platform Engineering qui simule l'évolution de
l'architecture d'une PME SaaS européenne d'environ 100 à 500 employés.

La phase 1 reconstruit un état existant (AS-IS) réaliste, fonctionnel mais
volontairement imparfait, sur un lab OpenStack à ressources limitées. Une phase
ultérieure portera l'audit et la modernisation de cette architecture.

## Documents de pilotage

- `PROJECT_CONTEXT.md` : contexte, périmètre et décisions structurantes ;
- `AGENTS.md` : règles de travail applicables aux humains et agents IA ;
- `PHASE_1_BACKLOG.md` : missions chronologiques de la phase 1 ;
- `archi.md` : diagramme Mermaid de l'architecture AS-IS validée ;
- `contexte.md` : matériau de réflexion initial et historique de cadrage.

## Phase actuelle

M00 à M15 sont terminées. L'infrastructure AS-IS comprend désormais les cinq
VM, PostgreSQL, le cluster K3s, ingress-nginx, Redis partagé et une observabilité
partielle. Les trois applications minimales sont déployées dans Kubernetes par
trois méthodes volontairement différentes. Leur livraison utilise deux
workflows GitHub Actions distincts et un chemin opérateur manuel.

M16 — auditer et documenter les problèmes AS-IS — est la mission en cours.
