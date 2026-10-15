# Asteria Platform Console — livraison et validation locales

- Date : 15 octobre 2026
- Périmètre : extension Demo v1, présentation statique et playground Docker opt-in
- Départ : branche `main`, commit `6086e97`
- Décision : [ADR-016](../../adr/ADR-016-platform-console-static.md)
- Publication distante : **non exécutée** ; aucun commit ni push effectué
- Cloud : **aucune connexion ou mutation OpenStack/Kubernetes**

## But et résultat mesurable

Livrer une console publique exploitable sans VPN, qui permette d’explorer
l’architecture, suivre une release vérifiée, rejouer trois incidents, comprendre
les services et remonter aux 22 constats M16. Livrer ensuite un laboratoire
local créant et archivant de vraies commandes synthétiques.

Résultat observé : sept vues, visite guidée en cinq étapes, graphe sélectionnable
avec clavier et liste mobile, replays contrôlables, catalogue et audit filtrable.
39 tests unitaires frontend et 14 tests navigateur passent. Le playground
crée, relit et retrouve les événements correspondants dans PostgreSQL.
La compréhension en 20 secondes et la durée de visite inférieure à trois minutes
restent des objectifs éditoriaux ; aucune étude utilisateur chronométrée n’a été menée.

## Traçabilité et dépendances

- REQ-SVC-008 / REQ-SEC-007, ASIS-012 à ASIS-015 : traçabilité de livraison.
- REQ-DATA-009 / REQ-SEC-003, ASIS-004/009/010 : frontières, données et risques.
- REQ-SVC-009 / REQ-DATA-010, ASIS-016/017/022 : diagnostic et retour arrière.
- ADR-015 reste la référence de la démo source. T08–T18 restent à faire ; aucun
  constat global n’est clôturé par cette mission de présentation.

Les documents AS-IS, les applications, `promote.py`, `orders-demo.yml` et les
preuves archivées du 14 octobre n’ont pas été modifiés. Le fichier préexistant
non suivi `docs/phase-1-as-is/06-synthese-m00-m09.md` est préservé.

## Faits vérifiés

- La release enregistrée associe le commit `27383ed72497a782c5cd3b3b4f62a2b20ebe812a`,
  le run `38622409565` et un digest retrouvé dans les imageID de la promotion.
- Le manifeste exige une promotion réussie, un rollback réussi, les contrôles
  métier correspondants et la préservation des images/données historiques.
- Les événements du drill sont conservés : `0`, `192.208`, `192.208`, `209.504`
  secondes. La durée totale `209.505` est distincte du dernier événement.
- Le registre M16 est extrait du Markdown canonique : 22 constats,
  dont 3 d’impact moyen ; aucun taux de remédiation n’est inventé.
- Le source est représenté avec Flannel ; Cilium/Hubble sont historiques sur
  staging inaccessible. Les ADR ne sont pas des preuves de déploiement.
- Le bundle public contient 17 fichiers autorisés, sans JSON interne brut.
  Les polices WOFF2 et leurs licences sont locales. Les parcours publics testés
  ne font aucune requête externe, ni appel cloud.
- Le playground publie seulement le BFF sur `127.0.0.1:4180`. Il utilise Orders
  au digest CI enregistré, le vrai worker, PostgreSQL et Redis. Le BFF dispose
  d’un rôle SQL de lecture distinct, sans socket Docker ni commande shell.

## Hypothèses et limites de validation

- Les paramètres GitHub Pages actuels n’ont pas été inspectés ou modifiés.
  Le YAML est contrôlé localement ; aucun nouveau workflow distant n’est exécuté.
- Les tests utilisent Chrome Linux, avec viewport desktop et émulation iPhone 13.
  Ils ne constituent pas des tests sur Safari/iPhone physique ou une certification WCAG.
- Le présent contrôle ne réinterroge jamais le cluster. Les états du 14 octobre
  restent des observations historiques, et non l’état courant des VM.
- Aucun test de performance, HA, DR, restauration de données ou SLO n’est ajouté.

## Décisions, cible entreprise et adaptation lab

