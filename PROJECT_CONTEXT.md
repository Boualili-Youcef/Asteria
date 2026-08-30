# Contexte du projet Asteria

## 1. Finalité du projet

Asteria est un projet de portfolio conçu comme une véritable mission de
Platform Engineering et de DevSecOps. Il ne s'agit pas de produire une simple
démonstration Kubernetes : le projet doit montrer comment une architecture
d'entreprise existante est reconstruite, comprise, auditée puis améliorée de
manière progressive et justifiable.

Le lab représente une version réduite d'une infrastructure réelle. Les choix
doivent rester crédibles pour l'entreprise simulée tout en étant exécutables
dans les quotas OpenStack disponibles.

## 2. Scénario d'entreprise

L'organisation simulée est une PME SaaS européenne comptant environ 100 à 500
employés et servant des clients B2B. Elle utilise un cloud OpenStack privé pour
des raisons de contrôle et de souveraineté.

Dans la référence d'entreprise :

- plusieurs environnements et davantage d'applications existent ;
- les équipes de développement livrent plusieurs services ;
- une équipe Platform/DevOps administre l'infrastructure ;
- une équipe Sécurité/Audit effectue encore plusieurs contrôles manuels ;
- des services externes ou partagés fournissent DNS, Git, CI, registre de
  conteneurs, stockage objet et artefacts de pipelines.

La plateforme est fonctionnelle, mais sa standardisation, sa sécurité, son
observabilité et son processus de livraison sont incomplets.

## 3. Rôle joué dans le projet

La phase 1 est terminée : le rôle consistait à reconstituer fidèlement l'état
AS-IS, comme une équipe chargée de reconstruire et documenter l'existant.

Depuis l'approbation du **30 août 2026**, la phase courante est la phase 2. Le
rôle est celui d'un Platform Engineer arrivant dans l'organisation pour :

1. auditer l'existant à partir de preuves ;
2. identifier les risques et les points de friction ;
3. définir une architecture cible ;
4. moderniser progressivement la plateforme selon les standards retenus ;
5. mesurer les résultats, tester les retours arrière et rendre visibles les
   risques résiduels.

Le point de départ AS-IS reste figé dans ses documents et preuves. Les
améliorations appartiennent à `docs/phase-2-to-be/` et ne doivent pas réécrire
l'historique pour le rendre artificiellement meilleur.

## 4. Architecture AS-IS validée

Le diagramme de référence courant est `archi.md`. Le PDF présent à la racine
représente la conception initiale antérieure au diagnostic Neutron ; il est
conservé comme historique et ne constitue plus une source de vérité.

### 4.1 Infrastructure OpenStack du lab

- un réseau provider OpenStack partagé, `prive`, comme unique underlay ;
- un port Neutron géré par Terraform pour chaque VM ;
- une port security effective attendue sur ces ports sans renseigner l'attribut
  interdit par la policy du réseau provider partagé ;
- des zones management, application, ingress et data matérialisées par cinq
  security groups dédiés ;
- un overlay K3s Flannel VXLAN pour les Pods ;
- une entrée NodePort privée accessible depuis le bastion ;
- aucun réseau self-service, routeur L3, Floating IP ou Octavia dans le lab.
- un config-drive Nova demandé pour chaque VM afin de ne pas dépendre du
  metadata service pour l'injection de la clé SSH.

### 4.2 Machines de la référence lab actuelle

| Machine | Fonction | Dimensionnement de référence |
|---|---|---:|
| `bastion-admin-01` | Administration et outillage | 1 vCPU / 1 Go |
| `k8s-control-plane-01` | Control plane Kubernetes non HA | 2 vCPU / 4 Go |
| `k8s-worker-01` | Worker Kubernetes | 2 vCPU / 4 Go |
| `k8s-worker-02` | Worker Kubernetes | 2 vCPU / 4 Go |
| `db-postgres-01` | PostgreSQL primaire hors cluster | 2 vCPU / 4 Go |

Empreinte de référence : **5 instances, 9 vCPU et 17 Go de RAM**.

M03 a confirmé des quotas de 10 vCPU et 20 Go de RAM. Un troisième worker
porterait l'empreinte à 11 vCPU et 21 Go : cette variante est rejetée. La
baseline de phase 1 reste définitivement à deux workers.

### 4.3 Composants Kubernetes

- `ingress-nginx` comme entrée commune ;
- `identity-api` dans `team-identity`, déployée avec des YAML bruts ;
- `orders-api` dans `team-orders`, déployée avec un chart Helm interne ;
- `notifications-worker` dans `team-notifications`, déployé manuellement avec
  `kubectl apply` ;
- Redis partagé avec une isolation faible ;
- Prometheus partiel, dashboards Grafana manuels et logs non centralisés.

### 4.4 Données, livraison et administration

- PostgreSQL s'exécute sur une VM séparée, sans réplication ni haute
  disponibilité ;
- une sauvegarde PostgreSQL initiale existe localement sur la VM, sans
  planification, copie objet ni restauration testée ;
- deux pipelines GitHub Actions distincts livrent Identity et Orders, tandis
  que Notifications reste hors runner ;
- GHCR est le registre retenu par M15 pour Identity et Orders ;
- les workloads M14 exécutent encore les images M13 importées manuellement :
  les images GHCR publiées ne sont pas déployées automatiquement ;
- les opérations et audits passent par le bastion depuis le réseau
  d'entreprise simulé.

## 5. Contraintes OpenStack

