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

M00 et M01 sont terminées. La prochaine mission est
`M02 — Figer et expliquer l'architecture AS-IS`.

Aucune ressource OpenStack ne doit être créée avant l'inventaire M03, le design
réseau M04 et la validation d'un plan Terraform en M05.
