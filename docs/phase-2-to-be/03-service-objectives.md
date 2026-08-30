# Objectifs de service et parcours critiques

## 1. Objet et statut

Ce document définit les parcours, responsabilités, indicateurs et objectifs de
service candidats de T01. Il décrit **ce que la plateforme doit garantir** ; il
ne choisit pas encore les produits qui réaliseront ces garanties.

Les valeurs sont des objectifs internes candidats. Elles ne constituent pas un
engagement contractuel envers un client et devront être approuvées par les
responsables métier avant T03.

## 2. Faits vérifiés

- Asteria représente une PME SaaS européenne de 100 à 500 employés servant des
  clients B2B sur un cloud OpenStack privé.
- Le domaine commercial, le nombre de clients, la volumétrie et les contrats
  de service ne sont pas définis.
- `identity-api` crée et lit des utilisateurs dans `identity_db`.
- `orders-api` crée et lit des commandes dans `orders_db`, puis publie un
  événement `order.created` dans Redis.
- `notifications-worker` consomme cet événement et l'archive dans
  `notifications_db` ; il n'envoie actuellement aucun message à un fournisseur
  externe.
- Les trois workloads exposent des contrôles de santé et des métriques.
- Aucun SLO, Alertmanager, logging centralisé ou tracing n'est présent dans
  l'AS-IS (`ASIS-016`, `ASIS-017`).
- L'authentification métier et l'isolation par tenant n'existent pas encore
  (`ASIS-010`).

## 3. Hypothèses à faire valider

| ID | Hypothèse candidate | Autorité de validation | Conséquence si refusée |
|---|---|---|---|
| HYP-T01-01 | Les parcours B2B sont mesurés 24 h/24, même si le support humain n'est pas disponible 24 h/24. | Direction produit | Modifier fenêtres SLO et astreinte. |
| HYP-T01-02 | La création de commande est le parcours métier le plus critique. | Responsable produit Orders | Reclasser priorités, RTO et budget d'erreur. |
| HYP-T01-03 | Une notification peut être asynchrone : 99 % en 60 s et 99,9 % en 5 min sont acceptables. | Responsable produit Notifications | Redimensionner le bus et le worker. |
| HYP-T01-04 | Les indisponibilités planifiées comptent dans les SLO utilisateurs. | Direction produit et Platform | Définir explicitement les exclusions contractuelles. |
| HYP-T01-05 | Le mois glissant de 30 jours est la fenêtre commune de décision. | Platform et Produit | Adapter alertes et budgets d'erreur. |
| HYP-T01-06 | Les objectifs portent sur un trafic B2B raisonnable ; le débit maximal sera fixé après mesure et test de charge. | Produit et équipes applicatives | Définir une capacité contractuelle avant T11. |
| HYP-T01-07 | Les propriétaires sont des rôles et non des personnes tant que l'organigramme nominatif n'est pas défini. | Direction technique | Nommer les responsables et remplaçants. |

Une hypothèse non approuvée ne devient pas silencieusement un fait. Elle reste
visible dans les ADR T03 et dans le registre des risques.

## 4. Criticité et responsabilités

### 4.1 Niveaux de criticité

| Niveau | Définition | Exemples Asteria |
|---|---|---|
| A — critique | Interrompt une fonction B2B essentielle ou risque une perte/incohérence de données. | commandes, identités, PostgreSQL, entrée client |
| B — important | Dégrade une fonction différable ou bloque l'exploitation sécurisée. | notifications, accès d'administration, secrets |
| C — support | Ne coupe pas immédiatement le trafic existant, mais bloque changement, diagnostic ou preuve. | CI/CD, registre, observabilité |

### 4.2 Modèle de propriété

| Service/capacité | Niveau | Responsable de service | Responsable technique | Approbateur sécurité/données |
|---|---:|---|---|---|
| Entrée B2B et routage | A | Responsable produit transverse | Équipe Platform | Équipe Sécurité/Audit |
| `identity-api` | A | Responsable produit Identity | Équipe Identity | Sécurité/Audit et référent données |
| `orders-api` | A | Responsable produit Orders | Équipe Orders | Sécurité/Audit et référent données |
| Traitement des notifications | B | Responsable produit Notifications | Équipe Notifications | Sécurité/Audit et référent données |
| PostgreSQL | A | Propriétaires des données métier | Équipe Platform/Data | Sécurité/Audit et référent données |
| Cache et messagerie | A pour événements, B pour cache | Responsable produit Orders | Platform et équipes Orders/Notifications | Sécurité/Audit |
| Kubernetes et réseau | A | Direction technique | Équipe Platform | Équipe Sécurité/Audit |
| Accès privilégié et secrets | B | Direction technique | Équipe Platform | Équipe Sécurité/Audit |
| CI, registre et promotion | C | Responsables Engineering | Platform et équipes applicatives | Équipe Sécurité/Audit |
| Observabilité et incident | C | Direction technique | Équipe Platform/SRE | Équipe Sécurité/Audit |

