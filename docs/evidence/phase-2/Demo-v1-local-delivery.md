# Demo v1 — Livraison locale et contrôles

- Date : 2026-10-14
- Propriétaire : Youcef Boualili
- Branche : `demo/recruiter-v1`, référence de départ `fe8596b`
- Décision : [ADR-015](../../adr/ADR-015-demo-v1-source-only.md)
- Statut : D0 source inventorié, D1 tests locaux et CI validés, D2 build/digest/gate métier CI validés,
  D3 rollback simulé seulement,
  D4 observations partielles, D5 site statique publié et contrôlé en HTTP,
  D6 documentation livrée. Démonstration live non validée.

## Objectif, dépendances et résultat attendu

Prioriser Orders et la traçabilité commit/digest/workload. L'extension prépare
ASIS-004, ASIS-009, ASIS-012 à 017, ASIS-020 et ASIS-022 ; exigences
REQ-SVC-008/009/011, REQ-SEC-003/007 et REQ-DATA-009/010. Elle dépend du code
et des preuves historiques, sans accès au second projet. Aucun constat M16
n'est déclaré globalement corrigé par cette livraison.

## Faits et hypothèses

Faits : cluster source lu à 3/3 Ready, images M13 toujours utilisées, 20 tests
applicatifs et sept tests de livraison réussis, chart validé, backups locaux T04
intègres. Les commandes, dates, écarts et limites sont dans
[EVIDENCE](../../demo-v1/EVIDENCE.md) et [D0](../../demo-v1/00-audit-and-constraints.md).
La release CI finale `38614847670` passe scan HIGH/CRITICAL, smoke et parcours
métier sur son digest en 10,445 s, nettoyage compris. L'artefact canonique et
le commit ont été revérifiés ; aucun déploiement K3s n'est déduit de ce résultat.

Hypothèses non acquises : isolation effective du namespace,
pull GHCR depuis les workers, authentification opérateur bornée, santé métier
et restauration des backups. Les lectures complémentaires ont réussi après
réactivation du VPN : readiness HTTP 200, cinq services actifs et NTP synchronisé.
Les quotas sont confirmés par la sortie authentifiée du propriétaire, distincte
des mesures effectuées directement via SSH.

## Décisions et périmètre

Référence entreprise : GitOps, supply chain vérifiée à la consommation,
répétition et reprise testée selon ADR-010/011/014. Adaptation Demo : un workflow
Orders distinct, promotion depuis le poste privé, release Helm séparée et site
statique. Alternatives écartées : nouveau cluster cloud, runner administrateur,
Argo CD et Flutter pour cette première démonstration.

Fichiers : nouveau périmètre `demo/`, `docs/demo-v1/`, workflow Orders Demo,
ADR-015 et cette preuve ; options digest/traçabilité du chart existant et trois
tests Orders. README et backlog signalent la nouvelle contrainte. Les preuves
AS-IS/T00–T07 restent intactes. Les deux fichiers non suivis préexistants sont
préservés et exclus des commits de livraison.

## Impact, backup, rollback et arrêt

Ajouts de code, publication GitHub/GHCR et site public, aucun contrôleur supplémentaire. Aucun apply
Terraform, nouvelle VM, migration, écriture PostgreSQL historique ou déploiement
Kubernetes. Les fichiers suivis sont récupérables par Git ; les modifications
préexistantes ne sont ni écrasées ni embarquées dans les commits.

Les tests Docker locaux utilisent uniquement leurs ressources synthétiques
étiquetées ; leur nettoyage retire ces ressources, jamais celles du cloud.
Avant tout déploiement : nouvelle mesure de capacité, autorisation du bootstrap,
isolation réseau testée et jeu de données séparé. Arrêt si projet incertain,
quotas non vérifiés, artefact incohérent, backup non récupérable ou cible ambiguë.

La promotion exige une release antérieure saine par digest. Rollback Helm puis
rollout, image et probes vérifiés. Une impossibilité de vérifier le rollback
bloque le live. Les tests de cet algorithme utilisent des doublures : aucune
restauration Kubernetes réelle n'est revendiquée.

## Tests et acceptation

| Type | Contrôle | Résultat |
|---|---|---|
| positif | suites applications, rendu digest | PASS local |
| négatif | payload invalide, ordre inexistant, mauvais digest/dépôt/cluster | PASS local |
| sécurité | sorties expurgées, credential ignoré, refus de cible non marquée | gardes codés/testés selon le registre ; isolation K3s NON TESTÉE |
| idempotence | tests unitaires sans données externes ; E2E avec nom unique et nettoyage | répétition des suites PASS ; E2E métier et nettoyage PASS en 12,228 s |
| rollback | erreurs Helm/probes et impossibilité de rollback simulées | PASS local ; scénario réel NON TESTÉ |
| documentaire | distinction historique/courant/préparé, pas de faux Live | livrée ; contrôles finaux dans EVIDENCE |

## Dettes et prochaine action autorisée

La branche/CI et le site sont publiés dans le périmètre approuvé. Achever la
validation CI, puis préparer et faire approuver le bootstrap synthétique avec
son impact précis, après réinventaire source.
La prochaine mission TO-BE reste T08 après requalification de ses dépendances.
Demo v1 ne clôture pas T08–T18 et n'autorise pas leur exécution automatique.
