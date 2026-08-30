# Modèle de menace et frontières de confiance

## 1. Objet et méthode

Ce modèle identifie les actifs, acteurs, frontières de confiance et scénarios
de menace à traiter avant les choix T03. Il utilise les catégories STRIDE comme
aide de revue : usurpation, altération, répudiation, divulgation, déni de
service et élévation de privilèges.

Dans le registre : `S` = usurpation, `T` = altération, `R` = répudiation,
`I` = divulgation, `D` = déni de service et `E` = élévation de privilèges.

Le score initial représente l'AS-IS appliqué au scénario d'entreprise :

```text
score = vraisemblance (1 à 3) x impact (1 à 3)
1-2 faible ; 3-4 moyen ; 6 élevé ; 9 critique
```

Il ne s'agit pas d'une probabilité statistique. Le risque résiduel sera réévalué
en T17 après tests. Le diagramme source est
`docs/diagrams/to-be-trust-boundaries.mmd`.

## 2. Faits vérifiés

- Le lab est accessible par un réseau provider partagé et compensé par SG et
  contrôles hôte (`ASIS-001`).
- Les APIs n'ont aucune authentification ou autorisation métier (`ASIS-010`).
- Les accès Kubernetes sont larges, sans ServiceAccounts dédiés ni
  NetworkPolicies (`ASIS-004`).
- PostgreSQL et Redis n'imposent pas le chiffrement de leurs flux ; Redis est
  sans authentification (`ASIS-006`, `ASIS-007`).
- Les secrets sont injectés manuellement sans rotation centralisée
  (`ASIS-011`).
- La CI, les artefacts et les déploiements ne fournissent ni chaîne de
  provenance homogène ni source de vérité commune (`ASIS-012` à `ASIS-015`).
- L'observabilité, les alertes et la synchronisation du temps sont insuffisantes
  pour une investigation robuste (`ASIS-016` à `ASIS-019`).

## 3. Hypothèses de menace

- un attaquant externe peut atteindre le futur point d'entrée B2B, mais pas les
  interfaces internes directement ;
- un compte client, développeur ou administrateur peut être compromis ;
- un workload ou une dépendance de build peut être malveillant ;
- une erreur opérateur est aussi probable qu'une action volontaire ;
- les administrateurs OpenStack du fournisseur restent dans la chaîne de
  confiance du lab ; ce risque n'est pas supprimable par Kubernetes ;
- les deux projets OpenStack peuvent dépendre du même site et du même réseau ;
  leur indépendance n'est pas acquise avant T02 ;
- aucune donnée client réelle n'est utilisée dans le lab.

## 4. Actifs prioritaires

| ID | Actif | Propriété à protéger |
|---|---|---|
| AST-01 | identités, sessions et frontières de tenant | confidentialité, authenticité, séparation |
| AST-02 | commandes et historique de notifications | intégrité, confidentialité, disponibilité |
| AST-03 | secrets, clés et certificats | confidentialité, rotation, traçabilité |
| AST-04 | contrôle Kubernetes/OpenStack/PostgreSQL | moindre privilège, disponibilité, audit |
| AST-05 | sources, workflows, images, SBOM et provenance | intégrité, authenticité, reproductibilité |
| AST-06 | état GitOps et historique des promotions | intégrité, non-répudiation, rollback |
| AST-07 | sauvegardes et catalogue de reprise | confidentialité, intégrité, disponibilité |
| AST-08 | métriques, logs, traces et journaux d'audit | intégrité, disponibilité, horodatage |

## 5. Frontières de confiance

| ID | Passage | Contrôles exigés au passage |
|---|---|---|
| TB-01 | réseau client non fiable vers Gateway | TLS, route explicite, limitation, validation d'entrée |
| TB-02 | utilisateur/IdP vers contexte d'identité et tenant | validation issuer/audience/expiration, MFA selon rôle, autorisation métier |
| TB-03 | Gateway vers workloads | identité réseau, routes autorisées, default-deny |
| TB-04 | workload vers PostgreSQL/cache/bus et entre namespaces | identité distincte, TLS/ACL, policy minimale, protocole borné |
| TB-05 | poste admin vers accès privilégié puis ressources | identité forte, privilège court, approbation, audit, break-glass limité |
| TB-06 | Git/CI/registre/source de vérité vers cluster | revue, actions immuables, scan, provenance, digest et admission |
| TB-07 | plan de secrets vers workload | authentification workload, secret limité, rotation, aucune persistance non nécessaire |
| TB-08 | workloads/data vers observabilité | minimisation, contrôle d'accès, protection contre falsification |
| TB-09 | plateforme vers domaine de sauvegarde | chiffrement, identité dédiée, écriture limitée, restauration contrôlée |
| TB-10 | projet AS-IS vers projet cible pendant migration | aucun transit implicite, flux inventorié, state et credentials séparés |

