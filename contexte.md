OK, maintenant, on va commencer à élaborer le truc. Du coup, je veux avoir un workflow parfait pour l'usage de l'IA, d'agents et tout ça, pour qu'il m'aide parfaitement à la construction de cette architecture de la phase 1. Car je vais pas tout faire par moi-même, du coup, je veux avoir un truc bien formalisé en détail, pour que si je lui donne à l'IA, il va me faire un truc vraiment clean. Si je le donne à GPT-5.6 Solo, il va me le donner de façon nickel, il sait exactement ce qu'il faut faire étape par étape. Du coup, je sais pas c'est quoi le mieux. Est-ce que c'est un cahier des charges, un genre de cahier des charges, un fichier MD ou bien... C'est quoi le mieux exactement à faire maintenant ? C'est ça que je veux que tu me fasses. Là, dans le contexte du projet, j'ai déjà mis l'architecture que tu m'avais donnée en fichier Mermaid, et aussi en PDF pour avoir double truc. Du coup, je sais pas trop. Est-ce que tu vois, c'est la meilleure idée ou bien c'est mieux d'aller, au lieu de faire un cahier des charges énorme, on va faire un truc étape par étape de façon chronologique de la meilleure manière de construire l'application si on... l'architecture, si on devait partir de zéro. Et aussi, moi de mon côté, ce que je dois faire et quand je devrais créer les machines sur OpenStack et ce genre de choses. C'est ça l'idée. Du coup, je te laisse me dire quoi faire exactement, c'est quoi le meilleur workflow qu'on puisse faire actuellement.Là, c'est les étapes qu'il me faut. Je sais pas par quoi commencer avec ce projet vu que j'ai jamais travaillé avec, ou j'ai jamais créé une architecture de zéro. Du coup, je sais pas par quoi commencer, par quel ordre, qu'est-ce que, les tâches que je dois formaliser. C'est ça le truc, formaliser les choses. Dis-moi à quel moment je dois allouer les machines sur OpenStack, quoi mettre comme réseau, tout ça, tout ça, tout ça, tout ça. C'est ça la mission. La première mission, c'est formaliser tout ça, petit à petit, de manière chronologique, logique, et bien structurée. C'est ça le truc que je veux faire. Du coup, si tu peux m'aider pour ça, pour qu'on commence vraiment le projet. Imagine-toi, c'est comme si j'avais une équipe, on doit commencer à faire cette architecture. Par quoi on va commencer? Mission par mission, jusqu'à avoir l'architecture de la phase 1.

Oui, maître. Le meilleur workflow maintenant, ce n’est pas de faire un énorme cahier des charges monolithique.

Le meilleur format, c’est de créer un système de pilotage de projet, comme si tu avais une mini-équipe technique. En clair :

1 fichier de contexte global + 1 fichier de règles pour l’IA + 1 backlog chronologique + 1 dossier de preuves.

Comme ça, GPT/agent/IA ne part pas dans tous les sens. Il sait exactement quoi faire, dans quel ordre, avec quelles contraintes, et comment valider chaque étape.

Ton fichier de revue AS-IS fixe déjà les contraintes importantes : conserver les défauts réalistes, distinguer entreprise réelle et lab, respecter les limites OpenStack, et ne pas transformer l’AS-IS en architecture cible parfaite.

1. Le meilleur workflow global

Tu vas fonctionner comme ça :

Architecture validée
        ↓
Project Operating System
        ↓
Backlog Phase 1
        ↓
Mission par mission
        ↓
Code + infra + validation
        ↓
Preuves techniques
        ↓
Documentation AS-IS finale

Le principe :

L’IA ne doit jamais “juste coder”.
Elle doit travailler par mission, avec objectif, fichiers, commandes, validation et preuve.

2. Les fichiers à créer maintenant

Dans ton repo, je te conseille cette structure dès le départ :

secure-kubernetes-developer-platform/
├── README.md
├── AGENTS.md
├── PROJECT_CONTEXT.md
├── PHASE_1_BACKLOG.md
├── docs/
│   ├── phase-1-as-is/
│   │   ├── 00-business-context.md
│   │   ├── 01-as-is-architecture.md
│   │   ├── 02-openstack-lab-constraints.md
│   │   ├── 03-network-design.md
│   │   ├── 04-instance-sizing.md
│   │   ├── 05-security-groups.md
│   │   ├── 06-deployment-methods.md
│   │   ├── 07-observability-as-is.md
│   │   └── 08-as-is-known-issues.md
│   ├── diagrams/
│   │   └── as-is-architecture.mmd
│   └── evidence/
│       └── phase-1/
├── infra/
│   └── terraform/
│       └── openstack/
├── ansible/
├── apps/
│   ├── identity-api/
│   ├── orders-api/
│   └── notifications-worker/
├── k8s/
│   └── current-state/
├── ci/
│   └── current-state/
├── monitoring/
│   └── current-state/
└── scripts/

