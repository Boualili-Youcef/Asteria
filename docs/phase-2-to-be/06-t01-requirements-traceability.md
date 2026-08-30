# Traçabilité des exigences T01 vers les risques M16

## 1. Règle de lecture

Cette matrice démontre que chaque constat M16 possède au moins une exigence
testable issue de T01. Le statut **Spécifiée** signifie que le test et son seuil
sont définis ; il ne signifie pas que le problème AS-IS est corrigé.

Un constat ne pourra passer à **Corrigé** qu'après implémentation, test positif,
test négatif ou de panne pertinent, mesure avant/après et preuve finale.

## 2. Matrice de couverture

| Risque M16 | Exigences T01 | Test/mesure de clôture attendu | Mission(s) de preuve | Statut T01 |
|---|---|---|---|---|
| ASIS-001 | REQ-SEC-003, REQ-SEC-012, REQ-DATA-002 | matrice de flux autorisés/refusés entre projets, hôtes, namespaces et data | T02, T07, T17 | Spécifiée |
| ASIS-002 | REQ-SVC-001, REQ-SEC-004, REQ-DATA-002 | entrée stable selon capacités T02, TLS valide, routes et mauvais hôte testés | T08, T17 | Spécifiée |
| ASIS-003 | REQ-SEC-009, REQ-DATA-007, REQ-DATA-010 | perte/reconstruction control plane chronométrée, état et workloads intègres | T07, T15, T17 | Spécifiée |
| ASIS-004 | REQ-SVC-006, REQ-SVC-007, REQ-SEC-002, REQ-SEC-003, REQ-DATA-010 | rôles minimaux, ServiceAccounts, flux default-deny, accès excessifs refusés | T06, T07, T09, T17 | Spécifiée |
| ASIS-005 | REQ-DATA-004, REQ-DATA-007, REQ-SEC-011 | PITR/restore PostgreSQL isolé dans RTO/RPO et intégrité métier vérifiée | T10, T15, T17 | Spécifiée |
| ASIS-006 | REQ-DATA-002, REQ-SEC-005 | connexion PostgreSQL TLS authentifiée réussie ; clair/mauvais rôle refusés | T10 | Spécifiée |
| ASIS-007 | REQ-SVC-005, REQ-DATA-005, REQ-DATA-006, REQ-SEC-005 | cache purgé sans perte métier ; bus sécurisé, panne, DLQ et rejeu testés | T09, T10, T11, T17 | Spécifiée |
| ASIS-008 | REQ-SVC-002, REQ-SVC-003, REQ-SEC-009 | perte d'un Pod puis d'un nœud sans dépassement du budget défini | T11, T17 | Spécifiée |
| ASIS-009 | REQ-SVC-004, REQ-SVC-005, REQ-DATA-004, REQ-DATA-005 | migrations répétables, coupure commit/publication, rejeu sans effet dupliqué | T10, T11, T17 | Spécifiée |
| ASIS-010 | REQ-SVC-006, REQ-SEC-001, REQ-DATA-009 | tests automatisés 401/403/2xx, mauvais tenant et aucune donnée réelle en staging | T09, T11 | Spécifiée |
| ASIS-011 | REQ-DATA-003, REQ-SEC-006, REQ-SEC-011 | secret rotaté/révoqué, scan propre et accès croisé refusé | T09, T15, T17 | Spécifiée |
| ASIS-012 | REQ-SVC-008, REQ-SEC-008, REQ-DATA-010 | même promotion/rollback pour trois apps, drift détecté puis réconcilié | T12, T13, T16 | Spécifiée |
| ASIS-013 | REQ-SVC-008, REQ-SEC-007 | workflow commun exécute les mêmes gates sur les trois services | T12 | Spécifiée |
| ASIS-014 | REQ-DATA-003, REQ-SEC-006, REQ-SEC-007 | scans, SBOM/provenance ; artefact inconnu ou invalide bloqué | T09, T12 | Spécifiée |
| ASIS-015 | REQ-SVC-008, REQ-SEC-007, REQ-SEC-008 | commit, provenance, digest approuvé et digest runtime identiques | T12, T13 | Spécifiée |
| ASIS-016 | REQ-SVC-009, REQ-DATA-001, REQ-DATA-008, REQ-SEC-010 | télémétrie persistante, dépendances couvertes et recherche après redémarrage | T14, T15 | Spécifiée |
| ASIS-017 | REQ-SVC-009, REQ-SEC-010 | incident synthétique détecté ≤ 5 min et expliqué ≤ 30 min | T14, T17 | Spécifiée |
| ASIS-018 | REQ-SVC-007, REQ-DATA-008, REQ-SEC-002, REQ-SEC-010 | anonyme refusé, rôles lecture/édition testés, session auditée | T09, T14 | Spécifiée |
| ASIS-019 | REQ-SVC-010, REQ-DATA-008, REQ-SEC-010 | écart NTP mesuré < 1 s et alerte de dérive vérifiée | T04, T14 | Spécifiée |
| ASIS-020 | REQ-SVC-011, REQ-SEC-009, REQ-SEC-012 | inventaire dual-project, plan sous quotas, marge/exception et charge testée | T02, T03, T17 | Spécifiée |
| ASIS-021 | REQ-SVC-001, REQ-SEC-004 | routes/TLS équivalents validés avant retrait contrôlé de l'ancien Ingress | T08 | Spécifiée |
| ASIS-022 | REQ-DATA-004, REQ-DATA-007, REQ-DATA-010, REQ-SEC-011, REQ-SEC-012 | staging séparé, restauration E2E dans RTO/RPO et rollback source | T05, T15, T17 | Spécifiée |

## 3. Catalogue des exigences

| Famille | IDs | Source |
|---|---|---|
| Service et expérience | REQ-SVC-001 à REQ-SVC-011 | `03-service-objectives.md` |
| Données et reprise | REQ-DATA-001 à REQ-DATA-010 | `04-data-classification-and-recovery.md` |
| Sécurité et menace | REQ-SEC-001 à REQ-SEC-012 | `05-threat-model.md` |

## 4. Règles de validation pour les missions suivantes

1. Copier les IDs concernés dans le plan et la preuve de mission.
2. Capturer la mesure AS-IS ou indiquer explicitement qu'elle est impossible.
3. Exécuter le succès attendu puis au moins un refus ou une panne pertinente.
4. Capturer durée, résultat et écart sans secret ni donnée client.
5. Ne fermer le constat que si le critère mesurable est satisfait.
6. En cas d'échec, conserver le constat ouvert avec propriétaire, compensation
   et échéance ; ne pas diminuer le seuil après coup sans décision métier.

## 5. Couverture

- constats M16 : 22 ;
- constats couverts par au moins une exigence : 22 ;
- exigences T01 définies : 33 ;
- constats corrigés par T01 : 0, car T01 spécifie sans modifier le runtime.
