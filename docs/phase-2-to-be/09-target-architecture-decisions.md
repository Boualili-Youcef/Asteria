# Architecture cible approuvée et registre de décision T03

## 1. But et statut

T03 transforme le candidat T00 en une cible approuvée, compatible avec les
exigences T01 et les capacités T02. L'approbation du 30 août 2026 vaut décision
technique pour le projet et le lab ; elle ne transforme pas les SLO candidats
en engagement contractuel ni les hypothèses métier en faits.

**Statut : approuvée.** Aucun runtime, apply Terraform, trafic ou donnée n'est
modifié par T03.

## 2. Faits vérifiés

- le projet source exécute cinq VM, 9 vCPU et 17 Go sur 10 vCPU/20 Go ;
- le projet secondaire est vide mais limité à 4 VM, 4 vCPU et 8 Go ;
- une seule AZ `nova` est visible et aucun Cinder, Swift/S3, Octavia, Designate,
  L3 ou Floating IP n'est fourni ;
- les deux projets voient le réseau provider `prive` ; le succès du chemin
  inter-projets reste un gate T05 ;
- le source utilise K3s `v1.36.2+k3s1`, Flannel et SQLite ;
- les 33 exigences T01 couvrent les 22 constats M16.

## 3. Hypothèses et approbations encore nécessaires

| ID | Hypothèse | Traitement décidé |
|---|---|---|
| HYP-T03-01 | GitHub reste utilisable pour SSO lab, CI, GitOps et GHCR. | dépendance externe acceptée pour le portfolio ; repli local/break-glass documenté |
| HYP-T03-02 | Une cible S3-compatible externe pourra être fournie. | gate bloquant avant T15 ; aucune cible n'est inventée |
| HYP-T03-03 | Les composants approuvés tiennent dans les VM existantes. | requests/limits, mesure avant/après et installation par étapes |
| HYP-T03-04 | Les SLO/RTO/RPO T01 sont adaptés au scénario métier. | seuils techniques du lab approuvés ; validation Produit/Data demeure ouverte |
| HYP-T03-05 | Une fenêtre de reconstruction source sera acceptable. | approbation explicite exigée après T17, jamais implicite |

## 4. Décisions approuvées

Les vues approuvées sont `to-be-enterprise-architecture.mmd`,
`to-be-lab-approved.mmd` et `to-be-trust-boundaries.mmd`. Le fichier
`to-be-lab-candidate.mmd` reste la proposition historique T00.

| Domaine | Référence entreprise | Adaptation lab | ADR |
|---|---|---|---|
| Kubernetes/CNI | RKE2 HA multi-domaines + Cilium/Hubble | K3s staging et source reconstruit, Cilium, sans HA revendiquée | ADR-002 |
| Entrée | Gateway API + Envoy + LB/DNS/TLS | mêmes APIs, NodePort privé et TLS de lab | ADR-003 |
| Projets | prod/staging/shared séparés | source production-like, secondaire staging CAP-05 | ADR-004 |
| Accès | Teleport HA avec OIDC/MFA licencié | Teleport Community, GitHub SSO/MFA, bastion break-glass | ADR-005 |
| Identité | IdP OIDC d'entreprise/Keycloak HA | Keycloak mono-nœud et données synthétiques | ADR-006 |
| Secrets | OpenBao Raft HA + ESO | OpenBao/ESO mono-nœud, snapshots obligatoires | ADR-007 |
| PostgreSQL | VMs Patroni ou service managé qualifié | VM unique, TLS, pgBackRest/WAL/PITR, sans HA | ADR-008 |
| Cache/bus | Valkey + NATS JetStream 3 nœuds | instances uniques, cache jetable et bus durable logique | ADR-009 |
| GitOps | Argo CD HA | Argo CD non-HA sur staging, droits bornés | ADR-010 |
| Supply chain | workflow commun, SBOM, provenance, policy | GitHub/GHCR/Cosign keyless, promotion par digest | ADR-011 |
| Observabilité | Prometheus/Loki/Tempo/OTel avec stockage durable | modes monolithiques plafonnés, rétention courte | ADR-012 |
| Reprise | objet externe multi-domaines + restores | S3 externe requis ; copie opérateur T04 seulement transitoire | ADR-013 |
| Migration | blue/green | répétition staging puis reconstruction source contrôlée | ADR-014 |

