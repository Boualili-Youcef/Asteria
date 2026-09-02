# ADR-012 — Retenir une pile LGTM/Prometheus dimensionnée

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T14/T17

## Contexte

Prometheus/Grafana sont éphémères et partiels ; il n'existe ni Alertmanager,
logs centralisés, traces, SLO, ni contrôle d'accès Grafana.

## Décision

- Prometheus Operator, Alertmanager et Grafana couvrent métriques/SLO ; Loki
  couvre les logs ; Tempo les traces ; OpenTelemetry Collector reçoit et route
  la télémétrie ; Hubble fournit les flux réseau.
- La référence entreprise utilise stockage objet et composants HA/distribués
  selon volumétrie. Le lab utilise Prometheus, Loki single-binary et Tempo
  monolithique avec rétentions courtes et ressources plafonnées.
- Grafana utilise OIDC sans accès anonyme. Les alertes viennent des parcours T01
  et incluent temps, capacité, sauvegardes, Gateway, PostgreSQL, Valkey/NATS.
- Les logs/traces sont minimisés ; secrets et données métier ne deviennent pas
  des labels ou attributs.

## Alternatives et conséquences

Elastic/OpenSearch est trop coûteux pour le quota. Une solution SaaS réduirait
l'exploitation mais change la souveraineté et le coût. Le stockage local du lab
ne satisfait pas 30/180 jours ni un domaine indépendant : l'écart reste ouvert
jusqu'à une cible externe et une restauration T15.

## Capacité, rollback et validation

Chaque composant est ajouté par étapes avec mesure CPU/RAM/disque. Critère
d'arrêt : saturation, éviction ou marge non approuvée. Rollback : réduire la
collecte ou revenir au composant précédent en conservant les signaux critiques.
Tests : incident détecté en 5 min, diagnostic en 30 min, anonyme refusé, rôles
testés et recherche après redémarrage.

Traite `ASIS-016` à `ASIS-020` et `REQ-SVC-009`, `REQ-SVC-010`,
`REQ-DATA-008`, `REQ-SEC-010`.