La frontière TB-10 est une exigence de conception. Sa faisabilité réseau et son
niveau d'indépendance seront vérifiés en T02.

## 6. Registre des menaces

| ID | STRIDE | Scénario et actif | Frontière | Risques M16 | Score initial | Exigences et test futur | Propriétaire |
|---|---|---|---|---|---:|---|---|
| THR-001 | S/E | Un appelant anonyme ou d'un autre tenant lit/crée identité ou commande. AST-01/02. | TB-01/02 | ASIS-002, ASIS-010 | 9 critique | `REQ-SEC-001` ; tests 401/403/2xx et isolation tenant | Produit + Sécurité |
| THR-002 | S/E/R | Un compte admin ou kubeconfig compromis obtient des privilèges durables et non attribuables. AST-03/04. | TB-05 | ASIS-004, ASIS-011, ASIS-018 | 9 critique | `REQ-SEC-002` ; session courte, moindre privilège, révocation et audit | Platform + Sécurité |
| THR-003 | E/I | Un workload compromis se déplace sur l'underlay/overlay et atteint DB, cache ou autre namespace. AST-02/04. | TB-03/04/10 | ASIS-001, ASIS-004, ASIS-006, ASIS-007 | 9 critique | `REQ-SEC-003`, `REQ-DATA-002` ; matrice de flux positive/négative | Platform + équipes apps |
| THR-004 | S/I/T | Un pair est usurpé ou un flux data intercepté/modifié. AST-01/02/03. | TB-01/02/04 | ASIS-002, ASIS-006, ASIS-007, ASIS-019 | 9 critique | `REQ-SEC-004`, `REQ-SEC-005` ; TLS valide, clair/mauvais certificat refusés | Platform/Data |
| THR-005 | I/E | Un secret fuit dans Git, une image, un log ou un Pod trop privilégié. AST-03. | TB-06/07/08 | ASIS-004, ASIS-011, ASIS-014, ASIS-016 | 9 critique | `REQ-SEC-006`, `REQ-DATA-003` ; scan, rotation, ancien secret refusé | Platform + Sécurité |
| THR-006 | T/E | Une dépendance, action CI ou image compromise injecte du code non approuvé. AST-05. | TB-06 | ASIS-013, ASIS-014, ASIS-015 | 9 critique | `REQ-SEC-007` ; artefact non conforme refusé à l'admission | Engineering + Sécurité |
| THR-007 | T/R | Un déploiement direct crée du drift, contourne les contrôles ou rend le rollback ambigu. AST-05/06. | TB-05/06 | ASIS-012, ASIS-015 | 6 élevé | `REQ-SEC-008`, `REQ-SVC-008` ; drift détecté et rollback Git chronométré | Platform + Engineering |
| THR-008 | T/D | Une coupure entre commit et publication perd un événement ou un rejeu crée un doublon métier. AST-02. | TB-04 | ASIS-007, ASIS-009 | 9 critique | `REQ-SVC-004/005`, `REQ-DATA-005` ; fault injection et rapprochement | Orders + Notifications |
| THR-009 | T/D | Panne/corruption PostgreSQL ou migration au boot provoque perte ou incohérence. AST-02/07. | TB-04/09 | ASIS-005, ASIS-009, ASIS-022 | 9 critique | `REQ-DATA-004/007` ; PITR isolé, migrations répétées, intégrité | Platform/Data + Produit |
| THR-010 | D | Perte control plane/nœud ou saturation de quota interrompt les workloads. AST-04. | projet/cluster | ASIS-003, ASIS-008, ASIS-020 | 9 critique | `REQ-SEC-009`, `REQ-SVC-011` ; panne Pod/nœud, reconstruction, seuils capacité | Platform |
| THR-011 | T/D/E | Le contrôleur d'entrée retiré ou vulnérable compromet routage/disponibilité. AST-01/04. | TB-01/03 | ASIS-002, ASIS-021 | 6 élevé | `REQ-SEC-004`; tests routes/TLS puis retrait contrôlé de l'ancien composant | Platform |
| THR-012 | R/T | Un incident reste invisible ou les preuves sont incohérentes à cause des logs absents, accès anonyme ou temps faux. AST-08. | TB-05/08 | ASIS-016, ASIS-017, ASIS-018, ASIS-019 | 9 critique | `REQ-SEC-010`, `REQ-SVC-009/010` ; incident synthétique et chronologie corrélée | Platform/SRE + Sécurité |
| THR-013 | I/T/D | Une sauvegarde est absente, altérée, lisible par un mauvais rôle ou inutilisable au moment de la reprise. AST-03/07. | TB-09 | ASIS-003, ASIS-005, ASIS-011, ASIS-022 | 9 critique | `REQ-SEC-011`, `REQ-DATA-007` ; restauration secondaire et accès refusé | Platform/Data + Sécurité |
| THR-014 | D | Un client, Pod ou contrôleur épuise CPU/RAM/connexions et affecte les autres tenants/services. AST-01/02/04. | TB-01/03/04 | ASIS-002, ASIS-008, ASIS-020 | 6 élevé | `REQ-SEC-009`, `REQ-SVC-011` ; charge bornée, quotas et dégradation contrôlée | Platform + Produit |
| THR-015 | I/E/D | Une mauvaise confiance entre projets expose la source AS-IS, les backups ou la cible. AST-04/07. | TB-10 | ASIS-001, ASIS-020, ASIS-022 | 6 élevé | `REQ-SEC-012` ; credentials/state séparés et tests inter-projets refusés/acceptés | Platform + Sécurité |
| THR-016 | T/D | Une migration ou restauration opérateur détruit la source avant validation de la cible. AST-02/04/07. | TB-09/10 | ASIS-003, ASIS-005, ASIS-012, ASIS-022 | 9 critique | `REQ-SEC-012`, `REQ-DATA-004/010` ; pré-check, répétition, critères d'arrêt et rollback | Platform/Data |

