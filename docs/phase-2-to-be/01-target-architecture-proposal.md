# Proposition d'architecture cible Asteria

## 1. Statut

Ce document conserve la **proposition initiale T00**. Elle a été évaluée par
T01/T02 puis remplacée, le 30 août 2026, par l'architecture approuvée dans
`09-target-architecture-decisions.md` et les ADR-002 à ADR-014. Les divergences
entre ce candidat historique et la décision T03 sont intentionnelles : le lab
n'a notamment pas la capacité d'héberger un green de production complet.

Deux vues sont obligatoires :

- une référence entreprise crédible pour environ 500 employés ;
- une implémentation de lab honnête, limitée par OpenStack.

## 2. Synthèse du TO-BE proposé

| Domaine | AS-IS | Candidat TO-BE |
|---|---|---|
| Administration | Bastion et clé SSH durable | Teleport, OIDC/MFA, RBAC, certificats courts ; bastion break-glass |
| Environnements | Un seul cluster prod-like | projets/clusters séparés pour production, staging et services partagés selon T02 |
| Réseau Kubernetes | Flannel, zéro NetworkPolicy | Cilium, default-deny, policies L3/L4/L7 et Hubble |
| Entrée | ingress-nginx retiré, NodePort privé | Gateway API + Envoy Gateway + TLS ; NodePort seulement comme adaptation lab |
| Identités | kubeconfig admin et APIs anonymes | OIDC, ServiceAccounts dédiés, rôles par équipe et autorisation métier |
| Secrets | fichiers locaux et Secrets manuels | OpenBao + External Secrets, auth Kubernetes, rotation et audit |
| Politiques | contrôle manuel | PSA + Kyverno audit puis enforce + vérification d'images |
| PostgreSQL | primaire VM unique, backup local | TLS, réplication validée, WAL/base backups objet, PITR et restore drills |
| Cache/messaging | Redis partagé utilisé pour tout | Valkey par usage cache ; événementiel durable séparé avec outbox et DLQ |
| CI | workflows fragmentés | workflow réutilisable : tests, scans, SBOM, provenance, digest |
| CD | kubectl/Helm/YAML manuels | Argo CD, promotion par digest, drift et rollback Git |
| Observabilité | métriques partielles et stockage éphémère | Prometheus/Alertmanager, Grafana OIDC, Loki, Tempo, OTel, SLO |
| Reprise | aucune restauration testée | backups multi-domaines, reconstruction et game days mesurés |
| Expérience dev | trois chemins incompatibles | template et contrat de service communs, exceptions gouvernées |

## 3. Architecture entreprise

Le diagramme source est
`docs/diagrams/to-be-enterprise-architecture.mmd`.

### 3.1 Accès et identités

Les administrateurs s'authentifient auprès d'un fournisseur OIDC avec MFA.
Teleport émet des certificats courts et applique le RBAC pour SSH, Kubernetes
et PostgreSQL. Aucun utilisateur ne conserve une clé SSH permanente comme
chemin quotidien. Un accès break-glass hors bande est protégé, testé et audité.

Les clients B2B et les équipes utilisent un IdP OIDC. Les applications
valident les tokens et appliquent les autorisations métier. Les workloads
possèdent des ServiceAccounts distincts.

### 3.2 Infrastructure et environnements

La référence entreprise sépare production, staging et services partagés dans
des projets OpenStack et states Terraform distincts. La production réelle
utilise au moins trois domaines de panne pour le control plane, les workers et
les données. Les services partagés ne deviennent pas une voie réseau implicite
vers toutes les charges.

### 3.3 Kubernetes et réseau

Le cluster cible conserve une API Kubernetes standard. La distribution exacte
est une décision T03. Cilium fournit CNI, NetworkPolicies et visibilité Hubble.
Les namespaces commencent en default-deny ; DNS, Gateway, data, observabilité
et dépendances externes sont ouverts explicitement.

Gateway API sépare les responsabilités de l'infrastructure (`GatewayClass` et
`Gateway`) de celles des équipes (`HTTPRoute`). Envoy Gateway est le contrôleur
candidat. Cette direction remplace ingress-nginx, dont la maintenance a pris
fin en mars 2026. Gateway API possède des ressources stables et un modèle de
rôles adapté aux équipes plateforme et applicatives.

### 3.4 Plateforme et livraison

Argo CD réconcilie l'état déclaré. Les équipes ne possèdent pas de kubeconfig
administrateur pour déployer. La CI construit une seule fois et publie dans
GHCR avec digest, tests, scan, SBOM et provenance. La promotion modifie le
digest du dépôt GitOps ; Argo CD applique et vérifie la santé.

Kyverno commence en audit afin de mesurer les violations, puis bloque les
nouveaux écarts : images sans provenance, tags mutables, Pods privilégiés,
absence de ressources/probes/labels et configurations réseau interdites.

### 3.5 Secrets et données

OpenBao est le candidat souverain pour le stockage et le cycle de vie des
secrets. External Secrets s'authentifie avec l'identité Kubernetes et ne dépend
pas d'un token statique global. La référence entreprise exécute OpenBao en HA
avec stockage Raft, audit et procédures d'unseal/recovery.

PostgreSQL peut être opéré par CloudNativePG uniquement si l'infrastructure
fournit trois nœuds et stockages indépendants. Sinon, un cluster PostgreSQL sur
VMs est plus honnête. Dans les deux cas, TLS, réplication, sauvegardes physiques,
WAL, PITR et tests de restauration sont obligatoires. Un simple `pg_dump`
quotidien ne représente pas le plan de continuité.

Valkey est limité au cache. La notification asynchrone utilise un bus durable
distinct, couplé à une outbox transactionnelle, des consommateurs idempotents,
des retries bornés et une DLQ.