Le responsable de service arbitre le risque et le budget d'erreur. Le
responsable technique opère le service. L'approbateur contrôle les exigences de
sécurité et de protection des données ; ces responsabilités ne doivent pas être
confondues.

## 5. Parcours critiques

| ID | Parcours et résultat métier attendu | Dépendances | Criticité | Propriétaire principal | Échec observable |
|---|---|---|---:|---|---|
| JRN-01 | Créer un utilisateur puis le relire avec le même identifiant. | entrée, Identity, PostgreSQL | A | Produit Identity | erreur inattendue, donnée absente ou différente |
| JRN-02 | Créer une commande, recevoir son identifiant puis relire la commande persistée. | entrée, Orders, PostgreSQL | A | Produit Orders | erreur, commande absente, montant/client altéré |
| JRN-03 | Pour toute commande acceptée, rendre durable un événement puis l'archiver sans perte et sans effet métier dupliqué. | Orders, PostgreSQL, bus, Notifications | A | Produits Orders et Notifications | événement perdu, bloqué, corrompu ou doublon non maîtrisé |
| JRN-04 | Refuser un client non authentifié, un mauvais tenant ou un rôle non autorisé, et accepter le rôle attendu. | IdP, entrée, APIs | A | Produit et Sécurité/Audit | accès illégitime ou refus illégitime |
| JRN-05 | Accéder à une ressource d'administration avec une identité forte, une autorisation minimale et une trace corrélable. | IdP, accès privilégié, NTP, audit | B | Équipe Platform | accès anonyme/excessif ou absence de trace |
| JRN-06 | Construire, vérifier, promouvoir puis annuler la même version immuable des trois services. | Git, CI, registre, source de vérité CD | C | Responsables Engineering | digest différent, contrôle contourné ou rollback inexécutable |
| JRN-07 | Détecter un incident synthétique, identifier le parcours touché et accéder aux signaux nécessaires au diagnostic. | métriques, alertes, logs, traces, temps | C | Platform/SRE | incident non détecté ou diagnostic sans preuve |
| JRN-08 | Restaurer les données et la plateforme dans les objectifs déclarés, puis vérifier leur intégrité fonctionnelle. | sauvegardes, stockage, runbooks, cible de reprise | A | Platform/Data et Produit | RTO/RPO dépassé ou données incohérentes |

Le parcours `JRN-03` s'arrête actuellement à l'archivage de la notification.
L'envoi d'un courriel, SMS ou webhook est hors spécification tant qu'un besoin
métier ne le définit pas.

## 6. Définitions des SLI

### 6.1 Disponibilité HTTP

```text
SLI disponibilité = requêtes éligibles au résultat attendu
                    / total des requêtes éligibles
```

Sont éligibles les requêtes métier syntaxiquement valides. Les `5xx`, timeouts,
connexions refusées et `429` causés par la plateforme sont mauvais. Les `4xx`
fonctionnels attendus, les endpoints `/health`, `/ready`, `/metrics` et le
trafic de test explicitement étiqueté ne sont pas dans le dénominateur. Une
panne d'une dépendance interne reste imputée au parcours utilisateur.

### 6.2 Latence

La latence est mesurée au point d'entrée, du premier octet reçu à la réponse
complète, sur les requêtes métier valides. Le percentile est calculé sur une
fenêtre suffisamment volumineuse ; en dessous de 100 requêtes, le résultat est
informatif et non une preuve statistique.

### 6.3 Fraîcheur asynchrone

```text
latence événement = horodatage d'archivage - horodatage du commit durable
SLI fraîcheur     = événements archivés avant le seuil / événements durables
```

Un événement placé en DLQ n'est pas perdu, mais il reste mauvais pour le SLI de
fraîcheur jusqu'à son traitement réussi. Les doublons techniques sont tolérés
uniquement si le résultat métier est idempotent.

### 6.4 Livraison, détection et reprise

- promotion : nombre de promotions saines / promotions démarrées ;
- cohérence : digest runtime égal au digest approuvé ;
- détection : temps entre injection de la panne et alerte reçue ;
- RTO : temps entre indisponibilité déclarée et service fonctionnel validé ;
- RPO : écart entre le dernier état récupérable validé et l'incident.

## 7. SLO candidats