## 7. Exigences de sécurité testables

| ID | Exigence | Validation minimale future |
|---|---|---|
| REQ-SEC-001 | Toute route métier exige une identité vérifiée et une autorisation par rôle/tenant. | matrices anonyme, token invalide/expiré, mauvais rôle/tenant et bon rôle |
| REQ-SEC-002 | Tout accès privilégié est nominatif, fort, court, minimal et audité ; break-glass séparé et alerté. | connexion/revocation, rôle excessif refusé, exercice break-glass |
| REQ-SEC-003 | Les flux réseau commencent en default-deny et seuls les flux de la matrice sont permis. | tests depuis chaque namespace et source non autorisée |
| REQ-SEC-004 | L'entrée possède identité de service, TLS maintenu et routes explicites ; aucun ancien point non contrôlé ne subsiste. | TLS/nom/chaîne, routes valides/invalides et inventaire des listeners |
| REQ-SEC-005 | PostgreSQL, cache et bus authentifient les clients et refusent les flux en clair ou rôles non autorisés. | bon/mauvais certificat, bon/mauvais rôle, source autorisée/interdite |
| REQ-SEC-006 | Les secrets sont centralisés, limités par workload, rotatifs et absents de Git/images/télémétrie. | scan, rotation à chaud, révocation et tentative croisée entre services |
| REQ-SEC-007 | Tout artefact runtime est relié à un commit revu, des contrôles CI, une SBOM, une provenance et un digest vérifié. | image conforme admise ; tag mutable, provenance invalide et image inconnue refusés |
| REQ-SEC-008 | La configuration runtime est réconciliée depuis une source versionnée ; toute urgence est auditée et réconciliée. | création de drift, détection, correction et rollback |
| REQ-SEC-009 | Quotas, limites, réplication et dégradation empêchent une charge unique de provoquer une panne globale non maîtrisée. | charge/panne Pod/nœud et vérification du budget d'erreur |
| REQ-SEC-010 | Alertes, logs, traces et audits sont authentifiés, corrélables et horodatés ; l'accès anonyme est refusé. | incident synthétique, recherche de bout en bout, altération/refus d'accès |
| REQ-SEC-011 | Les sauvegardes critiques sont chiffrées, à identité distincte, protégées de la source et restaurables. | accès non autorisé refusé, suppression source simulée et restauration intègre |
| REQ-SEC-012 | Projets, credentials, states et chemins de migration sont séparés ; aucune destruction source avant critères de bascule. | plan sans destruction, tests de connectivité et exercice de rollback |

## 8. Référence entreprise et adaptation lab

### Référence entreprise

- séparation réelle des environnements et domaines de panne ;
- IdP, accès privilégié, secrets, data et sauvegardes exploités avec redondance
  adaptée aux RTO/RPO ;
- exposition B2B stable, TLS et protections contre abus ;
- preuves conservées selon la classification et la politique approuvée.

### Adaptation lab

- les mêmes identités, refus, policies, rotations, signatures, restores et
  rollbacks sont testés à petite échelle ;
- le provider network reste une contrainte à compenser et mesurer ;
- aucune HA de zone ou DR physique n'est revendiquée sans preuve T02 ;
- les tests n'utilisent que des identités et données synthétiques ;
- l'AS-IS reste disponible comme rollback pendant la migration blue/green.

## 9. Critères de sortie du modèle

- chaque menace possède actif, frontière, risque, propriétaire et test ;
- les scénarios couvrent compromission externe, interne, supply chain, panne et
  erreur opérateur ;
- chaque exigence comporte un succès et au moins un refus ou une panne attendue ;
- les contrôles décrivent des capacités, sans approuver prématurément un
  produit candidat T00 ;
- le risque ne sera réduit dans le registre qu'après preuve T17.