React/TypeScript/Vite et XYFlow remplacent le site sans framework. Le maintien
en JavaScript simple a été écarté pour la complexité du graphe, des URLs et des
interactions testables. Un backend public et un runner administrateur sont exclus.
Les métadonnées explicites et la sélection de champs sont préférées à la copie
des rapports. Les sources sont typées par `recorded`, `historical`, `proposal`
et `pedagogical` ; les limites sont rendues visibles dans chaque parcours.

La cible entreprise reste celle de T03. Le playground n’en est pas une nouvelle
implémentation : c’est un laboratoire Docker jetable. Le réseau data est interne ;
le seul BFF rejoint aussi un bridge de publication localhost. Aucun produit
supplémentaire n’est installé dans l’infrastructure privée.

## Fichiers livrés et impact

- `demo/web/src/` : shell, composants communs, graphe et cinq modules de vues,
  CSS, schéma et manifeste public versionné.
- `demo/web/scripts/` : ingestion, métadonnées de topologie et audit strict du bundle.
- `demo/web/tests/` : contrat des preuves, confidentialité, interactions, E2E/WCAG.
- `demo/web/package*.json`, configurations TypeScript/Vite/Playwright/ESLint,
  `public/` : dépendances verrouillées, favicon, polices et licences.
- `demo/web/build.py` : point d’export compatible, refus d’écrasement conservé.
  L’ancien `app.js` et `style.css` sont remplacés par les modules React.
- `.github/workflows/demo-site.yml` : installation, tests, build filtré,
  contrôles navigateur et artefacts ; publication limitée à `main`, PR sans deploy.
- `demo/playground/` : Compose, initialisation des rôles, BFF, UI, démarrage et tests.
- `demo/tests/test_site_export.py` : trois refus d’export dangereux.
- README, runbook, ADR-016 et cette preuve : exploitation et périmètre.

Ajouts runtime : cinq conteneurs et deux réseaux Compose locaux, un volume
synthétique et un `.env` privé généré. Aucun ajout, remplacement ou destruction
sur OpenStack/K3s ; aucune migration de données historiques.

## Commandes de vérification dans l’ordre

Node 22.22.0 et npm ont été utilisés pour les checks. Le Node système initial
était 18 et npm n’était pas dans le PATH du shell d’agent. Node 22 a été préparé
dans `/tmp`, sans installation système ; le Node 24.13.1 déjà présent via mise
a servi à contourner une erreur interne du npm 10 lors d’une mise à jour.
`npm ci` fonctionne ensuite avec le lockfile livré.

Depuis la racine, avec Node 22.22+ et npm dans le PATH :

```bash
cd demo/web
npm ci --no-fund --no-audit
npm run ingest
npm run typecheck
npm run lint
npm test
npm run build
npm run test:e2e
npm audit --json
cd ../..
bash demo/scripts/test-offline.sh
python3 demo/web/build.py --output /tmp/asteria-console-delivery/Asteria
bash demo/playground/start.sh
python3 demo/playground/test_integration.py
node demo/playground/test-ui.mjs
bash -n demo/playground/start.sh demo/playground/init-db.sh
node --check demo/playground/web/app.js
python3 -m py_compile demo/playground/server.py demo/playground/test_integration.py demo/web/build.py
```

Les corrections ont été suivies de nouveaux passages pertinents. Ne pas réutiliser
un dossier d’export non vide. Les commandes d’exploitation courantes se trouvent
dans [le guide frontend](../../../demo/web/README.md) et
[le guide Docker](../../../demo/playground/README.md).

## Résultats observés