## 5. Évaluation capacité, compatibilité, exploitation et rollback

| ADR | Capacité/coût opérationnel | Compatibilité à verrouiller | Rollback principal | ASIS |
|---|---|---|---|---|
| 002 | staging à 100 % du quota ; UI Hubble optionnelle | K3s 1.36, noyau, Cilium | recréation staging ; SQLite+token source | 001,003,004,020 |
| 003 | contrôleur + proxies mesurés | Envoy/Gateway API/K8s | coexistence puis retour ingress | 002,021 |
| 004 | aucun quota mutualisé ; exception marge staging | config-drive et réseau T05 | ROLE-04 ou suppression staging autorisée | 001,020,022 |
| 005 | Teleport mesuré sur bastion 1/1 | édition Community, GitHub SSO, TLS | SSH/kubeconfig break-glass | 004,011,018,019 |
| 006 | Keycloak mono-nœud plafonné | OIDC clients, issuer/audience | routes privées AS-IS conservées | 010,018 |
| 007 | OpenBao/ESO ajoutés par étapes | auth Kubernetes et chart épinglé | ancien Secret temporaire | 004,011,014 |
| 008 | aucune VM data ajoutée | PostgreSQL 16, TLS, pgBackRest/S3 | config + dump/WAL antérieurs | 005,006,009,022 |
| 009 | services uniques en lab | clients NATS/Valkey et stockage local | double écriture/ancien chemin borné | 007,009,020 |
| 010 | installation non-HA, Applications bornées | K8s/CRD/chart épinglés | revert Git/digest | 012,015 |
| 011 | temps CI et rétention acceptés | identities OIDC/Cosign/Kyverno | digest antérieur déjà vérifié | 013,014,015 |
| 012 | ajout progressif, rétention courte | formats OTLP et versions charts | réduire collecte, garder signaux critiques | 016-020 |
| 013 | cible externe non budgétée = gate | clients S3, chiffrement, restore | conserver ancienne chaîne | 003,005,007,011,022 |
| 014 | fenêtre de maintenance lab acceptée en principe | manifests portables et backups lisibles | restauration source + ancienne entrée | 003,005,012,020,022 |

Les versions de déploiement ne sont pas figées artificiellement par T03 : la
version stable supportée est épinglée avec digest/chart et matrice de
compatibilité dans la mission qui l'installe. Une dérive de matrice rouvre
l'ADR concernée.

## 6. Impact, sauvegarde, arrêt et rollback

T03 ajoute uniquement de la documentation. Ajouts futurs : staging, contrôles
d'accès, controllers, data services séparés et télémétrie. Remplacements futurs :
Flannel, ingress-nginx, Redis événementiel et déploiements directs. Aucune
destruction n'est autorisée par ce document.

Avant toute migration : T04/T15 validés, checksums lisibles, répétition staging,
plan sans destruction inattendue, fenêtre et propriétaire approuvés. Arrêt si
la capacité dépasse quota, si un refus attendu devient succès, si le backup ne
se restaure pas ou si les données ne se rapprochent pas.

## 7. Validation T03

- les treize domaines minimaux possèdent une ADR acceptée ;
- chaque ADR distingue entreprise et lab, alternatives, capacité,
  compatibilité, coût opérationnel et rollback ;
- les 22 constats sont couverts par les décisions ou missions aval ;
- CAP-05 et l'absence de green/HA/DR lab sont visibles dans le diagramme ;
- le candidat T00 est marqué comme historique ;
- aucune commande mutante n'a été exécutée.

## 8. Sources primaires contrôlées le 30 août 2026

- [RKE2, options réseau](https://docs.rke2.io/networking/basic_network_options)
- [K3s, CNI personnalisé](https://docs.k3s.io/networking/basic-network-options#custom-cni)
- [K3s, backup et restauration](https://docs.k3s.io/datastore/backup-restore)
- [Envoy Gateway, compatibilité](https://gateway.envoyproxy.io/news/releases/matrix/)
- [Teleport, configuration](https://goteleport.com/docs/reference/deployment/config/)
- [OpenBao, stockage Raft](https://openbao.org/docs/configuration/storage/raft/)
- [Argo CD, installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Velero, File System Backup](https://velero.io/docs/v1.17/file-system-backup/)