### 3.6 Observabilité et exploitation

Prometheus et Alertmanager pilotent métriques et alertes. Loki centralise les
logs, Tempo reçoit les traces via OpenTelemetry Collector, et Grafana utilise
OIDC sans accès anonyme. Les règles et dashboards partent des parcours T01 et
de leurs SLO, pas d'une collection de métriques sans objectif.

Les données d'observabilité et les backups utilisent un stockage durable. Les
sauvegardes critiques sont copiées dans un projet ou domaine de panne distinct.

## 4. Adaptation proposée pour le lab

Le diagramme source est `docs/diagrams/to-be-lab-candidate.mmd`.

### 4.1 Ce que le lab peut démontrer

- séparation de credentials, states et rôles entre deux projets ;
- migration blue/green si T02 confirme quotas et connectivité ;
- accès Teleport par identité avec le bastion en secours ;
- cluster cible avec Cilium, Hubble, policies, PSA et Kyverno ;
- Gateway API/Envoy exposé par NodePort privé si aucun LB n'existe ;
- OpenBao et External Secrets en mode dimensionné pour le lab ;
- CI commune, artefacts attestés, GitOps et promotion par digest ;
- TLS PostgreSQL, sauvegarde objet/PITR et restauration mesurée ;
- métriques, alertes, logs et traces en modes monolithiques économes ;
- tests de panne applicative, policy, accès, GitOps et restauration.

### 4.2 Ce que le lab ne doit pas prétendre

- HA de zone sans trois domaines de panne prouvés ;
- exposition Internet stable si L3/Floating IP/Octavia restent absents ;
- stockage hautement disponible avec `local-path` ;
- DR si les deux projets dépendent du même site physique ;
- montée en charge d'une production de 500 employés à partir de quelques VMs ;
- Zero Trust complet si l'IdP ou Teleport reste une instance unique de lab.

### 4.3 Rôle possible du deuxième projet

T02 départagera quatre options :

1. **green cluster**, puis l'ancien projet devient staging/DR ;
2. **staging** permanent séparé de la production ;
3. **services partagés** : accès, secrets, runner et stockage objet ;
4. combinaison réduite si les quotas sont identiques et le réseau commun.

Le choix ne sera pas basé uniquement sur le nombre de vCPU : il faut prouver
le stockage, la connectivité, la sécurité inter-projets et la capacité de
retour arrière.

## 5. Stratégie de migration

1. figer mesures, SLO, RTO/RPO et menaces ;
2. réinventorier les deux projets ;
3. approuver les ADR et le budget de ressources ;
4. corriger le temps et créer des sauvegardes de sécurité ;
5. construire la cible en parallèle ;
6. installer accès, réseau, policies, secrets et observabilité avant les apps ;
7. migrer les données avec répétition et mesure du RPO ;
8. déployer les applications par digest et GitOps ;
9. effectuer smoke, sécurité, charge, restauration et rollback ;
10. basculer progressivement, observer puis décommissionner seulement après la
    période de sécurité approuvée.

## 6. Alternatives à évaluer en T03

| Décision | Candidat | Alternatives à comparer |
|---|---|---|
| Accès | Teleport | bastion durci, VPN overlay/ZTNA, Boundary |
| CNI | Cilium/Hubble | Calico, conservation Flannel + moteur policy |
| Gateway | Envoy Gateway | Cilium Gateway, Traefik |
| GitOps | Argo CD | Flux |
| Policy | Kyverno | ValidatingAdmissionPolicy, Gatekeeper |
| Secrets | OpenBao + External Secrets | Vault, SOPS/age, CSI direct |
| PostgreSQL | CloudNativePG si domaines valides | Patroni sur VMs, PostgreSQL managé |
| Bus | NATS JetStream candidat | RabbitMQ, Kafka selon besoins T01 |
| Logs/traces | Loki + Tempo + OTel | autres backends compatibles OTel |

## 7. Sources techniques initiales

- [Retrait officiel d'ingress-nginx](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) ;
- [modèle de rôles et ressources Gateway API](https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/) ;
- [CNI personnalisés supportés par K3s](https://docs.k3s.io/networking/basic-network-options) ;
- [architecture Cilium et Hubble](https://docs.cilium.io/en/stable/overview/component-overview/) ;
- [rapports de politiques Kyverno](https://main.kyverno.io/docs/guides/reports/) ;
- [certificats courts Teleport](https://goteleport.com/docs/reference/architecture/authentication/) ;
- [OpenBao HA sur Kubernetes](https://openbao.org/docs/platform/k8s/helm/run/) ;
- [authentification Kubernetes d'OpenBao](https://openbao.org/docs/next/auth/kubernetes/) ;
- [External Secrets avec un backend compatible Vault](https://external-secrets.io/latest/provider/hashicorp-vault/) ;
- [architecture CloudNativePG et domaines de panne](https://cloudnative-pg.io/docs/devel/architecture/) ;
- [backups physiques, WAL et PITR CloudNativePG](https://cloudnative-pg.io/docs/devel/backup/) ;
- [attestations et SBOM GitHub Actions](https://docs.github.com/en/actions/concepts/security/artifact-attestations) ;
- [Argo CD ApplicationSet et déploiements progressifs](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/) ;
- [déploiement Kubernetes d'OpenTelemetry Collector](https://opentelemetry.io/docs/platforms/kubernetes/collector/) ;
- [modes de déploiement Loki](https://grafana.com/docs/loki/latest/setup/install/helm/concepts/).

Les versions seront épinglées uniquement au moment des ADR et de
l'implémentation, après contrôle des matrices de compatibilité.
