# Backlog chronologique — Phase 1 AS-IS

## Règles de progression

Statuts autorisés : `À faire`, `En cours`, `Bloquée`, `Terminée`.

Une seule mission doit être `En cours`. Une mission devient `Terminée` lorsque
ses livrables, validations et preuves satisfont ses critères d'acceptation.
L'ordre ci-dessous protège les dépendances.

## Vue d'ensemble

| Mission | Intitulé | Statut | Dépend de |
|---|---|---|---|
| M00 | Initialiser le dépôt et les fichiers de pilotage | Terminée | — |
| M01 | Documenter le contexte entreprise | Terminée | M00 |
| M02 | Figer et expliquer l'architecture AS-IS | Terminée | M01 |
| M03 | Inventorier l'environnement OpenStack | Terminée | M02 |
| M04 | Concevoir les réseaux et security groups | Terminée | M03 |
| M05 | Écrire et appliquer Terraform réseau | Terminée | M04 |
| M06 | Créer les machines avec Terraform | Terminée | M05 |
| M07 | Configurer le bastion | Terminée | M06 |
| M08 | Installer PostgreSQL sur VM séparée | Terminée | M07 |
| M09 | Installer le cluster Kubernetes | Terminée | M07 |
| M10 | Installer l'Ingress et préparer les namespaces | À faire | M09 |
| M11 | Déployer Redis partagé | À faire | M10 |
| M12 | Déployer l'observabilité partielle | À faire | M10 |
| M13 | Créer les trois applications | À faire | M08, M11 |
| M14 | Déployer les applications de manière hétérogène | À faire | M12, M13 |
| M15 | Mettre en place le CI/CD hétérogène | À faire | M14 |
| M16 | Auditer et documenter les problèmes AS-IS | À faire | M15 |

## M00 — Initialiser le dépôt et les fichiers de pilotage

**Objectif :** disposer d'un dépôt Git structuré et d'un contrat clair pour
piloter toutes les missions suivantes.

**Livrables :**

- `README.md`, `PROJECT_CONTEXT.md`, `AGENTS.md` et
  `PHASE_1_BACKLOG.md` ;
- arborescence initiale des domaines ;
- dépôt Git local sur la branche `main` ;
- `docs/evidence/phase-1/M00-repository-initialized.md`.

**Validation :** vérifier l'arborescence, relire les documents, exécuter
`git status --short --branch` et contrôler qu'aucun secret n'est suivi.

**Critère d'acceptation :** documents cohérents avec l'architecture validée, Git
initialisé et aucune ressource OpenStack créée.

## M01 — Documenter le contexte entreprise

**Objectif :** rendre le scénario métier compréhensible sans l'historique de
conversation.

**Livrable :** `docs/phase-1-as-is/00-business-context.md`.

**Contenu :** entreprise, taille, équipes, produits B2B, cloud privé, état
actuel, irritants et mandat du futur Platform Engineer.

**Validation :** aucune contradiction avec `PROJECT_CONTEXT.md` ou `archi.md`.

**Preuve :** `M01-business-context-written.md`.

## M02 — Figer et expliquer l'architecture AS-IS

**Objectif :** expliquer chaque composant et empêcher une modernisation
involontaire pendant la phase 1.

**Livrables :**

- `docs/diagrams/as-is-architecture.mmd` ;
- `docs/phase-1-as-is/01-as-is-architecture.md` ;
- inventaire des flux utilisateurs, applicatifs, de livraison,
  d'administration, d'observabilité et de sauvegarde.

**Validation :** comparer le diagramme à `archi.md` et distinguer clairement la
référence entreprise du lab.

**Preuve :** `M02-as-is-architecture-frozen.md`.

## M03 — Inventorier l'environnement OpenStack

**Objectif :** remplacer les hypothèses par les capacités réelles du tenant
avant toute infrastructure as code.

**Livrable :** `docs/phase-1-as-is/02-openstack-lab-constraints.md`.

**Commandes indicatives :**

```bash
openstack quota show
openstack flavor list
openstack image list
openstack network list
openstack security group list
openstack floating ip list
```

**Validation :** confirmer quotas, flavors, images, réseau externe, Floating IP
et disponibilité d'Octavia. Arbitrer la baseline à deux ou trois workers.

**Preuve :** `M03-openstack-inventory.md`, sans donnée sensible.

## M04 — Concevoir les réseaux et security groups

**Objectif :** définir l'underlay disponible, les ports et les flux avant de les
créer.

**Livrables :**

- `docs/phase-1-as-is/03-network-design.md` ;
- `docs/phase-1-as-is/04-instance-sizing.md` ;
- `docs/phase-1-as-is/05-security-groups.md`.

**Validation :** topologie provider-network-only conforme à M03/ADR-001,
matrice source/destination, ports justifiés et SG sous quotas.

**Preuve :** `M04-network-design-approved.md`.

## M05 — Écrire et appliquer Terraform réseau

**Objectif :** référencer le réseau provider et créer de façon reproductible
ports Neutron, security groups et mécanisme d'exposition.

**Livrables :** configuration sous `infra/terraform/openstack/`, variables
documentées et outputs utiles.

**Validation :** `terraform fmt -check`, `terraform init`,
`terraform validate`, examen du plan, puis apply explicitement validé et
contrôles avec OpenStack CLI.

