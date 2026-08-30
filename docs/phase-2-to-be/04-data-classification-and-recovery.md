# Classification des données et objectifs de reprise

## 1. Objet et statut

Ce document classe les données représentées par Asteria et fixe des RTO/RPO
candidats. Les valeurs traduisent une exigence à démontrer en T10, T15 et T17 ;
elles ne prouvent ni sauvegarde, ni réplication, ni DR dans le lab actuel.

Les exigences s'appliquent à la référence entreprise. L'adaptation lab doit
exécuter les mêmes contrôles de restauration, mais ne revendique pas un domaine
de panne indépendant tant que T02 ne l'a pas prouvé.

## 2. Faits vérifiés

- `identity_db` contient au minimum une adresse électronique et un nom affiché.
- `orders_db` contient au minimum un identifiant client et un montant.
- `notifications_db` archive le contenu des événements de commande.
- PostgreSQL est actuellement un primaire unique ; une sauvegarde locale non
  restaurée a été observée (`ASIS-005`).
- Redis transporte les événements sans réplication, TLS ni authentification
  (`ASIS-007`).
- Les mots de passe PostgreSQL sont injectés par Secrets Kubernetes créés
  manuellement, sans coffre ni rotation (`ASIS-011`).
- Aucun staging ou exercice de reprise de bout en bout n'est démontré
  (`ASIS-022`).

## 3. Hypothèses à faire valider

| ID | Hypothèse candidate | Autorité de validation |
|---|---|---|
| HYP-DATA-01 | Une adresse électronique et tout identifiant rattachable à une personne sont traités comme données personnelles restreintes. | Référent données / Sécurité |
| HYP-DATA-02 | Les montants et relations client-commande sont confidentiels au minimum. | Produit Orders / Référent données |
| HYP-DATA-03 | Les payloads de notification héritent du niveau le plus élevé de leurs données sources. | Produit Notifications / Sécurité |
| HYP-DATA-04 | Le lab n'utilise aucune donnée réelle de client ; seulement des données synthétiques. | Responsable du lab |
| HYP-DATA-05 | Les durées de conservation ci-dessous sont des minima opérationnels, pas une politique juridique définitive. | Juridique / Référent données |

## 4. Niveaux de classification

| Niveau | Définition | Contrôles minimaux |
|---|---|---|
| PUBLIC | Publication intentionnelle sans dommage prévisible. | intégrité de publication, licence et propriétaire |
| INTERNAL | Usage interne ; divulgation à impact faible ou modéré. | authentification, accès par rôle, pas de partage public implicite |
| CONFIDENTIAL | Données commerciales, techniques ou opérationnelles sensibles. | chiffrement en transit et au repos, moindre privilège, journalisation d'accès, sauvegardes chiffrées |
| RESTRICTED | Données personnelles, secrets ou éléments permettant une compromission majeure. | identité forte, accès explicite et audité, rotation/révocation, masquage hors production, interdiction dans Git/logs, restauration contrôlée |

Une sauvegarde, un export, un log ou une trace hérite de la classification la
plus élevée des données qu'il contient.

## 5. Inventaire initial des données

| Jeu de données | Exemples | Classe candidate | Propriétaire | Règles candidates |
|---|---|---:|---|---|
| Identités client | e-mail, nom affiché, identifiant utilisateur | RESTRICTED | Produit Identity | chiffrement, accès par tenant/rôle, masquage en staging, suppression selon politique métier |
| Commandes | identifiant client, montant, identifiant commande | CONFIDENTIAL ; RESTRICTED si rattachable à une personne | Produit Orders | chiffrement, intégrité, journal d'accès, aucune copie brute en environnement de test |
| Événements de commande | `order.created`, identifiants et montant potentiel | même niveau que la commande | Produits Orders/Notifications | bus durable, minimisation du payload, idempotence, DLQ protégée |
| Historique de notifications | événement archivé, statut et horodatage | même niveau que la source | Produit Notifications | accès métier limité et durée approuvée |
| Secrets et clés | mots de passe DB, tokens, clés privées, certificats | RESTRICTED | Platform/Sécurité | jamais dans Git/logs/images, rotation, révocation, audit |
| État et sauvegardes PostgreSQL | bases, WAL, dumps, snapshots | RESTRICTED | Platform/Data et propriétaires métier | chiffrement, copie distincte, rétention et restauration testée |
| État Kubernetes et secrets sauvegardés | objets, RBAC, Secrets, configuration | RESTRICTED | Platform | accès privilégié, chiffrement, procédure de reconstruction |
| Journaux d'audit | connexions, décisions d'accès, actions admin | RESTRICTED | Sécurité/Audit | append-only ou protection contre altération, horodatage fiable, accès restreint |
| Logs, métriques et traces applicatives | routes, statuts, identifiants de corrélation | CONFIDENTIAL par défaut | Platform et équipes applicatives | minimisation, aucune valeur de secret, accès OIDC, rétention bornée |
| Code, manifests et ADR | source sans secret, configuration déclarative | INTERNAL ou PUBLIC si publié volontairement | Engineering/Platform | revue, historique Git, scan de secret |
| Images, SBOM et provenance | artefacts de build et dépendances | INTERNAL | Engineering/Sécurité | digest immuable, contrôle d'intégrité, rétention des versions déployées |
| Données synthétiques du lab | utilisateurs et commandes fictifs | INTERNAL | Responsable du lab | aucune donnée client réelle, réinitialisation possible |

