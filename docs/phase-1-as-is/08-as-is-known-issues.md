# Problèmes connus de l'architecture AS-IS

## 1. Objet

Ce registre clôture la phase 1. Il décrit les défauts et limites observés, leur
impact, et la preuve qui les soutient. Il ne constitue pas encore une
architecture cible.

Les recommandations sont regroupées dans une section séparée afin de ne pas
présenter une intention TO-BE comme une capacité déjà disponible.

## 2. Échelle d'impact

| Niveau | Signification |
|---|---|
| **Élevé** | panne globale, perte de données, exposition importante ou livraison non fiable possible |
| **Moyen** | exploitation fragile, diagnostic lent, dérive ou indisponibilité limitée |
| **Faible** | dette documentaire ou ergonomique sans impact immédiat majeur |

L'impact qualifie la plateforme si elle devait porter le scénario B2B simulé.
L'exposition réseau réelle du lab reste privée et limitée par le VPN, le
bastion et les contrôles compensatoires.

## 3. Registre factuel AS-IS

| ID | Constat observé | Impact | Preuve |
|---|---|---|---|
| ASIS-001 | L'underlay OpenStack est un réseau provider plat partagé. Les références inter-SG n'ont pas isolé seules SSH et les NodePorts ; des contrôles hôte compensatoires ont été nécessaires. | Élevé | [M03](../evidence/phase-1/M03-openstack-inventory.md), [M07](../evidence/phase-1/M07-bastion-ready.md), [M10](../evidence/phase-1/M10-ingress-and-namespaces-ready.md) |
| ASIS-002 | L'entrée du lab est un NodePort privé sur les adresses des workers, sans Floating IP, VIP, Octavia, DNS public ni certificat métier. | Élevé | [M03](../evidence/phase-1/M03-openstack-inventory.md), [M10](../evidence/phase-1/M10-ingress-and-namespaces-ready.md) |
| ASIS-003 | K3s possède un control plane unique, un datastore SQLite local et zéro snapshot K3s observé. | Élevé | [M09](../evidence/phase-1/M09-kubernetes-cluster-ready.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-004 | Le kubeconfig du bastion a des privilèges administratifs larges, les applications n'ont pas de ServiceAccount dédié et aucune NetworkPolicy n'existe dans le cluster. | Élevé | [M09](../evidence/phase-1/M09-kubernetes-cluster-ready.md), [M14](../evidence/phase-1/M14-heterogeneous-deployments.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-005 | PostgreSQL est un primaire unique hors cluster ; `pg_stat_replication` ne montre aucun réplica. Une unique sauvegarde initiale locale existe, sans planification, copie externe ou restauration testée. | Élevé | [M08](../evidence/phase-1/M08-postgres-vm-ready.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-006 | Les connexions PostgreSQL utilisent SCRAM, mais TLS n'est pas imposé par la baseline sur l'underlay partagé. | Élevé | [M08](../evidence/phase-1/M08-postgres-vm-ready.md) |
| ASIS-007 | Redis est un maître unique sans réplica, avec `default on nopass +@all`, trafic non chiffré, PVC `local-path` et aucune NetworkPolicy. | Élevé | [M11](../evidence/phase-1/M11-redis-shared-deployed.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-008 | Les trois applications, Prometheus et Grafana n'ont qu'un replica. Une panne ou maintenance du nœud hébergeant un Pod provoque une interruption jusqu'au redémarrage ailleurs. | Moyen | [M12](../evidence/phase-1/M12-monitoring-partial-ready.md), [M14](../evidence/phase-1/M14-heterogeneous-deployments.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-009 | Les applications créent leurs schémas au démarrage, sans migrations versionnées. Orders persiste puis publie sans outbox, et Notifications consomme une liste Redis sans reprise robuste ni DLQ. | Élevé | [M13](../evidence/phase-1/M13-applications-built-locally.md) |
| ASIS-010 | Les APIs ne fournissent aucune authentification ou autorisation métier ; l'Ingress privé est le principal facteur limitant l'exposition réelle du lab. | Élevé | [M13](../evidence/phase-1/M13-applications-built-locally.md), [M14](../evidence/phase-1/M14-heterogeneous-deployments.md) |
| ASIS-011 | Les mots de passe PostgreSQL sont gérés par des fichiers locaux protégés puis des Secrets Kubernetes créés manuellement, sans coffre central ni rotation automatique. | Élevé | [M08](../evidence/phase-1/M08-postgres-vm-ready.md), [M14](../evidence/phase-1/M14-heterogeneous-deployments.md) |
| ASIS-012 | Trois méthodes de déploiement coexistent : YAML brut, chart Helm spécifique et `kubectl apply` manuel. Il n'existe aucun GitOps, rollback ou historique de promotion commun. | Élevé | [M14](../evidence/phase-1/M14-heterogeneous-deployments.md), [méthodes](06-deployment-methods.md) |
| ASIS-013 | La CI est fragmentée : Identity publie sans tests, Notifications reste hors runner et aucun chemin ne fournit des contrôles homogènes. | Élevé | [M15](../evidence/phase-1/M15-cicd-fragmented.md) |
| ASIS-014 | Aucun pipeline ne produit de scan, SBOM, signature ou provenance. Les actions GitHub utilisent des tags majeurs plutôt que des SHA immuables. | Élevé | [M15](../evidence/phase-1/M15-cicd-fragmented.md) |
| ASIS-015 | Les images GHCR publiées par M15 ne sont pas consommées par M14. Les workloads exécutent des tags M13 importés manuellement sur chaque nœud et non épinglés par digest dans les manifests. | Élevé | [M14](../evidence/phase-1/M14-heterogeneous-deployments.md), [M15](../evidence/phase-1/M15-cicd-fragmented.md), [méthodes](06-deployment-methods.md) |
| ASIS-016 | Prometheus et Grafana utilisent `emptyDir`, avec 24 h de rétention maximum, un dashboard artisanal et aucune couverture dédiée pour PostgreSQL, Redis ou ingress-nginx. | Élevé | [M12](../evidence/phase-1/M12-monitoring-partial-ready.md), [observabilité](07-observability-as-is.md) |
| ASIS-017 | Zéro règle Prometheus, aucun Alertmanager, SLO, logging centralisé ou tracing n'est présent. Les incidents dépendent de l'observation manuelle. | Élevé | [M12](../evidence/phase-1/M12-monitoring-partial-ready.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-018 | Grafana accepte un utilisateur anonyme `Viewer`. Le chemin actuel est privé, mais cette configuration ne doit pas être assimilée à une exposition publique sécurisée. | Moyen | [M12](../evidence/phase-1/M12-monitoring-partial-ready.md) |
| ASIS-019 | Les cinq VM signalent `NTPSynchronized=no` et présentent environ sept minutes de retard, ce qui fragilise certificats, journaux et corrélation des exécutions. | Élevé | [M14](../evidence/phase-1/M14-heterogeneous-deployments.md), [M16](../evidence/phase-1/M16-as-is-audit-complete.md) |
| ASIS-020 | La baseline consomme 9 des 10 vCPU et 17 des 20 Go de RAM autorisés ; les quotas empêchent un troisième worker de taille actuelle et limitent les options de HA. | Moyen | [M03](../evidence/phase-1/M03-openstack-inventory.md), [M06](../evidence/phase-1/M06-openstack-instances-created.md) |
| ASIS-021 | ingress-nginx est figé sur une version issue d'un dépôt archivé ; sa trajectoire de maintenance n'est pas satisfaisante. | Élevé | [M10](../evidence/phase-1/M10-ingress-and-namespaces-ready.md) |
| ASIS-022 | Aucun environnement de staging, plan de reprise global ou restauration K3s/Redis/PostgreSQL de bout en bout n'est démontré. | Élevé | [M08](../evidence/phase-1/M08-postgres-vm-ready.md), [M09](../evidence/phase-1/M09-kubernetes-cluster-ready.md), [M11](../evidence/phase-1/M11-redis-shared-deployed.md) |

## 4. Contrôles positifs à préserver

L'AS-IS n'est pas dépourvu de protections :

- les cinq VM et leurs ports sont gérés par Terraform ;
- le bastion reste le point d'administration et SSH exige des clés ;
- les NodePorts sont limités au bastion par un contrôle hôte testé ;
- PostgreSQL sépare trois rôles/bases et refuse les sources non autorisées ;
- les conteneurs applicatifs et Redis s'exécutent sans privilège root ;
- aucun secret n'est embarqué dans Git ou dans les images ;
- les trois applications exposent santé, disponibilité et métriques ;
- les trois Deployments et les huit targets Prometheus sont disponibles.

Ces contrôles réduisent le risque du lab, sans annuler les constats du registre.

## 5. Candidats TO-BE — non approuvés et non implémentés

Les éléments ci-dessous sont des sujets à étudier en phase 2. Ils ne décrivent
pas l'état courant.

### Priorité 1 — Continuité, données et exposition

- **ASIS-002, ASIS-003, ASIS-005, ASIS-007, ASIS-022 :** définir les objectifs
  de reprise, tester les restaurations et concevoir les niveaux de redondance
  adaptés avant de choisir les mécanismes HA ;
- **ASIS-001, ASIS-002, ASIS-006 :** réévaluer segmentation réseau, entrée
  stable, certificats et chiffrement en fonction des capacités réelles du
  fournisseur ;
- **ASIS-019 :** rétablir et superviser une source de temps fiable avant toute
  dépendance forte aux certificats ou à la corrélation d'audit.

### Priorité 1 — Identités et isolation

- **ASIS-004, ASIS-007, ASIS-010, ASIS-011, ASIS-018 :** définir RBAC,
  NetworkPolicies, authentification métier, ACL data et cycle de vie des secrets
  selon des modèles de menace documentés.

### Priorité 2 — Livraison et supply chain

- **ASIS-012 à ASIS-015 :** choisir une golden path progressive, une source de
  vérité de déploiement, une promotion par digest et des contrôles de supply
  chain proportionnés ;
- définir les critères obligatoires par service avant de décider si GitOps,
  signature, SBOM ou scans deviennent bloquants.

### Priorité 2 — Fiabilité applicative

- **ASIS-008 à ASIS-010 :** introduire migrations, stratégie de replicas,
  transactions événementielles, reprise/DLQ et contrôles d'accès à partir de
  tests de panne et de besoins métier explicites.

### Priorité 2 — Observabilité et exploitation

- **ASIS-016, ASIS-017 :** définir les parcours critiques et SLI avant les SLO,
  puis concevoir métriques, alertes, logs, traces, rétention et sauvegardes ;
- **ASIS-020, ASIS-021 :** réévaluer quotas, capacité et composant d'Ingress
  maintenu avant de figer une architecture cible.

## 6. Porte de sortie de la phase 1

La phase 1 est clôturable lorsque :

1. les vingt-deux constats possèdent une preuve et un impact ;
2. les recommandations restent explicitement séparées de l'AS-IS ;
3. les validations runtime et documentaires M16 sont enregistrées ;
4. aucune correction TO-BE n'est introduite silencieusement.

Le passage à la conception cible exige une approbation explicite de la phase 2.
