# Preuve T01 — Objectifs de service et modèle de menace

## Métadonnées

- **Date :** 2026-08-30
- **Mission :** T01
- **Statut :** réussi
- **Périmètre :** exigences, risques et documentation uniquement
- **Runtime modifié :** non

## Objectif et résultat

T01 définit ce que la plateforme doit rendre disponible, protéger et restaurer
avant de sélectionner définitivement les mécanismes T03.

Résultat obtenu :

- 8 parcours critiques avec résultat observable et propriétaire par rôle ;
- 11 objectifs/exigences de service `REQ-SVC-xxx` ;
- 4 classes et 12 catégories initiales de données ;
- RTO/RPO candidats pour 11 services ou ensembles de données ;
- 10 frontières de confiance ;
- 16 scénarios de menace avec actif, score initial, propriétaire et test ;
- 12 exigences sécurité `REQ-SEC-xxx` ;
- 10 exigences data/reprise `REQ-DATA-xxx` ;
- 33 exigences au total, reliées aux 22 constats M16.

## Dépendances et constats concernés

- T00 est terminé ;
- M16 fournit le registre `ASIS-001` à `ASIS-022` ;
- les applications M13 fournissent les parcours Identity, Orders et
  Notifications ;
- les preuves M03 à M16 décrivent les dépendances et limites du lab.

T01 couvre les 22 constats au niveau **Spécifiée**. Aucun constat n'est fermé
par cette mission, qui n'implémente aucun contrôle.

## Faits et hypothèses

Les faits proviennent des documents AS-IS et du code applicatif : endpoints,
données minimales, dépendances PostgreSQL/Redis et absence actuelle de SLO.

Les éléments inconnus sont conservés comme hypothèses explicites : engagements
contractuels, trafic, horaires métier, tolérance de notification, propriétaires
nominatifs, conservation juridique et indépendance des deux projets. Leur
validation appartient aux responsables métier/sécurité simulés et aux ADR T03.

## Décisions T01

1. mesurer les parcours plutôt qu'un unique taux de disponibilité plateforme ;
2. utiliser une fenêtre candidate de 30 jours et des budgets basés sur les
   événements ;
3. compter les pannes des dépendances internes dans le SLO utilisateur ;
4. traiter création de commande et durabilité de son événement comme un même
   invariant ;
5. ne pas prétendre envoyer une notification externe : le worker l'archive ;
6. classer les sauvegardes et la télémétrie selon les données qu'elles
   contiennent ;
7. distinguer réplication, sauvegarde et DR ;
8. exprimer les contrôles comme capacités testables sans approuver les produits
   candidats T00 ;
9. utiliser des propriétaires par rôle jusqu'à définition d'un organigramme ;
10. ne réduire aucun risque avant preuves d'implémentation et de panne T17.

Alternatives écartées : disponibilité à 100 %, SLO global masquant les services,
RTO/RPO choisis depuis un produit, sauvegarde déclarée valide sans restauration,
et modèle de menace limité aux seuls attaquants externes.

## Livrables

- `docs/phase-2-to-be/03-service-objectives.md` ;
- `docs/phase-2-to-be/04-data-classification-and-recovery.md` ;
- `docs/phase-2-to-be/05-threat-model.md` ;
- `docs/phase-2-to-be/06-t01-requirements-traceability.md` ;
- `docs/diagrams/to-be-trust-boundaries.mmd` ;
- mise à jour de `PHASE_2_BACKLOG.md`.

## Commandes de validation