| Contrôle réellement exécuté | Résultat |
|---|---|
| Installation `npm ci` | réussie |
| Typecheck strict / lint | réussis |
| Vitest | 39/39 |
| Playwright public | 14/14, desktop et mobile |
| axe WCAG 2 A/AA et 2.1 AA | zéro violation détectée sur les sept vues, aux deux largeurs |
| Navigation et graphe | URLs, retour arrière, sélection clavier nœuds/flux, fermeture et mode liste passent |
| Replay / catalogue / audit | scan, étapes, pause, comparaison, probes, flux et filtres passent |
| Console / réseau / overflow | zéro erreur console observée, zéro requête externe et zéro débordement horizontal dans les parcours publics |
| Références de dépôt | liens `blob/main` des vues testées vers fichiers existants ; commit de release présent dans Git |
| Bundle / export Python | 17 fichiers explicitement autorisés, assets `/Asteria/` résolus |
| Audit npm final | zéro vulnérabilité signalée à la date du contrôle |
| Applications historiques | 5 Identity + 9 Orders + 6 Worker = 20 tests réussis |
| Garde-fous Python demo | 16 tests réussis, dont trois nouveaux refus d’export |
| Helm | chart lint réussi, aucun appel au cluster |
| Playground intégration | deux commandes, deux archives SQL correspondantes, Redis arrêté puis rétabli |
| Sécurité locale | Origin étrangère refusée, rôle reader incapable d’écrire, aucun port data publié |
| Playground UI | desktop et mobile : création/lecture/archive, axe, absence d’erreur JS et d’overflow réussies |
| Rollback statique | ancien bundle de quatre fichiers rebâti depuis une archive de `6086e97`, sans mutation Git |

Les dépendances de test signalent des avertissements de dépréciation ESLint 9,
whatwg-encoding et Starlette/httpx. Ils n’ont pas fait échouer les tests et ne
sont pas assimilés à des résultats d’exécution en production.

## Preuves et captures

- [Synthèse des checks locaux](platform-console/validation-summary.json) : résumé
  rédigé à partir des résultats observés, pas une attestation signée.
- [Sortie réelle du test d’intégration Docker](platform-console/playground-integration.json).
- [Lecture finale locale](platform-console/playground-final-observation.json) : huit
  commandes et huit archives au terme des tests et itérations UI ; les deux commandes
  du test d’intégration sont un sous-ensemble de ce jeu synthétique.
- [16 captures réelles](platform-console/screenshots/) : sept vues publiques × deux
  largeurs, puis playground desktop/mobile. Inspection visuelle effectuée sur
  Overview, Architecture, Delivery, Incident, Services, Engineering, Proofs et local.

## Écarts corrigés et critères d’arrêt

Les premiers contrôles ont révélé la sélection Enter sans ouverture du détail,
des labels de filtre ambigus, un contraste de repère insuffisant et des liens
distingués uniquement par la couleur : corrigés puis retestés. L’audit npm initial
a conduit à des mises à jour Vite/Vitest/typescript-eslint et à un audit final nul.
La réorganisation des vues a révélé des imports manquants, corrigés avant livraison.

Compose a d’abord refusé un Dockerfile hors contexte : Orders utilise désormais
le digest réel de la release. Un réseau exclusivement internal ne publiait pas le
BFF : un bridge de publication a été ajouté au seul BFF. La liste d’archives
défilante a reçu son focus clavier après détection par axe.

Arrêter en cas de manifeste incohérent, export sensible, rollback non vérifié,
conflit de port local ou besoin d’accès cloud. Aucun faux succès ou panneau de
télémétrie de remplacement n’est introduit.

## Sauvegarde, rollback et arrêt local

Le commit initial conserve le site précédent. Son export a été rebâti depuis
`git archive HEAD demo/web demo/evidence` dans un répertoire temporaire, puis
contrôlé : quatre fichiers, mode `dated-evidence-not-live`. Aucun rollback de
publication distante n’est revendiqué puisqu’aucune publication n’a eu lieu.

Le playground est arrêté par `docker compose down` dans son propre dossier :
seuls ses conteneurs et réseaux sont retirés. Le volume et `.env` restent locaux
pour permettre le redémarrage. Aucun prune global ni suppression de volume exécuté.
Les données sont jetables, sans promesse de backup ou restauration. Pour effacer
volontairement CE volume, la procédure distincte est documentée dans son README.

## Dettes et prochaine action autorisée

Le site conserve les limites du lab : pas de HA/DR, GitOps achevé, SLO de production,
TLS data de démo ou signature vérifiée à l’admission. Outbox, ACK durable et DLQ
restent absents. Le playground ne dispose pas d’authentification et doit rester
strictement sur localhost. Aucun reset/chaos depuis le navigateur.

La prochaine action est la revue puis le commit/push et la publication Pages par
le propriétaire, explicitement hors exécution de cette mission. Les missions
infrastructure suivent toujours le backlog et exigent leur requalification avant
reprise ; aucune permission cloud n’est déduite de cette livraison.