Les 3 fichiers les plus importants pour piloter l’IA sont :

PROJECT_CONTEXT.md
AGENTS.md
PHASE_1_BACKLOG.md
3. Rôle de chaque fichier
PROJECT_CONTEXT.md

C’est le contexte global du projet.

Il contient :

- le scénario entreprise ;
- le rôle que tu joues ;
- l’architecture AS-IS validée ;
- les limites OpenStack ;
- ce qu’on doit construire en phase 1 ;
- ce qu’on ne doit pas encore corriger.

C’est le fichier que tu redonnes toujours à l’IA quand elle oublie le contexte.

AGENTS.md

C’est le fichier qui dit à l’IA comment travailler.

Il contient les règles :

- ne pas sauter d’étapes ;
- ne pas proposer l’architecture cible pendant la phase 1 ;
- toujours expliquer les hypothèses ;
- toujours donner les fichiers à créer ;
- toujours donner les commandes ;
- toujours donner les tests de validation ;
- toujours produire une preuve ;
- toujours respecter les limites OpenStack ;
- ne pas corriger les défauts AS-IS volontairement conservés.

C’est un peu le “contrat de travail” de ton agent IA.

PHASE_1_BACKLOG.md

C’est le plan chronologique.

Il contient toutes les missions à faire, dans l’ordre.

Exemple :

M00 — Initialiser le repo
M01 — Documenter le contexte entreprise
M02 — Documenter l’architecture AS-IS
M03 — Inventorier OpenStack
M04 — Concevoir les réseaux
M05 — Écrire Terraform réseau
M06 — Créer les VMs
M07 — Configurer bastion
M08 — Installer PostgreSQL
M09 — Installer Kubernetes
M10 — Installer ingress
M11 — Déployer Redis
M12 — Déployer monitoring partiel
M13 — Créer les apps
M14 — Déployer les apps de manière hétérogène
M15 — Simuler CI/CD hétérogène
M16 — Documenter les problèmes AS-IS
4. Le workflow d’IA parfait

À chaque mission, tu donnes à l’IA ce format :

Contexte :
Nous sommes dans la phase 1 AS-IS du projet Secure Kubernetes Developer Platform.
Le but est de reconstruire une architecture existante imparfaite, pas de la moderniser.

Mission :
[Nom de la mission]

Contraintes :
- OpenStack lab
- ressources disponibles
- architecture AS-IS validée
- ne pas introduire GitOps/Kyverno/TO-BE pour l’instant

Ce que j’attends :
1. objectif de la mission ;
2. fichiers à créer/modifier ;
3. code complet si nécessaire ;
4. commandes à exécuter ;
5. tests de validation ;
6. preuve à sauvegarder dans docs/evidence/phase-1/ ;
7. risques et erreurs fréquentes ;
8. prochaine étape.

C’est ça qui va te donner un résultat propre.

5. Les rôles d’agents à utiliser

Tu peux utiliser GPT comme un seul agent, mais en lui demandant de raisonner avec plusieurs casquettes.

Pour chaque mission, tu peux dire :

Réponds comme :
- Cloud Architect pour la cohérence OpenStack ;
- Network Architect pour les réseaux et security groups ;
- Platform Engineer pour Kubernetes ;
- DevOps Engineer pour Terraform/Ansible/CI ;
- SRE pour la validation et les preuves ;
- Security Reviewer pour les risques.

Mais attention : il ne faut pas qu’il te fasse des romans à chaque fois.

Tu lui demandes surtout :

Décision + fichiers + commandes + validation.
6. Quand créer les machines OpenStack ?

Très important : pas tout de suite à la main.

L’ordre correct est :

Étape 1 — Documentation et repo

Pas de machine.

Tu crées le repo, le contexte, le backlog, le diagramme.

Étape 2 — Inventaire OpenStack

Toujours pas de machine.

Tu récupères :

openstack flavor list
openstack image list
openstack network list
openstack security group list
openstack quota show

Tu colles les résultats à l’IA pour qu’elle adapte Terraform à ton environnement réel.

Étape 3 — Design réseau

Toujours pas de machines.

Tu définis :

management-net
application-net
data-net
DMZ/public-services-net si possible
router
security groups
floating IP
Étape 4 — Terraform réseau