| ID | Périmètre | Objectif sur 30 jours glissants | Validation future | Risques M16 |
|---|---|---|---|---|
| REQ-SVC-001 | Entrée B2B, `JRN-01/02` | 99,95 % de requêtes synthétiques valides atteignent la bonne route avec TLS valide. | sondes depuis au moins deux points et test de bascule | ASIS-002, ASIS-008, ASIS-021 |
| REQ-SVC-002 | `identity-api`, `JRN-01` | disponibilité 99,9 % ; p95 création ≤ 500 ms ; p95 lecture ≤ 300 ms. | trafic synthétique et métriques au Gateway | ASIS-008, ASIS-016, ASIS-017 |
| REQ-SVC-003 | `orders-api`, `JRN-02` | disponibilité 99,9 % ; p95 création ≤ 750 ms ; p95 lecture ≤ 300 ms. | création/lecture synthétique avec identifiant corrélé | ASIS-005, ASIS-007, ASIS-008, ASIS-017 |
| REQ-SVC-004 | intégrité commande/événement, `JRN-02/03` | 100 % des réponses `201` correspondent à une commande durable et à un événement durable atomiquement lié ; aucun effet métier dupliqué après rejeu. | test de coupure aux points de panne et rapprochement DB/bus | ASIS-009 |
| REQ-SVC-005 | Notifications, `JRN-03` | 99 % des événements archivés en ≤ 60 s et 99,9 % en ≤ 5 min ; aucun événement acquitté perdu. | horodatages corrélés, backlog et test DLQ/rejeu | ASIS-007, ASIS-009, ASIS-017 |
| REQ-SVC-006 | Authentification/autorisation, `JRN-04` | 100 % des scénarios négatifs de la matrice d'accès donnent `401/403` ; 100 % des scénarios autorisés donnent le résultat fonctionnel attendu. | tests automatisés anonyme, mauvais rôle, mauvais tenant, bon rôle | ASIS-004, ASIS-010 |
| REQ-SVC-007 | Accès privilégié, `JRN-05` | 100 % des sessions quotidiennes utilisent identité forte, privilège court et audit ; tout break-glass alerte en ≤ 5 min. | revue de sessions et exercice break-glass | ASIS-004, ASIS-011, ASIS-018, ASIS-019 |
| REQ-SVC-008 | Livraison, `JRN-06` | 95 % des changements standards sont promus en staging en ≤ 15 min ; digest approuvé = digest runtime dans 100 % des contrôles ; rollback sain en ≤ 15 min. | pipeline commun exécuté sur les trois services | ASIS-012, ASIS-013, ASIS-014, ASIS-015 |
| REQ-SVC-009 | Incident, `JRN-07` | incident critique synthétique détecté en ≤ 5 min, notification reçue en ≤ 10 min, parcours et dépendance identifiés en ≤ 30 min. | game day avec chronologie, métriques, logs et traces | ASIS-016, ASIS-017, ASIS-019 |
| REQ-SVC-010 | Temps distribué | écart NTP absolu < 1 s sur 99,99 % des mesures et alerte si écart ≥ 2 s pendant 5 min. | métrique hôte et comparaison horodatée | ASIS-019 |
| REQ-SVC-011 | Capacité | aucune ressource planifiée ne dépasse quota ; marge normale cible ≥ 20 % CPU/RAM/stockage après charge de référence, ou exception approuvée. | inventaire T02, requests/limits et test de charge T17 | ASIS-020 |

### 7.1 Budgets d'erreur

Pour un SLO basé sur les requêtes, le budget est calculé sur le volume réel :

- 99,95 % autorise 0,05 % de mauvais événements ;
- 99,9 % autorise 0,1 % de mauvais événements ;
- 99 % autorise 1 % de mauvais événements.

L'équivalent temporel sur 30 jours est seulement indicatif : 99,95 % représente
environ 21 min 36 s et 99,9 % environ 43 min 12 s. La décision de ralentir les
changements se prend sur la consommation du budget par parcours, pas sur une
moyenne globale qui masquerait un service défaillant.

## 8. Critères d'acceptation T01

- chaque parcours possède un résultat et un propriétaire par rôle ;
- chaque SLI indique numérateur, dénominateur, fenêtre ou chronologie ;
- chaque objectif est testable et relié à au moins un constat M16 ;
- les objectifs de sécurité à 100 % sont vérifiés par scénarios positifs et
  négatifs, pas déclarés à partir d'une absence d'incident ;
- aucune conformité au SLO n'est revendiquée avant instrumentation T14 et
  observation ;
- les valeurs candidates non validées restent des hypothèses pour T03.