**Preuve :** `M05-terraform-network-apply.md`.

## M06 — Créer les machines avec Terraform

**Objectif :** provisionner bastion, nœuds Kubernetes et PostgreSQL dans la
baseline confirmée en M03.

**Livrables :** ressources compute attachées aux ports M05, clés et outputs non
sensibles sous `infra/terraform/openstack/`.

**Validation :** aucun remplacement inattendu, instances actives, bonnes
interfaces et accès conformes à M04.

**Preuve :** `M06-openstack-instances-created.md`.

## M07 — Configurer le bastion

**Objectif :** établir le point d'administration reproductible.

**Livrables :** inventaire et automatisation Ansible, documentation d'accès et
outils OpenStack CLI, Terraform, Ansible, kubectl, Helm, psql, Git, jq et curl.

**Validation :** versions, accès autorisés et absence d'accès public imprévu.

**Preuve :** `M07-bastion-ready.md`.

## M08 — Installer PostgreSQL sur VM séparée

**Objectif :** reconstruire la base externe au cluster, primaire unique non HA.

**Livrables :** automatisation, bases et comptes des services, configuration
réseau et sauvegarde basique non industrialisée.

**Validation :** service actif, connexions prévues autorisées et autres sources
refusées.

**Preuve :** `M08-postgres-vm-ready.md`.

## M09 — Installer le cluster Kubernetes

**Objectif :** créer un cluster réduit avec un control plane non HA et le nombre
de workers validé en M03.

**Livrables :** automatisation, kubeconfig protégé et procédure opératoire.

**Validation :** `kubectl get nodes -o wide`, `kubectl get pods -A` et tests de
connectivité requis.

**Preuve :** `M09-kubernetes-cluster-ready.md`.

## M10 — Installer l'Ingress et préparer les namespaces

**Objectif :** créer l'entrée commune et le découpage logique AS-IS.

**Livrables :** ingress-nginx et namespaces `team-identity`, `team-orders`,
`team-notifications`, `shared` et `monitoring`.

**Validation :** contrôleur disponible, chemin Floating IP/NodePort démontré et
endpoint de test accessible.

**Preuve :** `M10-ingress-and-namespaces-ready.md`.

## M11 — Déployer Redis partagé

**Objectif :** représenter la dépendance partagée et faiblement isolée.

**Livrables :** manifests sous `k8s/current-state/` et dette documentée.

**Validation :** Redis disponible et connexion depuis les workloads prévus.

**Preuve :** `M11-redis-shared-deployed.md`.

## M12 — Déployer l'observabilité partielle

**Objectif :** fournir Prometheus et Grafana sans masquer l'immaturité AS-IS.

**Livrables :** configuration sous `monitoring/current-state/`, métriques
partielles et dashboards manuels.

**Validation :** targets et dashboard visibles ; absence de SLO, alerting
homogène et logs centralisés explicitement documentée.

**Preuve :** `M12-monitoring-partial-ready.md`.

## M13 — Créer les trois applications

**Objectif :** produire `identity-api`, `orders-api` et
`notifications-worker` avec le minimum fonctionnel nécessaire.

**Livrables :** code, dépendances, tests et images conteneurisables sous `apps/`.
Les APIs exposent santé, disponibilité et métriques ; le worker fournit un
mécanisme équivalent adapté.

**Validation :** tests locaux, build des images, accès à PostgreSQL/Redis selon
le service et aucun secret embarqué.

**Preuve :** `M13-applications-built-locally.md`.

## M14 — Déployer les applications de manière hétérogène

**Objectif :** matérialiser l'absence de golden path.

**Livrables :** YAML brut pour `identity-api`, chart Helm interne pour
`orders-api` et procédure `kubectl apply` manuelle pour
`notifications-worker`.

**Validation :** workloads, routes et worker fonctionnels ; différences de
déploiement documentées.

**Preuve :** `M14-heterogeneous-deployments.md`.

## M15 — Mettre en place le CI/CD hétérogène

**Objectif :** reproduire une livraison partiellement industrialisée.

**Livrables :** build/push sans scan pour `identity-api`, tests/build/push sans
SBOM pour `orders-api` et procédure manuelle pour `notifications-worker`.

**Validation :** exécutions observables, images identifiables, artefacts partiels
et écarts documentés.

**Preuve :** `M15-cicd-fragmented.md`.

## M16 — Auditer et documenter les problèmes AS-IS

**Objectif :** clôturer la phase 1 avec un état factuel servant d'entrée à la
phase 2.

**Livrables :**

- `docs/phase-1-as-is/06-deployment-methods.md` ;
- `docs/phase-1-as-is/07-observability-as-is.md` ;
- `docs/phase-1-as-is/08-as-is-known-issues.md`.

**Validation :** chaque constat est relié à une preuve, qualifié par impact et
séparé des recommandations TO-BE.

**Preuve :** `M16-as-is-audit-complete.md`.

## Condition de clôture de la phase 1

M00 à M16 sont toutes `Terminée`, l'AS-IS fonctionne dans les limites du lab et
ses dettes sont observables, reproductibles et documentées. La conception TO-BE
peut alors commencer comme une phase explicitement approuvée.
