# Demo v1 — Livraison et validation K3s

- Date : 2026-10-14 ; propriétaire : Youcef Boualili.
- Branche : `demo/recruiter-v1` ; référence initiale : `fe8596b`.
- Décision : [ADR-015](../../adr/ADR-015-demo-v1-source-only.md).
- Lecture principale : [présentation](../../../demo/README.md) et
  [guide opérateur](../../../demo/RUNBOOK.md).

## Objectif et dépendances

Prouver commit → CI → digest → K3s → test métier → rollback dans un namespace
isolé. Extension source uniquement, sans terminer mécaniquement T08–T18.
Traçabilité : ASIS-004/009/012/013/014/015/016/017/020/022 ; REQ-SVC-008/009/011,
REQ-SEC-003/007 et REQ-DATA-009/010. Les constats M16 restent ouverts globalement.

## Faits vérifiés

- Source : cinq VM actives ; quotas confirmés par la sortie authentifiée du
  propriétaire (9/10 vCPU, 17408/20480 MiB, 5/8 instances). Trois nœuds Ready.
- 20 tests applicatifs et 13 contrôles de livraison passent localement.
- CI de l'image promue : run 38622409565, scan 0 HIGH/CRITICAL, smoke et
  parcours Docker réels réussis. Artefact canonique revérifié avant promotion.
- Quatre Deployments synthétiques disponibles dans asteria-demo. Le digest
  demandé, le Deployment et les imageID observés concordent.
- Promotion : 36,323 s ; drill readiness et rollback : 209,505 s ; test métier
  après retour arrière : 12,151 s. Les trois commandes du scénario sont
  persistées, relues et archivées avec le même order_id.
- Accès réseau autorisé accepté ; client non autorisé et accès inter-namespaces
  refusés. Droits démo autorisés ; opérations historiques/cluster refusées.
- 64 lectures health/ready à 200 pendant l'exercice, sans revendication de SLO.
- État final : images historiques inchangées, trois nœuds Ready, tunnel fermé,
  fichier du token temporaire supprimé, Pods de test retirés.

Hypothèses non acquises : HA, DR, restauration de données, SLO de production,
vérification de signature à l'admission et disponibilité du second compte.

## Décisions et compromis

Réutiliser le chart Orders, les applications et le source K3s. Publier l'image
Orders par digest ; promotion depuis un opérateur privé, pas depuis le runner.
Namespace avec quota, PSA restricted, huit policies et identité courte bornée.
Données dédiées jetables, sans PVC et sans accès public. Exception de lab :
flux PostgreSQL/Redis internes sans TLS, données factices et secret neuf.

Alternatives écartées : nouveau cluster/VM, contrôleur GitOps lourd, refonte
Worker et frontend Flutter. La cible entreprise reste distincte de ce lab.

## Fichiers et commandes

Livraison : scripts et site sous `demo/`, deux guides de lecture, workflow
Orders Demo et workflow Pages ; adaptation digest rétrocompatible du chart,
readiness Redis corrigée et quatre tests Orders ajoutés. Les preuves AS-IS et
T00–T07 ne sont pas réécrites.

L'ordre reproductible est dans [RUNBOOK](../../../demo/RUNBOOK.md) : lecture
source, contrôles privés, préparation du bundle, socle et policies, dépendances,
installation initiale, refus réseau/RBAC, aperçu, promotion, test métier, drill,
rollback et test métier final. Les scripts exigent contexte et UID explicites.
Les paramètres d'identité, endpoints, credentials et logs bruts restent privés.

## Impact, backup et rollback

Ajouts : un namespace, quatre Deployments, trois Services ClusterIP, quota et
LimitRange, huit policies, deux ServiceAccounts, rôle/bindings et lecture
cluster limitée à deux objets Namespace. Aucun apply Terraform, nouvelle VM,
Ingress, NodePort, PVC, migration ou modification de données historiques.

Budget : 80m/288Mi demandés, 1 CPU/864Mi limités. Mesure finale ponctuelle :
environ 133,4 MiB de mémoire cumulée pour les quatre conteneurs.
Les catalogues d'archives source T04 ont été vérifiés avant activation, sans
restauration revendiquée. La nouvelle base ne contient que des données jetables.
La disparition de son Pod peut les perdre ; aucune sauvegarde data validée.

Le rollback Helm rétablit une révision saine puis recontrôle image et probes.
Il a été exécuté, puis le parcours métier a été revérifié. Un premier essai
Helm 3.15 RC a dépassé son délai et a également été annulé ; la reprise stable
3.19.0 a réussi. La cause profonde n'est pas isolée. La version validée est
maintenant imposée, avec diagnostics optionnels en fichier privé.

Arrêt si identité, capacité, réseau ou droits sont incertains, si les workloads
historiques se dégradent ou si le retour arrière n'est pas vérifiable.
Aucune suppression automatique de namespace ; les services de démo sont gardés.

## Tests, critères et preuves

| Contrôle | Résultat |
|---|---|
| Positif | CI, probes, digest et trois parcours métier K3s : PASS |
| Négatif | readiness 404 observée 21 fois ; échec et rollback : PASS |
| Sécurité | refus réseau et RBAC, secrets hors Git, token de 1800 s : PASS dans ce périmètre |
| Idempotence | clients métier uniques ; génération refusant écrasement/rotation ; tests répétés : PASS |
| Compatibilité | chart par défaut sémantiquement identique à la référence AS-IS ; rendu digest valide |
| Présentation | bundle limité à quatre fichiers ; site statique, aucune commande cloud côté visiteur |

Les preuves indiquent dates, versions, durées et écarts :
[replay K3s](../../../demo/evidence/kubernetes-flow-20261014.json),
[release](../../../demo/evidence/orders-release.json),
[CI](../../../demo/evidence/ci-verification-20261014.json),
[inventaire propriétaire](../../../demo/evidence/openstack-audit-20261014.json).
La revue visuelle navigateur reste non exécutée faute de navigateur connecté.

## Dettes et prochaine mission

Outbox/DLQ absentes ; Worker M13 en cache avec sources/requirements contrôlés ;
flux data internes non chiffrés ; métriques directes sans ajout au Prometheus
historique ; données non restaurées ; pas de HA/DR ni de signature à l'admission.
Ces limites sont exposées dans la présentation, sans survente.

La démo est validée dans ce périmètre. La mission TO-BE suivante reste T08 après
requalification de ses dépendances ; cette livraison ne clôture pas T08–T18.
