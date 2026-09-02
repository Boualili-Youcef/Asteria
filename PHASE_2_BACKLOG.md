# Backlog chronologique — Phase 2 TO-BE

## Règles de progression

La phase 2 est la transformation contrôlée de l'architecture AS-IS auditée en
M16. Son démarrage a été approuvé le **30 août 2026**.

Statuts autorisés : `À faire`, `En cours`, `Bloquée`, `Terminée`.

Une seule mission est `En cours`. Une mission ne devient `Terminée` que si :

1. les constats `ASIS-xxx` traités sont explicitement référencés ;
2. la cible entreprise et l'implémentation du lab sont distinguées ;
3. les hypothèses et les faits vérifiés sont séparés ;
4. le changement, son impact et son retour arrière sont documentés ;
5. les validations positives, négatives et de sécurité sont observables ;
6. une preuve sans secret existe sous `docs/evidence/phase-2/` ;
7. le commit reste limité à la mission.

Aucun changement destructif, apply Terraform, bascule de trafic ou migration de
données ne peut être exécuté sans examen explicite de son périmètre.

## Vue d'ensemble

| Mission | Intitulé | Statut | Dépend de |
|---|---|---|---|
| T00 | Initialiser la transformation TO-BE | Terminée | M16 |
| T01 | Définir SLO, RTO/RPO et modèle de menace | Terminée | T00 |
| T02 | Réinventorier les deux projets OpenStack | Terminée | T01 |
| T03 | Approuver l'architecture cible et les ADR | Terminée | T02 |
| T04 | Stabiliser les fondations avant migration | Terminée | T03 |
| T05 | Construire la landing zone et le staging séparé | Terminée | T04 |
| T06 | Mettre en place l'accès d'administration Zero Trust | Terminée | T05 |
| T07 | Construire la fondation Kubernetes cible | À faire | T05 |
| T08 | Migrer l'entrée vers Gateway API et TLS | À faire | T07 |
| T09 | Industrialiser identités, secrets et politiques | À faire | T07 |
| T10 | Fiabiliser PostgreSQL, cache et messagerie | À faire | T07, T09 |
| T11 | Moderniser la fiabilité et la sécurité applicatives | À faire | T08, T10 |
| T12 | Construire la golden path CI et la supply chain | À faire | T09, T11 |
| T13 | Déployer par GitOps et promotion contrôlée | À faire | T12 |
| T14 | Construire observabilité, alerting et SLO | À faire | T11, T13 |
| T15 | Automatiser sauvegardes, restauration et DR | À faire | T10, T14 |
| T16 | Standardiser l'expérience des équipes | À faire | T13, T14 |
| T17 | Exécuter les tests de résilience et de sécurité | À faire | T15, T16 |
| T18 | Auditer le TO-BE et mesurer les progrès | À faire | T17 |

## T00 — Initialiser la transformation TO-BE

**Objectif :** ouvrir officiellement la phase 2 sans modifier le runtime.

**Livrables :**

- `PHASE_2_BACKLOG.md` ;
- `docs/phase-2-to-be/00-transformation-charter.md` ;
- `docs/phase-2-to-be/01-target-architecture-proposal.md` ;
- `docs/phase-2-to-be/02-as-is-to-to-be-traceability.md` ;
- diagrammes cibles entreprise et lab ;
- règles de travail et contexte mis à jour ;
- `docs/evidence/phase-2/T00-phase-2-initialized.md`.

**Validation :** les 22 constats M16 sont couverts, l'AS-IS reste inchangé et
aucune capacité non inventoriée n'est présentée comme acquise.

## T01 — Définir SLO, RTO/RPO et modèle de menace

**Objectif :** définir ce que la plateforme doit protéger et rendre disponible
avant de choisir définitivement les mécanismes.

**Livrables :**

- `docs/phase-2-to-be/03-service-objectives.md` : parcours critiques,
  propriétaires, SLI/SLO et budgets d'erreur candidats ;
- `docs/phase-2-to-be/04-data-classification-and-recovery.md` : classification,
  RTO/RPO et exigences de restauration ;
- `docs/phase-2-to-be/05-threat-model.md` : actifs, menaces, frontières et
  contrôles testables ;
- `docs/phase-2-to-be/06-t01-requirements-traceability.md` : couverture des 22
  constats M16 ;
