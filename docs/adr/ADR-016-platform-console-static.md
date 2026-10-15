# ADR-016 — Console publique statique fondée sur les preuves

- Statut : accepté pour l’implémentation locale, sans publication distante
- Date : 2026-10-15
- Propriétaire : Youcef Boualili
- Portée : extension de présentation Demo v1 ; aucune mission T08–T18 clôturée

## Problème et contraintes

Rendre le lab compréhensible puis auditable depuis un seul site public, sans
VPN, accès cluster ou télémétrie inventée. L’ancien site présentait surtout
la livraison ; il ne permettait pas d’explorer les frontières et les 22 constats.

Traçabilité : REQ-SVC-008 / REQ-SEC-007 et ASIS-012–015 pour la livraison ;
REQ-DATA-009 / REQ-SEC-003 et ASIS-004/009/010 pour les limites applicatives et
l’isolation ; REQ-SVC-009 / REQ-DATA-010 et ASIS-016/017/022 pour le diagnostic.
La console expose les résultats disponibles, elle ne remédie pas ces constats.

## Décision et alternatives

React / TypeScript strict / Vite, graphe XYFlow et composants natifs accessibles.
Conserver Python comme point d’export compatible, en remplaçant explicitement
la contrainte technique des quatre fichiers par une allowlist d’extensions.
Un manifeste public strict Zod est construit à partir des JSON canoniques et
de métadonnées sourcées. Chaque champ publiable est sélectionné ; aucune copie
automatique du dépôt ou des JSON bruts n’est autorisée.

L’alternative sans framework réduisait les dépendances, mais rendait plus
fragiles le graphe, les interactions partageables et les tests. Un backend
cloud public, une authentification et un portail d’administration sont exclus.
Une image statique seule ne satisfait pas l’exploration demandée.

## Référence entreprise et adaptation lab

La référence entreprise reste celle des ADR T03. La console montre un lab
source Flannel, sa démo isolée, les expériences historiques T06/T07 et les
propositions T08–T18 avec des labels distincts. Les ADR ne prouvent aucun
déploiement. Aucun taux global de remédiation, HA, DR ou SLO n’est calculé.

Le playground expérimental est un second produit, opt-in sur localhost :
Orders au digest de la release, worker réel, PostgreSQL et Redis sous Compose.
Le BFF possède une identité SQL de lecture distincte et des upstreams fixes,
sans accès Docker ni shell. Aucun reset/chaos n’est exposé dans le navigateur.
Il est exclu du bundle Pages ; son arrêt ne touche que son projet Compose.

## Sécurité, validation et retour arrière

Les incohérences de commit/run/digest, rollback, archive et préservation
historique bloquent le build. Tests unitaires négatifs, audit du bundle,
tests UI desktop/mobile et liens locaux contrôlent la livraison. La publication
reste GitHub Pages, `/Asteria/`, avec permissions minimales. Aucun credential
cluster n’est nécessaire dans le runner. Les polices sont hébergées localement.

L’impact est limité à la présentation, son workflow et ses documents. Ni les
applications, ni promote.py, ni orders-demo.yml, ni les preuves archivées ne
sont modifiés. Rollback : revenir au commit antérieur de ces seuls fichiers,
rebâtir puis publier volontairement via Pages. Aucun rollback cloud requis.
Arrêt si une preuve devient incohérente, si des données sensibles apparaissent
dans le bundle ou si le périmètre exige une mutation du runtime privé.

La preuve de mission est
[Platform-console-local-delivery.md](../evidence/phase-2/Platform-console-local-delivery.md).