Tu écris Terraform pour les réseaux, router, subnet, security groups.

Tu fais :

terraform init
terraform plan

Seulement si le plan est propre :

terraform apply
Étape 5 — Création des VMs

C’est là seulement que tu alloues les machines.

Avec ton doublement de ressources, je recommande :

bastion-admin-01      1 vCPU / 1 Go RAM
k8s-control-plane-01  2 vCPU / 4 Go RAM
k8s-worker-01         2 vCPU / 4 Go RAM
k8s-worker-02         2 vCPU / 4 Go RAM
k8s-worker-03         2 vCPU / 4 Go RAM
db-postgres-01        2 vCPU / 4 Go RAM

Total :

6 instances
11 vCPU
21 Go RAM

Si ton nouveau quota est autour de 16 instances / 20 vCPU / 40 Go RAM, c’est nickel.

7. Pourquoi on garde 1 seul control-plane malgré plus de ressources ?

Parce que c’est encore l’AS-IS.

On veut montrer une entreprise qui a une infra fonctionnelle mais imparfaite.

Donc on garde volontairement :

- control-plane non HA ;
- PostgreSQL sans réplication ;
- monitoring partiel ;
- CI/CD hétérogène ;
- pas de GitOps ;
- pas de policy-as-code.

Avec tes ressources doublées, le seul ajout intelligent est :

+ 1 worker Kubernetes

Ça rend le lab plus confortable sans transformer l’AS-IS en plateforme mature.

8. Backlog chronologique Phase 1

Voici le plan de construction officiel.

M00 — Initialisation du repo

Objectif : créer la base du projet.

À faire :

mkdir secure-kubernetes-developer-platform
cd secure-kubernetes-developer-platform

mkdir -p docs/phase-1-as-is
mkdir -p docs/diagrams
mkdir -p docs/evidence/phase-1
mkdir -p infra/terraform/openstack
mkdir -p ansible
mkdir -p apps/identity-api
mkdir -p apps/orders-api
mkdir -p apps/notifications-worker
mkdir -p k8s/current-state
mkdir -p ci/current-state
mkdir -p monitoring/current-state
mkdir -p scripts

touch README.md
touch PROJECT_CONTEXT.md
touch AGENTS.md
touch PHASE_1_BACKLOG.md

Preuve attendue :

docs/evidence/phase-1/M00-repo-structure.md
M01 — Écrire le contexte entreprise

Objectif : expliquer la mission.

Fichier :

docs/phase-1-as-is/00-business-context.md

Contenu :

- entreprise fictive ;
- taille ;
- équipes ;
- usage OpenStack ;
- usage Kubernetes ;
- problèmes actuels ;
- pourquoi tu arrives comme Platform Engineer.

Preuve :

M01-business-context-written.md
M02 — Figer l’architecture AS-IS

Objectif : documenter le schéma validé.

Fichiers :

docs/diagrams/as-is-architecture.mmd
docs/phase-1-as-is/01-as-is-architecture.md

Tu y mets :

- diagramme Mermaid ;
- explication des flux ;
- différence entreprise réelle vs lab ;
- dettes AS-IS conservées.

Preuve :

M02-as-is-architecture-frozen.md
M03 — Inventaire OpenStack

Objectif : connaître ton environnement réel avant d’écrire Terraform.

Commandes :

openstack quota show
openstack flavor list
openstack image list
openstack network list
openstack security group list
openstack floating ip list

Fichier :

docs/phase-1-as-is/02-openstack-lab-constraints.md

Preuve :

docs/evidence/phase-1/M03-openstack-inventory.md

C’est ici que tu colles les sorties des commandes.

M04 — Design réseau OpenStack

Objectif : définir les réseaux avant de les créer.

Fichiers :

docs/phase-1-as-is/03-network-design.md
docs/phase-1-as-is/05-security-groups.md

Réseaux prévus :

mgmt-net
app-net
data-net
public-services-net ou DMZ si possible

Security groups minimaux :

sg-bastion
sg-k8s-control-plane
sg-k8s-workers
sg-postgres
sg-ingress

Preuve :

M04-network-design-approved.md
M05 — Terraform réseau OpenStack

Objectif : créer les réseaux avec IaC.

Fichiers :

infra/terraform/openstack/main.tf
infra/terraform/openstack/variables.tf
infra/terraform/openstack/outputs.tf
infra/terraform/openstack/provider.tf
infra/terraform/openstack/network.tf
infra/terraform/openstack/security-groups.tf

Commandes :