- `docs/diagrams/to-be-trust-boundaries.mmd` ;
- `docs/evidence/phase-2/T01-service-objectives-and-threat-model.md`.

**Validation :** chaque exigence est testable et reliée à un risque M16.

**Preuve :** `T01-service-objectives-and-threat-model.md`.

**Conclusion :** 33 exigences testables couvrent les 22 constats. Les valeurs
SLO/RTO/RPO restent des objectifs internes candidats à faire approuver par les
propriétaires métier ; aucune conformité runtime n'est revendiquée par T01.

## T02 — Réinventorier les deux projets OpenStack

**Objectif :** décider la topologie du lab à partir des capacités actuelles des
deux projets et non des captures historiques.

**Inventaire obligatoire :** quotas, consommation, flavors, images, réseaux,
subnets, ports, SG, volumes, snapshots, Swift/S3, L3, Floating IP, Octavia,
DNS, metadata/config-drive et connectivité inter-projets.

**Décision attendue :** rôle de chaque projet, capacité d'un blue/green, nombre
de workers, stockage et cible de sauvegarde.

**Preuve :** `T02-dual-project-openstack-inventory.md`, sans identifiants ni
secrets.

**État actuel :** les deux collectes authentifiées sont analysées. Le projet
source conserve le lab principal ; le projet secondaire ne peut devenir qu'un
staging Kubernetes léger. La libération de ses deux VM CKA a été autorisée le
30 août 2026 ; le contrôle live final confirme 0 instance, 0 vCPU, 0 Mo de RAM
et 0 port utilisés. Le probe inter-projets est reporté comme critère bloquant à
la création contrôlée du staging en T05.

## T03 — Approuver l'architecture cible et les ADR

**Objectif :** transformer le candidat T00 en décisions approuvées.

**ADR minimales :** distribution Kubernetes et CNI, Gateway API, séparation
des projets, accès Zero Trust, identité, secrets, PostgreSQL, cache/messaging,
GitOps, supply chain, observabilité, sauvegarde et stratégie de migration.

**Validation :** capacité, compatibilité, coût opérationnel, rollback et
couverture `ASIS-xxx` évalués pour chaque décision.

**Preuve :** `T03-target-architecture-approved.md`.

**Conclusion :** treize ADR (ADR-002 à ADR-014) approuvent la cible entreprise,
son adaptation lab et la stratégie de migration. Le second projet est staging
CAP-05, pas un green de production, un backup ou un DR. Aucun runtime n'a été
modifié par T03.

## T04 — Stabiliser les fondations avant migration

**Objectif :** supprimer les risques immédiats qui rendent une migration peu
fiable.

**Contenu :** synchronisation NTP vérifiée, inventaires/export de configuration,
sauvegardes de sécurité, état Terraform protégé, procédures break-glass,
baseline de versions et contrôles de santé reproductibles.

**Traite :** `ASIS-019` et prépare `ASIS-003`, `ASIS-005`, `ASIS-022`.

**Preuve :** `T04-foundations-stabilized.md`.

**Conclusion :** les cinq VM sont synchronisées sur la source institutionnelle
avec un écart mesuré nul, K3s 3/3 et PostgreSQL restent sains, le break-glass
ProxyJump réussit et l'authentification directe est refusée. State Terraform,
dump PostgreSQL et backup K3s sont hors Git, en mode `0600` et contrôlés par
checksum. Le second passage NTP est idempotent (`changed=0`). Aucun apply
Terraform, redémarrage applicatif, bascule ou destruction n'a été exécuté.

T05 a démarré après la clôture durable de T04 et est désormais terminée. Son
incident de ciblage initial, son rollback et ses contrôles finaux sont décrits
dans sa propre section et sa preuve.

## T05 — Construire la landing zone et le staging séparé

**Objectif :** préparer le staging CAP-05 sans modifier la production AS-IS en
place. Le blue/green reste la référence entreprise mais est impossible dans les
quotas du lab selon T02/T03.

**Contenu :** states et credentials séparés, conventions, réseau réellement
disponible, compute/stockage, staging, sauvegarde et plan de bascule/rollback.

**Validation :** plan Terraform sans destruction de l'AS-IS et budget de
ressources respecté.

**Preuve :** `T05-target-landing-zone-ready.md`.