## 6. RTO/RPO candidats par service

### 6.1 Définitions

- **RTO** : durée maximale candidate entre le début de l'indisponibilité et la
  validation fonctionnelle du service restauré.
- **RPO** : perte maximale de données candidate mesurée entre le dernier point
  récupérable intègre et l'incident.
- **Réplication** : réduit certaines interruptions mais ne remplace pas une
  sauvegarde.
- **Sauvegarde** : fournit un point récupérable, validé uniquement après
  restauration et contrôle d'intégrité.
- **DR** : restaure un service dans un autre domaine de panne ; un second projet
  sur le même site ne suffit pas à prouver un DR physique.

### 6.2 Tableau de reprise

| Service/donnée | Criticité | RTO candidat | RPO candidat | Preuve exigée | Risques M16 |
|---|---:|---:|---:|---|---|
| Entrée B2B et APIs stateless | A | 1 h | non applicable aux Pods ; état déclaré sans perte | reconstruction et tests `JRN-01/02` | ASIS-002, ASIS-003, ASIS-008, ASIS-021 |
| `identity-api` + `identity_db` | A | 2 h | 15 min | restauration vers cible isolée, création/lecture et rapprochement | ASIS-005, ASIS-008, ASIS-022 |
| `orders-api` + `orders_db` | A | 1 h | 5 min | PITR, intégrité commande et rapprochement événements | ASIS-005, ASIS-009, ASIS-022 |
| Bus des événements de commande | A | 1 h | 5 min, aucun message acquitté perdu au-delà du RPO | panne broker, reprise backlog, DLQ et rejeu idempotent | ASIS-007, ASIS-009 |
| Worker + `notifications_db` | B | 4 h | 15 min | restauration, reprise du backlog et absence d'effet dupliqué | ASIS-007, ASIS-009, ASIS-022 |
| Cache | B | 30 min | perte totale acceptable si reconstruction sans corruption métier | suppression du cache et rechargement | ASIS-007 |
| Kubernetes control plane | A | 2 h | 15 min pour l'état non déclaratif ; zéro pour la configuration versionnée et distante | reconstruction cluster et redéploiement sur cible isolée | ASIS-003, ASIS-022 |
| Accès privilégié et secrets | B | 2 h avec chemin break-glass contrôlé | 15 min pour état/audit critique | restauration isolée, authentification, révocation et audit | ASIS-004, ASIS-011, ASIS-019, ASIS-022 |
| Git, CI, registre et source de vérité CD | C | 8 h ; le runtime continue sans nouveau changement | zéro pour Git distant ; 1 h pour métadonnées/artefacts non reproductibles | checkout propre, rebuild ou récupération du digest déployé | ASIS-012, ASIS-013, ASIS-014, ASIS-015 |
| Observabilité | C | 4 h | 1 h pour télémétrie standard ; 15 min pour audit sécurité | restauration stockage et recherche d'un incident synthétique | ASIS-016, ASIS-017, ASIS-019 |
| Sauvegardes et catalogue de reprise | A | 4 h pour rendre un point restaurable accessible | hérite du RPO du service source | lecture depuis le domaine secondaire et contrôle d'intégrité | ASIS-005, ASIS-022 |

Le RTO le plus strict d'une chaîne s'impose aux dépendances indispensables.
Par exemple, restaurer `orders-api` en 20 minutes ne respecte pas son RTO si
PostgreSQL ou le bus reste inutilisable après une heure.

