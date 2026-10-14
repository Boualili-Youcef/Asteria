# D0 — Audit et contraintes

Date : 2026-10-14. Référence initiale : `fe8596b`. Branche : `demo/recruiter-v1`.
But : préparer la démo Orders sans altérer l'AS-IS.

## Faits vérifiés

| Contrôle | Statut | Résultat |
|---|---|---|
| Arbre initial | CONFIRMÉ | deux fichiers non suivis préexistants, préservés et exclus des commits |
| State source local | CONFIRMÉ | cinq instances dans les outputs ; ce fichier n'est pas un inventaire cloud actuel |
| Identité OpenStack source | CONFIRMÉ (collecte propriétaire) | sortie du script neutre : token et cinq IDs d'instances concordants ; aucun ID publié |
| Quotas et consommation Nova actuels | CONFIRMÉ (collecte propriétaire) | 5/8 instances ACTIVE, 9/10 vCPU, 17408/20480 MiB RAM |
| Ancien staging | INDISPONIBLE | compte retiré du périmètre par le propriétaire ; aucun contact tenté |
| Bastion source | CONFIRMÉ | SSH existant, clé locale, hôte déjà connu, commandes de lecture uniquement |
| Kubernetes source | CONFIRMÉ | trois nœuds Ready, K3s v1.36.2+k3s1 |
| Deployments applicatifs | CONFIRMÉ | Identity, Orders, Worker : 1/1 disponibles ; Redis 1/1 |
| Monitoring | CONFIRMÉ | Prometheus et Grafana 1/1 disponibles ; santé métier non déduite de ce seul état |
| Accès Kubernetes via bastion | CONFIRMÉ | lecture des Pods autorisée ; droits de promotion bornés pas encore provisionnés |
| Tests existants | CONFIRMÉ | 5 Identity + 5 Orders + 6 Worker passent avec le venv existant |
| Outils | CONFIRMÉ | Docker, Helm, kubectl, Terraform, OpenStack, gh ; Flutter/Dart absents |
| Session GitHub | CONFIRMÉ | gh authentifié ; publication non encore exécutée |
| Archives T04 locales | CONFIRMÉ | catalogue présent ; intégrité et restauration à revalider avant mutation |
| Digest GHCR → Pod Demo | NON VÉRIFIÉ | chemin à créer ; ne pas confondre image publiée et exécutée |
| Readiness des APIs et PostgreSQL source | CONFIRMÉ | trois APIs HTTP 200, pg_isready réussi sur la VM dédiée |
| Mesures Prometheus source | CONFIRMÉ | sum(up)=8, compteurs Orders=1 et Worker=1 ; aucune création de commande par cet audit |
| NTP et ressources des cinq VM | CONFIRMÉ | services actifs et NTP=yes partout ; mémoire/disque libres dans le rapport source |

Mesures K3s via metrics-server : CPU `176m / 105m / 181m` (8 / 5 / 9 %),
mémoire `951 / 650 / 1589 Mi` (24 / 16 / 40 %), dans l'ordre retourné par
le cluster. Bastion : 961 Mi au total, 548 Mi disponibles ; racine 50 % occupée,
4,4 Gi disponibles. Ce sont des photographies sans ajout de contrôleur.

## Hypothèses et limites

Les quotas sont reconfirmés par la collecte authentifiée du propriétaire,
distincte des lectures SSH effectuées directement. La restauration des backups,
le pull GHCR depuis les nœuds et l'isolation du nouveau namespace nécessitent
des contrôles complémentaires. Le pull local GHCR est refusé avec le credential
disponible ; un accès registre en lecture reste à préparer pour K3s.
Aucun résultat fonctionnel cloud ni rollback n'est déduit
des tests unitaires. Le VPN peut être coupé pendant les travaux locaux.

## Contradictions et décision

Le backlog historique autorise T08 sur un staging désormais inaccessible.
[ADR-015](../adr/ADR-015-demo-v1-source-only.md) ouvre un périmètre indépendant,
sans réécrire les preuves ni reprendre automatiquement la migration complète.
La présence d'un state source ne suffit pas à identifier une session Keystone.
L'identité et les ressources source ont maintenant été vérifiées. Les mutations
restent bloquées tant que l'isolation des données, les droits de promotion,
l'accès au registre et l'accord d'activation ne sont pas acquis.

## Reproduction et suite

Les commandes de collecte de lecture sont regroupées dans
`demo/scripts/preflight.py`. Les rapports bruts contenant IP, endpoints,
credentials et inventaires privés restent hors Git. Les preuves publiques
doivent être limitées aux résultats neutralisés.

Priorité autorisée : D1/D2 locaux. Un test Docker synthétique ne remplace pas
une validation K3s. Aucune nouvelle VM ni aucun contact du second projet.

Collectes finales :
[OpenStack, terminal propriétaire](../../demo/evidence/openstack-audit-20261014.json),
[VM et services, lecture SSH](../../demo/evidence/source-audit-20261014.json),
[Kubernetes](../../demo/evidence/kubernetes-audit-20261014.json).
