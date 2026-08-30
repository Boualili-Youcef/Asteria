# Charte de transformation Asteria — Phase 2 TO-BE

## 1. Mandat

La phase 1 a reconstruit puis audité une plateforme AS-IS fonctionnelle. La
phase 2 simule l'arrivée d'un Platform Engineer chargé de la moderniser sans
effacer les preuves de départ ni transformer le lab en démonstration irréaliste.

Le mandat est approuvé depuis le **30 août 2026** : analyser les risques,
définir une cible, migrer par étapes, prouver les améliorations et rendre
visibles les compromis qui subsistent.

## 2. Résultat recherché

À la fin de la phase 2, Asteria doit démontrer :

- une architecture cible crédible pour une PME SaaS B2B d'environ 500 employés ;
- une adaptation lab reproductible dans les capacités OpenStack vérifiées ;
- une administration liée aux identités et non à des clés permanentes ;
- une plateforme Kubernetes isolée, observable et livrée par GitOps ;
- une supply chain commune avec artefacts traçables et immuables ;
- des services data chiffrés, sauvegardés et restaurés ;
- des applications authentifiées, résilientes et instrumentées ;
- des SLO, alertes et procédures de reprise réellement testés ;
- une comparaison AS-IS/TO-BE reliée aux 22 constats de M16.

## 3. Ce que « parfait » signifie dans ce projet

Une architecture parfaite n'existe pas. Ici, le niveau attendu signifie :

1. aucun choix important sans besoin, risque ou preuve ;
2. aucun mécanisme HA déclaré sans domaine de panne indépendant et test ;
3. aucune sauvegarde déclarée utile sans restauration ;
4. aucun outil de sécurité déclaré efficace sans test négatif ;
5. aucun déploiement déclaré reproductible si une étape manuelle cachée reste ;
6. chaque limite du lab explicitement séparée de la référence entreprise ;
7. chaque dette restante acceptée, propriétaire et datée.

## 4. Principes de transformation

### P1 — Besoins avant produits

T01 définit SLO, RTO/RPO, données et menaces. Les produits sont définitivement
retenus par ADR en T03, pas uniquement parce qu'ils sont populaires.

### P2 — Traçabilité complète

Chaque changement cite un ou plusieurs identifiants `ASIS-001` à `ASIS-022`,
un résultat attendu et une preuve après exécution.

### P3 — Migration progressive

Le chemin préféré est blue/green entre projets OpenStack si T02 confirme les
quotas et la connectivité. La plateforme AS-IS reste disponible jusqu'à ce que
la cible réussisse les tests et qu'un rollback soit possible.

### P4 — Zero Trust progressif

Le bastion n'est pas supprimé le premier jour. Un accès lié à l'identité, avec
MFA, RBAC, certificats courts et audit, est installé puis validé. Le bastion
devient ensuite un chemin break-glass contrôlé.

### P5 — Git comme source de vérité

Terraform gère l'infrastructure, Ansible le bootstrap nécessaire et GitOps les
ressources Kubernetes. Les actions d'urgence sont réconciliées et auditées.

### P6 — Build once, promote by digest

La CI produit une image unique, testée, scannée, accompagnée d'une SBOM et
d'une provenance. Les environnements promeuvent son digest ; ils ne rebâtissent
pas le code et ne déploient pas de tag mutable.

### P7 — Default deny, moindre privilège

Les accès réseau, Kubernetes, data et secrets commencent fermés. Les flux
nécessaires sont ouverts, documentés et testés par source/destination.

### P8 — Restore before HA claims

La sauvegarde/restauration et les objectifs de reprise sont prioritaires. La HA
ne masque pas l'absence de DR et ne compense pas une sauvegarde inutilisable.

### P9 — Observabilité orientée service

Les dashboards ne suffisent pas. La cible relie métriques, alertes, logs,
traces, événements de sécurité et SLO aux parcours métier critiques.

### P10 — Complexité proportionnée

Chaque contrôleur ajouté doit avoir un propriétaire, une procédure d'upgrade,
des ressources mesurées et une valeur supérieure à son coût opérationnel.

## 5. Frontières du projet

### Référence entreprise

La cible entreprise peut représenter plusieurs zones de disponibilité, des
clusters séparés, des services HA, un stockage objet et une exposition stable.
Elle décrit ce qu'une PME de 500 employés devrait commander et exploiter.

### Implémentation lab

Le lab ne revendique pas les propriétés qu'OpenStack ne fournit pas. Les
restrictions connues du réseau provider, l'absence historique de L3/Octavia et
les quotas restent contraignants jusqu'au nouvel inventaire T02.

Le deuxième projet est un candidat pour staging, services partagés, green
cluster ou DR. Son rôle définitif dépend de ses capacités vérifiées et de la
connectivité inter-projets.

## 6. Vagues de transformation

| Vague | Missions | But |
|---|---|---|
| 0 — Décider | T00 à T03 | exigences, capacités, architecture et ADR |
| 1 — Sécuriser | T04 à T06 | temps, backups initiaux, landing zone, accès |
| 2 — Reconstruire | T07 à T10 | cluster, réseau, identités, secrets et data |
| 3 — Moderniser | T11 à T13 | applications, supply chain et GitOps |
| 4 — Opérer | T14 à T16 | SLO, observabilité, DR et expérience équipes |
| 5 — Prouver | T17 à T18 | game days, audit et comparaison finale |

## 7. Portes de contrôle

- **Gate A — après T01 :** objectifs métier et risques approuvés ;
- **Gate B — après T02 :** capacités des deux projets prouvées ;
- **Gate C — après T03 :** technologies et diagramme final approuvés ;
- **Gate D — avant chaque bascule :** backup, rollback et tests négatifs prêts ;
- **Gate E — après T17 :** résilience et sécurité observées ;
- **Gate F — T18 :** écarts restants acceptés ou replanifiés.

## 8. Indicateurs de réussite candidats

Les valeurs définitives seront fixées en T01. La phase 2 devra au minimum
mesurer : disponibilité et latence des APIs, taux d'erreur, délai de livraison,
taux d'échec de déploiement, MTTR, couverture de tests/policies, fraîcheur des
backups, RPO/RTO observés, temps de révocation d'un accès et consommation des
quotas.

## 9. Première mission autorisée

T00 est une mission documentaire sans changement runtime. La prochaine mission
autorisée est T01. Aucun cluster, réseau, base ou outil cible ne doit être
installé avant la validation des exigences, de l'inventaire T02 et des ADR T03.