**Conclusion :** le projet secondaire héberge deux VM staging actives dans le
budget CAP-05 exact. Le state et les credentials sont séparés, NTP/config-drive
et SSH via bastion sont validés, UFW compense le contournement observé des
security groups du réseau provider, le probe refus/succès/rollback passe et le
dernier passage Ansible est idempotent (`changed=0`). Le state final est
sauvegardé hors Git avec checksum. Une première tentative sur le mauvais projet
a été intégralement annulée avant la création de VM ; le garde-fou Keystone et
les contrôles de quotas empêchent sa répétition.

## T06 — Mettre en place l'accès d'administration Zero Trust

**Objectif :** remplacer les clés SSH permanentes et le bastion quotidien par
un accès lié à l'identité, à privilèges courts et auditable.

**Cible approuvée :** Teleport entreprise avec OIDC/MFA ; lab Community avec
GitHub SSO/MFA, RBAC et certificats courts. Le bastion actuel reste un accès
break-glass testé pendant la transition.

**Traite :** `ASIS-001`, `ASIS-004`, `ASIS-011`.

**Preuve :** `T06-zero-trust-access-ready.md`.

**Conclusion :** GitHub SSO mappe l'équipe privée au rôle minimal
`asteria-platform`. WebAuthn est exigé par session. SSH `ubuntu`, la lecture
Kubernetes et PostgreSQL `asteria_readonly` réussissent ; `root`, la création
de `ClusterRole`, PostgreSQL `postgres` et un certificat expiré sont refusés.
Les événements et enregistrements sont retrouvés dans l'audit, le break-glass
reste actif et tracé, et le second passage du connecteur est idempotent. T07 est
désormais autorisée.

## T07 — Construire la fondation Kubernetes cible

**Objectif :** fournir une fondation réseau et sécurité observable avant les
workloads.

**Cible approuvée :** RKE2 HA en référence entreprise ; K3s reconstruit dans le
lab après répétition staging, Cilium comme CNI, NetworkPolicies default-deny,
Hubble, RBAC minimal, Pod Security Admission, ressources/quotas et stockage
validé.

La HA entreprise exige trois domaines de panne ; le lab ne peut la déclarer
que si T02 démontre réellement ces domaines.

**Traite :** `ASIS-001`, `ASIS-003`, `ASIS-004`, `ASIS-020`.

**Preuve :** `T07-target-kubernetes-foundation.md`.

## T08 — Migrer l'entrée vers Gateway API et TLS

**Objectif :** retirer ingress-nginx et fournir une entrée maintenue, portable
et chiffrée.

**Cible approuvée :** Gateway API standard, Envoy Gateway, cert-manager,
HTTPRoute, TLS, politiques d'attachement inter-namespaces et exposition adaptée
aux capacités OpenStack réelles.

**Traite :** `ASIS-002`, `ASIS-021` et une partie de `ASIS-010`.

**Preuve :** `T08-gateway-api-and-tls-ready.md`.

## T09 — Industrialiser identités, secrets et politiques

**Objectif :** supprimer les secrets manuels et appliquer les garde-fous de
plateforme de manière déclarative.

**Cible approuvée :** Keycloak/OIDC applicatif, OpenBao, External Secrets, rotation,
ServiceAccounts dédiés, RBAC, Kyverno en mode audit puis enforce, vérification
d'images et règles par namespace.

**Traite :** `ASIS-004`, `ASIS-010`, `ASIS-011`, `ASIS-014`, `ASIS-018`.

**Preuve :** `T09-identities-secrets-policies-ready.md`.

## T10 — Fiabiliser PostgreSQL, cache et messagerie

**Objectif :** séparer les responsabilités data et démontrer sauvegarde,
reprise et chiffrement.

**Cible approuvée :** PostgreSQL TLS sur VM dans le lab avec sauvegarde
physique/WAL et restauration ; Valkey réservé au cache ; NATS JetStream distinct
pour les événements, avec réplication et DLQ selon capacité.

CloudNativePG est rejeté dans le lab courant par T02/T03 : absence de Cinder,
unique AZ et quotas insuffisants. Il ne pourra être réévalué que si un futur
inventaire prouve nœuds, stockage CSI et domaines de panne indépendants.

**Traite :** `ASIS-005`, `ASIS-006`, `ASIS-007`, `ASIS-009`, `ASIS-022`.

**Preuve :** `T10-reliable-data-services.md`.

## T11 — Moderniser la fiabilité et la sécurité applicatives