Les limites confirmées par l'inventaire M03 du 15 juillet 2026 sont :

- 8 instances au maximum ;
- 10 vCPU au maximum ;
- 20 Go de RAM au maximum.

Ces valeurs sont des limites maximales, pas une mesure de la capacité encore
libre. La consommation actuelle doit être contrôlée avant tout apply. M03 a
confirmé `prive` comme réseau externe partagé, actif et non géré par Asteria,
avec le CIDR `172.28.0.0/16`. L'API Floating IP retourne toujours une erreur
404 et aucun service Octavia n'est confirmé dans la baseline exécutable. Les
tests M05 ont ensuite confirmé l'absence de l'extension routeur/L3, l'échec de
création des réseaux self-service en HTTP 503 et l'échec des routeurs en HTTP
404. `docs/adr/ADR-001-provider-network-fallback.md` formalise l'adaptation.

Principes obligatoires :

- distinguer en permanence l'architecture d'entreprise et son implémentation
  réduite dans le lab ;
- ne créer aucune VM avant le design réseau et la validation du plan
  Terraform ;
- ne jamais stocker de secret OpenStack, clé privée ou mot de passe dans Git ;
- documenter toute adaptation imposée par les quotas ou services disponibles.

## 6. Périmètre livré en phase 1

La phase 1 a construit et documenté :

- le dépôt, ses règles de travail et son système de preuves ;
- le contexte métier et le diagramme AS-IS figé ;
- l'inventaire réel du tenant OpenStack ;
- le design réseau et les security groups ;
- le provisionnement OpenStack avec Terraform ;
- le bastion et la configuration des machines ;
- PostgreSQL sur une VM distincte ;
- un cluster Kubernetes réduit avec un seul control plane ;
- l'Ingress, Redis et une observabilité partielle ;
- les trois applications représentatives ;
- les trois modes de livraison volontairement hétérogènes ;
- l'audit final des limites et dettes de l'AS-IS.

## 7. Dettes AS-IS à conserver volontairement

Les éléments suivants ne sont pas des oublis de la phase 1 :

- control plane Kubernetes non HA ;
- PostgreSQL primaire unique sans réplication ;
- CI/CD hétérogène et absence de golden path ;
- absence de GitOps commun et déploiements directs encore possibles ;
- scans d'images et SBOM non systématiques ;
- RBAC partiel, peu de NetworkPolicies et aucune policy-as-code généralisée ;
- monitoring incomplet, sans SLO ni alerting homogène ;
- logs consultés fréquemment avec `kubectl logs` ;
- Redis partagé et faiblement isolé ;
- sauvegardes présentes mais restauration non testée ;
- forte dépendance envers l'équipe Platform.

Ces dettes doivent être visibles, documentées et démontrables afin d'alimenter
l'audit et la transformation de la phase 2.

## 8. Périmètre de la phase 2

La phase 2 est pilotée par `PHASE_2_BACKLOG.md`. Elle doit :

- définir SLO, RTO/RPO, modèle de menace et critères mesurables ;
- réinventorier les deux projets OpenStack avant de distribuer leurs rôles ;
- approuver les décisions importantes par ADR ;
- sécuriser les fondations et conserver un rollback avant chaque migration ;
- construire accès Zero Trust, Kubernetes sécurisé, Gateway API, secrets,
  données fiables, golden path CI, GitOps et observabilité ;
- tester les restaurations, pannes, accès refusés et politiques ;
- comparer factuellement les 22 constats AS-IS à l'état final TO-BE.

L'architecture entreprise et l'implémentation lab sont toujours distinguées.
Une capacité HA ou DR n'est jamais revendiquée si le lab ne possède pas les
domaines de panne nécessaires.

## 9. Hors périmètre historique de la phase 1

Sauf instruction explicite modifiant la phase, ne pas introduire :

- un control plane ou PostgreSQL hautement disponibles ;
- une plateforme GitOps complète ;
- une golden path ou un portail développeur mature ;
- une gestion centralisée et avancée des secrets ;
- une politique Kyverno ou OPA généralisée ;
- une supply chain complète avec scans bloquants et SBOM obligatoires ;
- une observabilité complète avec logs centralisés, SLO et alerting homogène ;
- des corrections silencieuses rendant l'AS-IS artificiellement parfait.

Les bonnes pratiques indispensables à la sécurité du lab restent obligatoires.
Conserver une dette réaliste ne signifie jamais publier des secrets ou prendre
un risque inutile sur l'environnement réel.

## 10. Méthode de travail et preuves

Le projet avance mission par mission selon `PHASE_2_BACKLOG.md`. Une mission
n'est terminée que lorsque :

1. ses livrables existent ;
2. les validations prévues réussissent ou leurs écarts sont expliqués ;
3. une preuve est enregistrée sous `docs/evidence/phase-2/` ;
4. les décisions et hypothèses sont traçables ;
5. la prochaine mission peut commencer sans dépendance cachée.

## 11. Sources de vérité

En cas de contradiction, appliquer cet ordre :

1. inventaires et validations techniques capturés pendant les missions ;
2. ADR approuvées et exigences de phase 2 ;
3. décisions explicitement approuvées dans ce fichier ;
4. `PHASE_2_BACKLOG.md`, ordre et critères de transformation ;
5. `archi.md` et les preuves M00-M16 pour le point de départ AS-IS ;
6. `contexte.md`, matériau de cadrage initial non normatif.

Toute contradiction doit être signalée et résolue dans la documentation avant
qu'elle n'affecte une ressource réelle.