cd infra/terraform/openstack
terraform init
terraform fmt
terraform validate
terraform plan

Puis seulement après validation :

terraform apply

Preuve :

M05-terraform-network-apply.md
M06 — Terraform compute OpenStack

Objectif : créer les VMs.

Fichier :

infra/terraform/openstack/compute.tf

Instances :

bastion-admin-01
k8s-control-plane-01
k8s-worker-01
k8s-worker-02
k8s-worker-03
db-postgres-01

Commandes :

terraform plan
terraform apply
openstack server list

Preuve :

M06-openstack-instances-created.md
M07 — Configurer le bastion

Objectif : faire du bastion le point d’administration.

Avec Ansible ou commandes manuelles documentées au début.

Installer :

openstack client
terraform
ansible
kubectl
helm
psql client
git
jq
curl

Preuve :

M07-bastion-ready.md
M08 — Installer PostgreSQL sur VM séparée

Objectif : reconstruire le choix réaliste “DB hors Kubernetes”.

Sur :

db-postgres-01

À faire :

- installer PostgreSQL ;
- créer users/databases pour identity/orders/notifications ;
- ouvrir seulement les flux nécessaires depuis app-net ;
- sauvegarde basique non encore industrialisée.

Preuve :

M08-postgres-vm-ready.md
M09 — Installer Kubernetes

Objectif : créer le cluster prod-like réduit.

Je conseille k3s au début.

Nodes :

control-plane-01
worker-01
worker-02
worker-03

Preuves :

kubectl get nodes -o wide
kubectl get pods -A

Fichier preuve :

M09-kubernetes-cluster-ready.md
M10 — Installer Ingress NGINX

Objectif : exposer les apps via une entrée commune.

À faire :

- installer ingress-nginx ;
- exposer via NodePort ou Floating IP selon OpenStack ;
- documenter le flux DNS/FIP/Ingress.

Preuve :

M10-ingress-ready.md
M11 — Créer les namespaces AS-IS

Namespaces :

team-identity
team-orders
team-notifications
shared
monitoring
ingress-nginx

Important : ne pas tout rendre parfait.

Tu peux volontairement avoir :

- labels incomplets sur certains namespaces ;
- pas encore de ResourceQuota ;
- pas encore de NetworkPolicies.

Preuve :

M11-namespaces-created.md
M12 — Déployer Redis partagé

Objectif : simuler une dette réaliste.

Namespace :

shared

Redis partagé par :

orders-api
notifications-worker

Preuve :

M12-redis-shared-deployed.md
M13 — Déployer monitoring partiel

Objectif : avoir Prometheus/Grafana, mais pas une stack mature.

À faire :

- Prometheus léger ;
- Grafana ;
- pas de Loki complet au début ;
- dashboards manuels ;
- alerting absent ou minimal.

Preuve :

M13-monitoring-partial-ready.md
M14 — Créer les trois applications

Applications :

identity-api
orders-api
notifications-worker

Stack recommandée :

Python FastAPI

Chaque service doit avoir au minimum :

/health
/ready
/metrics

Preuve :

M14-apps-built-locally.md
M15 — Déploiements hétérogènes

Objectif : créer le vrai AS-IS fragmenté.

Méthodes :

identity-api → YAML brut
orders-api → Helm chart interne
notifications-worker → kubectl apply manuel

Preuve :

M15-heterogeneous-deployments.md
M16 — CI/CD hétérogène

Objectif : simuler les pipelines existants.

Pipelines :

identity-api → build + push, pas de scan
orders-api → tests + build + push, pas de SBOM
notifications-worker → manuel

Preuve :

M16-cicd-fragmented.md
M17 — Audit AS-IS final

Objectif : documenter les problèmes avant ton arrivée.

Fichier :

docs/phase-1-as-is/08-as-is-known-issues.md

Findings :

- pas de GitOps ;
- pas de golden path ;
- CI/CD hétérogène ;
- déploiements manuels ;
- sécurité K8s incomplète ;
- pas de NetworkPolicies ;
- logs non centralisés ;
- observabilité partielle ;
- backups non restaurés ;
- dépendance à l’équipe Platform.

Preuve :

M17-as-is-audit-complete.md
9. Le fichier AGENTS.md à donner à l’IA

Tu peux créer ce fichier :

# AGENTS.md

You are assisting with a serious portfolio project simulating a real Platform Engineering / DevSecOps mission.

## Project

Secure-by-Default Kubernetes Internal Developer Platform.

## Current phase

Phase 1: reconstruct the AS-IS architecture of a mid-size European SaaS company before modernization.