**Objectif :** rendre les trois services compatibles avec les objectifs T01.

**Contenu :** OIDC/autorisation, migrations versionnées, outbox, consommateurs
idempotents, retries/DLQ, replicas, PDB, requests/limits, probes, arrêt gracieux,
tests contractuels et instrumentation OpenTelemetry.

**Traite :** `ASIS-008`, `ASIS-009`, `ASIS-010`.

**Preuve :** `T11-applications-modernized.md`.

## T12 — Construire la golden path CI et la supply chain

**Objectif :** une même chaîne contrôlée produit tous les artefacts.

**Contenu :** workflow réutilisable, tests, lint, scan de dépendances et image,
SBOM, provenance, actions épinglées, GHCR, digest immuable et publication des
résultats. Les exceptions sont explicites et temporaires.

**Traite :** `ASIS-012`, `ASIS-013`, `ASIS-014`, `ASIS-015`.

**Preuve :** `T12-golden-ci-supply-chain.md`.

## T13 — Déployer par GitOps et promotion contrôlée

**Objectif :** rendre Git source de vérité de la configuration runtime.

**Cible approuvée :** Argo CD, séparation code/configuration, environnements,
promotion par digest, drift detection, politiques de sync, smoke tests et
rollback Git documenté.

**Traite :** `ASIS-012`, `ASIS-015`.

**Preuve :** `T13-gitops-delivery-ready.md`.

## T14 — Construire observabilité, alerting et SLO

**Objectif :** détecter et expliquer les incidents avant les utilisateurs.

**Contenu :** Prometheus persistant, Alertmanager, Grafana authentifié,
exporters PostgreSQL/cache/gateway, Loki, OpenTelemetry Collector, Tempo,
dashboards orientés service, alertes et burn rates SLO.

Le lab utilise des modes monolithiques dimensionnés ; la référence entreprise
utilise stockage objet et composants distribués lorsque le volume le justifie.

**Traite :** `ASIS-016`, `ASIS-017`, `ASIS-018`, `ASIS-019`.

**Preuve :** `T14-observability-and-slo-ready.md`.

## T15 — Automatiser sauvegardes, restauration et DR

**Objectif :** prouver la reprise de bout en bout, pas seulement la présence de
fichiers de sauvegarde.

**Contenu :** sauvegardes Kubernetes/data/secrets, copie dans un domaine de
panne distinct, rétention, chiffrement, tests PITR, reconstruction de cluster,
runbook et mesure réelle du RTO/RPO.

**Traite :** `ASIS-003`, `ASIS-005`, `ASIS-007`, `ASIS-022`.

**Preuve :** `T15-disaster-recovery-proven.md`.

## T16 — Standardiser l'expérience des équipes

**Objectif :** transformer la plateforme en produit utilisable sans dépendance
permanente à l'équipe Platform.

**Contenu :** template de service, chart ou base commune, documentation,
ownership, self-service borné, scorecard et parcours d'onboarding. Un portail
développeur n'est ajouté que si le besoin dépasse les templates et la docs.

**Traite :** `ASIS-012`, `ASIS-013` et la dépendance Platform observée.

**Preuve :** `T16-developer-golden-path-ready.md`.

## T17 — Exécuter les tests de résilience et de sécurité

**Objectif :** soumettre la cible à des pannes et abus contrôlés.

**Contenu :** perte de Pod/nœud, indisponibilité data, restauration, saturation,
drift GitOps, image non conforme, secret révoqué, accès interdit et rollback de
release. Aucun test destructif ne vise l'AS-IS sans autorisation spécifique.

**Preuve :** `T17-resilience-security-game-days.md`.

## T18 — Auditer le TO-BE et mesurer les progrès

**Objectif :** comparer factuellement AS-IS et TO-BE et enregistrer les dettes
restantes sans déclarer l'architecture « parfaite ».

**Livrables :** matrice finale des 22 constats, résultats SLO/RTO/RPO, coûts et
capacités, risques acceptés, diagramme final, runbooks et synthèse portfolio.

**Preuve :** `T18-to-be-audit-complete.md`.

## Condition de clôture de la phase 2

La phase 2 est terminée lorsque les exigences T01 sont mesurées, chaque constat
M16 est corrigé ou explicitement accepté, les chemins de migration/rollback et
de restauration sont testés, et la différence entre production d'entreprise
et démonstration du lab reste honnête.
