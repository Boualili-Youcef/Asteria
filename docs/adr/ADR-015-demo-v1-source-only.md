# ADR-015 — Démonstration Orders sur le seul projet source

- Statut : accepté pour le code et les validations locales ; activation cloud soumise à accord distinct
- Date : 2026-10-14
- Propriétaire : Youcef Boualili
- Portée : extension Demo v1, indépendante de T08–T18

## But et décision

Rendre vérifiable le parcours commit → tests → image immuable → promotion
opérateur → validation → rollback, sans reconstruire la plateforme historique.
Le second compte OpenStack n'est plus accessible. Ses preuves T05–T07 restent
historiques ; aucune connexion à ses VM ou API n'est nécessaire à la démo.

Réutiliser le chart Orders avec une option digest rétrocompatible. Un nouveau
workflow produit une image et un artefact de release, sans credential cluster.
La promotion s'exécute sur le poste privé, dans `asteria-demo`, avec contexte
et identité du cluster explicitement vérifiés. Aucune adoption de release
historique, aucune création implicite de namespace, aucun apply Terraform.

Un site statique sans dépendance présente les preuves, les étapes préparées et
les limites. Ce choix a été retenu plutôt que Flutter, absent du poste : il
évite une installation et reste hébergeable sans cloud privé. Le site ne
possède aucun accès d'administration. Un scénario préparé n'est pas un replay
validé ; seul un enregistrement exécuté peut porter ce nom.

## Traçabilité et alternatives

| Besoin | Risques préparés | Preuve recherchée |
|---|---|---|
| REQ-SVC-008, REQ-SEC-007 | ASIS-012, ASIS-013, ASIS-014, ASIS-015 | tests, digest, commit et image observée concordants |
| REQ-DATA-009, REQ-SEC-003 | ASIS-004, ASIS-009, ASIS-010 | données synthétiques isolées, accès bornés |
| REQ-SVC-009, REQ-DATA-010 | ASIS-016, ASIS-017, ASIS-022 | observation et rollback mesurés |
| REQ-SVC-011 | ASIS-020 | consommation avant/après et budget namespace |

La cible entreprise des ADR-010/011/014 reste GitOps, contrôles supply chain et
répétition avant migration. Demo v1 accepte une promotion manuelle bornée et
ne clôture aucun constat global. Un runner distant administrateur, un nouveau
cluster cloud et une installation Argo CD sont écartés pour cette extension.

## Conséquences sur les dépendances

T08–T18 restent à faire. Leur exécution sur l'ancien staging est indisponible.
Avant reprise : nouvel inventaire source, capacité, environnement de répétition,
sauvegarde restaurée et révision des ADR concernées. Demo v1 ne les remplace
pas et ne démontre ni HA, ni DR, ni SLO entreprise.

## Arrêt, impact et rollback

Les ajouts locaux sont réversibles par revert des commits Demo v1. Le chart
conserve le tag `m13` par défaut. Les ressources proposées sont limitées à un
namespace neuf, sans PVC, Ingress ni nouveau port public. L'activation nécessite
une validation de capacité et de l'isolation, un jeu synthétique séparé et un
accord préalable ; aucune base historique n'est utilisée.

Une release saine par digest doit exister avant promotion. Un échec entraîne
un rollback Helm, puis une vérification du digest précédent et de `/ready`.
Un rollback non vérifié bloque la démo live. L'effacement des données et du
namespace reste une opération séparée, jamais automatique dans le cloud.