The goal is not to build the final target platform yet.  
The goal is to reproduce a realistic but imperfect existing infrastructure.

## AS-IS principles

The architecture must remain imperfect:

- heterogeneous CI/CD;
- no common GitOps;
- partial monitoring;
- incomplete Kubernetes security;
- no systematic SBOM;
- no mandatory image scanning;
- manual deployment for one worker;
- PostgreSQL on a separate VM without HA;
- Redis shared;
- backups present but restore not tested;
- strong dependency on the Platform team.

Do not prematurely introduce target-state components such as full GitOps, Kyverno enforcement, mature observability, centralized secrets management, or a complete golden path unless explicitly requested.

## Lab constraints

The implementation runs on an OpenStack lab.

The lab is a reduced but representative version of the company infrastructure.

The current target lab footprint is:

- bastion-admin-01;
- k8s-control-plane-01;
- k8s-worker-01;
- k8s-worker-02;
- k8s-worker-03;
- db-postgres-01.

Expected footprint:

- 6 instances;
- around 11 vCPU;
- around 21 GB RAM.

## Working rules

For every mission, provide:

1. objective;
2. assumptions;
3. files to create or modify;
4. exact commands;
5. full code when needed;
6. validation steps;
7. expected output;
8. evidence file to create;
9. risks and common errors;
10. next step.

Do not skip validation.

Do not create resources manually if Terraform is expected.

Do not hide lab limitations.

Do not over-engineer the AS-IS.

Always distinguish:

- enterprise reference architecture;
- lab implementation.
10. Le prompt à utiliser pour chaque mission

Tu peux utiliser ce prompt à chaque nouvelle tâche :

Nous sommes dans le projet Secure-by-Default Kubernetes Internal Developer Platform.

Phase actuelle : Phase 1 — reconstruction de l’architecture AS-IS.

Objectif de cette phase :
Reconstruire une infrastructure existante réaliste mais imparfaite d’une PME européenne utilisant OpenStack, Kubernetes et une chaîne DevOps partiellement industrialisée.

Important :
Ne propose pas encore l’architecture cible TO-BE.
Ne corrige pas encore tous les défauts.
Conserve les dettes AS-IS réalistes : CI/CD hétérogène, pas de GitOps, monitoring partiel, sécurité K8s incomplète, PostgreSQL sans HA, backup restore non testé.

Mission actuelle :
[METS ICI LA MISSION, ex: M05 — Terraform réseau OpenStack]

Contraintes :
- OpenStack lab ;
- architecture AS-IS validée ;
- ressources limitées ;
- travail étape par étape ;
- tout doit être documenté.

Réponds avec :
1. objectif ;
2. hypothèses à confirmer ;
3. fichiers à créer/modifier ;
4. code complet ;
5. commandes ;
6. validation ;
7. preuve à sauvegarder ;
8. erreurs fréquentes ;
9. prochaine mission.
11. Ce que tu dois faire maintenant, concrètement

La toute première chose à faire, c’est M00.

Exécute :

mkdir secure-kubernetes-developer-platform
cd secure-kubernetes-developer-platform

mkdir -p docs/phase-1-as-is
mkdir -p docs/diagrams
mkdir -p docs/evidence/phase-1
mkdir -p infra/terraform/openstack
mkdir -p ansible
mkdir -p apps/identity-api
mkdir -p apps/orders-api
mkdir -p apps/notifications-worker
mkdir -p k8s/current-state
mkdir -p ci/current-state
mkdir -p monitoring/current-state
mkdir -p scripts

touch README.md
touch PROJECT_CONTEXT.md
touch AGENTS.md
touch PHASE_1_BACKLOG.md

Ensuite tu remplis dans cet ordre :

1. PROJECT_CONTEXT.md
2. AGENTS.md
3. PHASE_1_BACKLOG.md
4. docs/phase-1-as-is/00-business-context.md
5. docs/diagrams/as-is-architecture.mmd
6. docs/phase-1-as-is/01-as-is-architecture.md

Seulement après ça, tu passes à OpenStack.

12. Résumé simple

Le meilleur workflow, c’est :

Ne pas demander à l’IA : “construis-moi tout le projet”.

Demander à l’IA :
“Voici le contexte, voici la mission M05, donne-moi uniquement cette étape avec fichiers, commandes, validation et preuve.”

C’est comme ça que tu vas garder un projet propre, sérieux, et proche d’une vraie mission entreprise.

Donc maintenant, on est prêt à démarrer officiellement par :

M00 — Initialisation du repo et des fichiers de pilotage.