## 7. Exigences de protection et de restauration

| ID | Exigence testable | Test d'acceptation futur | Risques M16 |
|---|---|---|---|
| REQ-DATA-001 | Tout datastore, sauvegarde, flux et signal d'observabilité possède classe, propriétaire et durée de conservation. | inventaire automatisé comparé à ce registre, aucun objet sans propriétaire | ASIS-005, ASIS-007, ASIS-011, ASIS-016 |
| REQ-DATA-002 | Tout flux contenant des données CONFIDENTIAL/RESTRICTED est chiffré et authentifie ses pairs lorsque supporté. | connexion TLS réussie, connexion en clair et mauvais certificat refusés | ASIS-001, ASIS-002, ASIS-006, ASIS-007 |
| REQ-DATA-003 | Les secrets ne résident ni dans Git, ni dans les images, ni dans la télémétrie ; rotation et révocation sont démontrées. | scan historique/build/logs, rotation sans redéploiement manuel et ancien secret refusé | ASIS-011, ASIS-014 |
| REQ-DATA-004 | PostgreSQL respecte le RTO/RPO le plus strict de ses bases et l'intégrité est vérifiée après PITR. | restauration chronométrée, requêtes métier et rapprochements avant/après | ASIS-005, ASIS-009, ASIS-022 |
| REQ-DATA-005 | Une commande acceptée et son événement durable sont atomiquement liés ; consommateurs idempotents, retries bornés et DLQ sont testés. | coupures aux points critiques, rejeu, comparaison commandes/événements/archives | ASIS-007, ASIS-009 |
| REQ-DATA-006 | Le cache est isolé du bus et peut être perdu/reconstruit sans perte métier. | purge totale contrôlée, trafic fonctionnel et cache repeuplé | ASIS-007 |
| REQ-DATA-007 | Chaque donnée critique possède au moins une copie récupérable hors de son domaine de panne logique, chiffrée et restaurée périodiquement. | restauration isolée depuis la copie secondaire avec checksum/intégrité | ASIS-003, ASIS-005, ASIS-022 |
| REQ-DATA-008 | Les journaux d'audit sont horodatés, protégés contre altération et conservés au moins 180 jours ; la télémétrie standard au moins 30 jours, sous réserve de validation coût/juridique. | recherche d'une session et d'un incident anciens ; modification non autorisée refusée | ASIS-016, ASIS-017, ASIS-018, ASIS-019 |
| REQ-DATA-009 | Staging et tests n'utilisent que des données synthétiques ou irréversiblement masquées. | scan d'échantillon et contrôle de provenance du jeu de données | ASIS-010, ASIS-011, ASIS-022 |
| REQ-DATA-010 | Une reconstruction Kubernetes depuis les sources autorisées restaure workloads, politiques et secrets dans le RTO, sans kubeconfig partagé. | cluster vide, restauration, tests fonctionnels et tests d'accès négatifs | ASIS-003, ASIS-004, ASIS-012, ASIS-022 |

## 8. Fréquence candidate des preuves

| Preuve | Référence entreprise | Minimum démontré par le lab |
|---|---|---|
| succès des sauvegardes | surveillance à chaque exécution | capture de chaque job testé |
| restauration PostgreSQL isolée | mensuelle et après changement majeur | au moins une restauration complète et un PITR en T15 |
| reconstruction Kubernetes | trimestrielle et après changement majeur | une reconstruction chronométrée avant clôture T17 |
| restauration secrets/accès | trimestrielle | un exercice incluant révocation et break-glass |
| reprise de bout en bout `JRN-08` | trimestrielle | un game day complet T17 |

Ces fréquences restent candidates jusqu'à l'évaluation du coût, du stockage et
des domaines de panne en T02/T03.

## 9. Critères d'arrêt d'une restauration ou migration

L'opération s'arrête et revient au plan de rollback si :

- la sauvegarde source n'est pas lisible ou son intégrité n'est pas vérifiable ;
- le point de récupération prévu ne peut pas être identifié ;
- le schéma cible est incompatible ou une migration non répétée est requise ;
- les contrôles d'accès sont plus ouverts que la source ;
- le RPO est déjà dépassé sans acceptation explicite du propriétaire ;
- la comparaison fonctionnelle révèle données manquantes, corrompues ou
  effets dupliqués.