```bash
git diff --check

rg '^\| ASIS-[0-9]{3} ' \
  docs/phase-2-to-be/06-t01-requirements-traceability.md | wc -l

rg -o --no-filename 'ASIS-[0-9]{3}' \
  docs/phase-2-to-be/06-t01-requirements-traceability.md \
  | sort -u | wc -l

comm -23 \
  <(seq -f 'ASIS-%03g' 1 22) \
  <(rg -o --no-filename 'ASIS-[0-9]{3}' \
    docs/phase-2-to-be/06-t01-requirements-traceability.md | sort -u)

comm -23 \
  <(rg -o --no-filename 'REQ-(SVC|DATA|SEC)-[0-9]{3}' \
    docs/phase-2-to-be/03-service-objectives.md \
    docs/phase-2-to-be/04-data-classification-and-recovery.md \
    docs/phase-2-to-be/05-threat-model.md | sort -u) \
  <(rg -o --no-filename 'REQ-(SVC|DATA|SEC)-[0-9]{3}' \
    docs/phase-2-to-be/06-t01-requirements-traceability.md | sort -u)

docker run --rm \
  -v "$PWD:/data" \
  -v /tmp:/host-tmp \
  ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:latest \
  -i /data/docs/diagrams/to-be-trust-boundaries.mmd \
  -o /host-tmp/to-be-trust-boundaries.svg

rg -n \
  '(-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----|OS_PASSWORD\s*=|github_pat_[A-Za-z0-9_]+|ghp_[A-Za-z0-9]+|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]+|sk-[A-Za-z0-9]{20,})' \
  PHASE_2_BACKLOG.md \
  docs/phase-2-to-be/0{3,4,5,6}-*.md \
  docs/diagrams/to-be-trust-boundaries.mmd \
  docs/evidence/phase-2/T01-service-objectives-and-threat-model.md
```

Le scan de secret cible les fichiers de mission avec des signatures fortes de
clés privées, credentials OpenStack et tokens courants. Une sortie vide avec
le code `1` de `rg` signifie qu'aucun motif n'a été trouvé.

## Résultats observés

- `git diff --check` : succès ;
- lignes de constats dans la matrice : 22 ;
- identifiants M16 uniques dans la matrice : 22 ;
- constats attendus absents : aucun ;
- exigences définies absentes de la matrice : aucune ;
- exigences : 11 service + 10 data + 12 sécurité = 33 ;
- scan de secret : aucune correspondance ;
- rendu Mermaid SVG/PNG : succès ;
- inspection visuelle : acteurs, projets, namespaces, data, livraison,
  observabilité et sauvegarde restent distinguables.

L'inspection locale a également trouvé 39 objets dans le state Terraform. La
variable `OS_AUTH_URL` n'est pas présente dans l'environnement Codex : ce
nombre décrit le state local, pas l'état live OpenStack, qui sera réinventorié
avec les credentials utilisateur en T02.

## Tests non exécutés

Aucun test SLO sur 30 jours, test de charge, refus OIDC, panne, restauration ou
rollback runtime n'est exécuté en T01 : les contrôles n'existent pas encore et
leur implémentation appartient à T04-T17. Aucun appel OpenStack authentifié
n'est nécessaire ; l'inventaire live des deux projets est précisément T02.

## Impact, backup, rollback et critères d'arrêt

- ajout : cinq documents/diagrammes de spécification et cette preuve ;
- modification : statut et livrables T01 dans le backlog ;
- remplacement/destruction : aucun ;
- backup runtime : non applicable, aucune ressource ni donnée modifiée ;
- rollback documentaire : revert du commit T01 ;
- arrêt : toute valeur contradictoire avec un contrat ou une capacité vérifiée
  doit rester candidate et être corrigée avant T03.

Les modifications locales AS-IS préexistantes restent hors du commit T01.

## Limites et dettes restantes

- aucune validation métier réelle des hypothèses candidates ;
- aucun historique de trafic permettant de prouver les percentiles ;
- aucune capacité de stockage, réplication ou domaine de panne réinventoriée ;
- les propriétaires sont des rôles, pas des personnes nommées ;
- les valeurs de conservation doivent être approuvées selon coût et obligations
  réelles.

## Conclusion et prochaine mission

T01 fournit une base testable pour comparer les décisions T03 et mesurer T18.
La prochaine mission autorisée est **T02 — réinventorier les deux projets
OpenStack**, sans attribuer leur rôle avant les résultats de l'inventaire.
