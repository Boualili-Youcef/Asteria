# Traçabilité AS-IS vers TO-BE

## 1. Rôle de la matrice

Cette matrice empêche la phase 2 de devenir une accumulation d'outils. Chaque
constat M16 possède une réponse, une mission principale et une preuve attendue.

Les réponses sont des candidats jusqu'aux décisions T03.

## 2. Matrice des 22 constats

| ID | Risque à corriger | Réponse TO-BE candidate | Mission principale | Critère observable final |
|---|---|---|---|---|
| ASIS-001 | Underlay plat et SG insuffisants | projets séparés, host controls, Cilium default-deny et tests de flux | T02, T07 | chaque flux autorisé/refusé correspond à la matrice |
| ASIS-002 | NodePort sans entrée stable/TLS | Gateway API, Envoy, TLS et exposition adaptée au cloud | T08 | adresse/nom stable selon lab, TLS et routes testés |
| ASIS-003 | control plane/SQLite uniques, zéro snapshot | cible HA entreprise, cluster lab honnête, snapshots et restore | T07, T15 | perte simulée et reconstruction mesurée |
| ASIS-004 | kubeconfig large, aucun SA/policy | Teleport/RBAC, SA par workload, PSA et NetworkPolicies | T06, T07, T09 | accès minimal et tests négatifs par rôle |
| ASIS-005 | PostgreSQL unique, aucun restore | réplication validée, backups physiques/WAL, PITR | T10, T15 | RPO/RTO mesurés par restauration |
| ASIS-006 | PostgreSQL sans TLS imposé | TLS serveur/client et règles `hostssl` | T10 | connexion chiffrée réussie, non-TLS refusée |
| ASIS-007 | Redis unique, nopass, sans TLS/policy | Valkey cache isolé, ACL/TLS ; bus durable séparé | T09, T10 | accès non autorisé refusé, panne/reprise testée |
| ASIS-008 | workloads à un replica | replicas, spread, PDB, probes et budgets | T11 | perte d'un Pod sans rupture SLO selon T01 |
| ASIS-009 | schémas au boot, pas d'outbox/DLQ | migrations, outbox, idempotence, retry et DLQ | T10, T11 | événement rejoué sans doublon et échec isolé |
| ASIS-010 | APIs sans auth métier | OIDC et autorisations par scope/tenant | T09, T11 | 401/403/2xx testés automatiquement |
| ASIS-011 | secrets locaux/manuels | OpenBao, External Secrets, rotation et audit | T09 | secret rotaté sans Git et accès révoqué |
| ASIS-012 | trois méthodes de déploiement | contrat de service commun et GitOps | T12, T13, T16 | même parcours de promotion/rollback pour 3 apps |
| ASIS-013 | CI fragmentée | workflow réutilisable obligatoire | T12 | mêmes gates et artefacts sur les 3 services |
| ASIS-014 | aucun scan/SBOM/signature/provenance | scans, SBOM, provenance, actions immuables, admission | T09, T12 | artefact vérifié ; image non conforme bloquée |
| ASIS-015 | GHCR non consommé, tags locaux | build once, digest GitOps et promotion | T12, T13 | digest CI égal au digest runtime |
| ASIS-016 | monitoring éphémère et incomplet | stockage persistant, exporters et rétention | T14 | données survivent à un redémarrage et couvrent les dépendances |
| ASIS-017 | aucune alerte/SLO/log/tracing | Alertmanager, Loki, Tempo, OTel et SLO | T14 | incident synthétique détecté et expliqué |
| ASIS-018 | Grafana anonyme | OIDC, RBAC et aucune session anonyme | T09, T14 | accès anonyme refusé, rôles Viewer/Editor testés |
| ASIS-019 | NTP non synchronisé | chrony/NTP vérifié et alerte de dérive | T04, T14 | synchronisation vraie et dérive sous seuil T01 |
| ASIS-020 | quota presque saturé | inventaire dual-project, sizing et budgets | T02, T03 | plan sous quotas avec marge documentée |
| ASIS-021 | ingress-nginx retiré | migration Gateway API/Envoy et suppression contrôlée | T08 | routes équivalentes puis ancien contrôleur absent |
| ASIS-022 | aucun staging/DR/restore E2E | environnement séparé, backups multi-domaines et game day | T05, T15, T17 | scénario de reprise complet dans RTO/RPO |

## 3. Couverture par vague

| Vague | Constats principalement couverts |
|---|---|
| Décider | ASIS-001 à ASIS-022 par exigences et ADR |
| Sécuriser | ASIS-001, 003, 004, 005, 011, 019, 020, 022 |
| Reconstruire | ASIS-001 à 007, 010, 011, 020 à 022 |
| Moderniser | ASIS-008 à 015 |
| Opérer | ASIS-003, 005, 007, 016 à 019, 022 |
| Prouver | les 22 constats par tests et audit final |

## 4. Règle de clôture

T18 ne peut fermer un constat que si son critère observable est prouvé. Sinon,
le constat devient un risque explicitement accepté avec propriétaire, raison,
compensation et échéance ; il ne disparaît pas de la documentation.
