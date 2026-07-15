# Contexte métier de l'entreprise simulée

## 1. Objet du document

Ce document décrit le scénario d'entreprise de la phase 1 sans dépendre de
l'historique des conversations. Il explique pourquoi l'architecture AS-IS
existe, qui l'utilise, quelles difficultés elle présente et quel sera le mandat
du Platform Engineer après sa reconstruction.

Il s'agit d'un contexte de référence pour un projet de portfolio. Les éléments
non définis par les sources sont présentés comme hypothèses et non comme faits.

## 2. L'entreprise de référence

L'organisation simulée est une PME SaaS européenne comptant entre 100 et
500 employés. Elle fournit des services numériques à des clients professionnels
B2B et exploite une infrastructure privée basée sur OpenStack.

Dans une entreprise réelle de cette taille, la plateforme hébergerait plusieurs
environnements, davantage d'applications et plus de ressources que le lab. Le
projet Asteria n'en reproduit qu'un sous-ensemble représentatif afin de rester
compatible avec les quotas disponibles.

## 3. Produit B2B représenté

Le domaine commercial exact n'est volontairement pas imposé. Le système
représente les capacités techniques communes d'un produit SaaS B2B :

- `identity-api` porte les fonctions d'identité nécessaires aux utilisateurs ;
- `orders-api` représente un service métier de gestion des commandes ;
- `notifications-worker` traite les notifications de façon asynchrone ;
- PostgreSQL conserve les données persistantes des trois services ;
- Redis est partagé par le service de commandes et le worker de notifications.

Les utilisateurs B2B accèdent aux APIs exposées par une entrée HTTPS commune.
Le worker de notifications n'est pas exposé directement aux utilisateurs.

Cette définition suffit à justifier les flux techniques sans inventer de règles
métier qui appartiendraient à une future spécification applicative.

## 4. Pourquoi un cloud OpenStack privé

L'entreprise utilise OpenStack comme cloud privé afin de conserver davantage de
contrôle sur son infrastructure et de répondre à ses objectifs de souveraineté.
Elle administre ainsi ses propres réseaux, règles de sécurité, machines
virtuelles et points d'exposition.

Ce choix apporte aussi des responsabilités : capacité limitée, services
variables selon le cloud disponible, exploitation des VMs, configuration des
réseaux et maintien d'un chemin d'administration sécurisé.

Le lab OpenStack est une réduction de ce contexte d'entreprise. Il sert à
démontrer les décisions et les opérations, pas à simuler artificiellement toute
la capacité d'une production réelle.

## 5. Équipes et responsabilités

### 5.1 Équipes de développement

Les équipes de développement maintiennent les applications et leurs pipelines.
Dans l'AS-IS, elles ne disposent pas d'un chemin de livraison commun :

- l'identité utilise un pipeline build/push sans scan d'image ;
- les commandes utilisent tests/build/push sans SBOM ;
- les notifications sont construites et déployées manuellement.

### 5.2 Équipe Platform / DevOps

L'équipe Platform/DevOps administre OpenStack, le bastion, Kubernetes,
PostgreSQL, l'Ingress et les composants partagés. Elle intervient également
pour les déploiements qui ne sont pas pleinement automatisés.

Cette concentration des opérations crée une dépendance forte des équipes
applicatives envers l'équipe Platform.

### 5.3 Équipe Sécurité / Audit

L'équipe Sécurité/Audit consulte les dépôts, le registre et les configurations
Kubernetes. Plusieurs contrôles sont encore manuels, notamment les revues de
manifests et de RBAC.

### 5.4 Clients et utilisateurs

Les clients B2B consomment les services publics à travers le DNS, le réseau
externe OpenStack, le point d'exposition et l'Ingress Kubernetes. Ils n'accèdent
pas directement aux VMs, à PostgreSQL ou aux interfaces d'administration.

## 6. État actuel de la plateforme

La plateforme AS-IS est fonctionnelle mais hétérogène :

- Kubernetes possède un control plane unique et deux workers ;
- PostgreSQL s'exécute sur une VM séparée avec un primaire unique ;
- Redis est partagé et faiblement isolé ;
- les applications utilisent trois méthodes de déploiement différentes ;
- aucun GitOps commun ne gouverne les changements ;
- la sécurité Kubernetes est partielle ;
- Prometheus et Grafana offrent une visibilité incomplète ;
- les logs sont souvent consultés manuellement avec `kubectl logs` ;
- les sauvegardes existent mais leur restauration n'est pas testée.

Ces caractéristiques constituent l'état à reconstruire en phase 1. Elles ne
doivent pas être corrigées silencieusement pendant cette phase.

## 7. Irritants métier et opérationnels

### 7.1 Livraison lente et peu prévisible

L'absence de golden path et la coexistence de plusieurs modes de déploiement
augmentent les différences entre équipes. Une livraison dépend de connaissances
spécifiques au service et parfois d'une intervention manuelle.

### 7.2 Dépendance envers l'équipe Platform

Les équipes de développement ne peuvent pas réaliser toutes leurs opérations de
façon autonome. Le bastion et les procédures non standardisées concentrent la
connaissance et les accès dans l'équipe Platform.

### 7.3 Risque de sécurité difficile à mesurer

Les scans, SBOM, NetworkPolicies et politiques de conformité ne sont pas
systématiques. Les audits manuels donnent une vision ponctuelle plutôt qu'une
garantie homogène sur toutes les livraisons.

### 7.4 Diagnostic incomplet

Les métriques sont partielles, les dashboards sont manuels, les logs ne sont pas
centralisés et aucun ensemble homogène de SLO ou d'alertes n'existe. Un incident
peut donc demander plusieurs vérifications manuelles.

### 7.5 Continuité de service limitée

Le control plane Kubernetes et PostgreSQL ne sont pas hautement disponibles.
Les sauvegardes non restaurées en exercice ne démontrent pas encore une capacité
de reprise fiable.

## 8. Mandat du futur Platform Engineer

Le mandat ne commence réellement qu'après la reconstruction et l'audit de
l'AS-IS. En phase 2, le Platform Engineer devra :

1. s'appuyer sur les preuves de la phase 1 pour établir un diagnostic factuel ;
2. prioriser les risques selon leur impact métier et opérationnel ;
3. proposer une architecture cible réaliste et progressive ;
4. réduire la variabilité des livraisons sans masquer les besoins des équipes ;
5. améliorer sécurité, autonomie, observabilité et capacité de reprise ;
6. mesurer les progrès et documenter les compromis liés aux ressources.

Le mandat n'autorise pas à transformer prématurément la phase 1 en plateforme
cible. L'intérêt du projet repose précisément sur une évolution démontrable
entre un AS-IS crédible et un futur TO-BE justifié.

## 9. Hypothèses et limites du scénario

### Faits validés

- PME SaaS européenne de 100 à 500 employés ;
- clientèle B2B ;
- cloud OpenStack privé pour contrôle et souveraineté ;
- équipes Développement, Platform/DevOps et Sécurité/Audit ;
- trois workloads représentatifs et une chaîne de livraison hétérogène ;
- lab réduit par rapport à la production de référence.

### Éléments volontairement non définis

- secteur commercial exact ;
- nombre précis de clients et d'utilisateurs ;
- engagements contractuels ou réglementaires détaillés ;
- volumétrie réelle des commandes et notifications ;
- organisation interne détaillée des équipes.

Ces éléments ne doivent pas être inventés tant qu'une mission ne nécessite pas
leur formalisation.
