# Asteria Platform Console

Console publique **strictement statique** : React, TypeScript strict, Vite,
XYFlow, Lucide et CSS. Aucune connexion cloud, aucun backend public. Le chemin
de base est `/Asteria/`. Les mesures sont des observations du 14 octobre 2026,
jamais l’état courant du lab. Les simulations sont explicitement étiquetées.

## Développer et vérifier

Prérequis : Node 22.22+ et npm. Sur le poste de cette livraison, Node 24 est déjà
installé par mise ; si le shell sélectionne encore Node 18 sans npm :

```bash
export PATH="$HOME/.local/share/mise/installs/node/24.13.1/bin:$PATH"
```

Depuis la racine du dépôt :

```bash
cd demo/web
npm ci
npm run dev
# http://127.0.0.1:5173/Asteria/
```

```bash
cd demo/web
npm run ingest
npm run lint
npm test
npm run build
npm run test:e2e
npm run preview
# http://127.0.0.1:4175/Asteria/
```

Les tests E2E démarrent eux-mêmes le preview si nécessaire. Ils utilisent le
Chrome installé à `/usr/bin/google-chrome` ; ailleurs, définir `CHROME_BIN` vers
un exécutable Chromium/Chrome. `test-results/` contient captures desktop/mobile
et traces des échecs. Aucune commande de ce guide n’appelle le cloud.

Export compatible avec l’ancienne commande (dossier neuf ou vide) :

```bash
mkdir -p /tmp/asteria-console-preview
python3 demo/web/build.py --output /tmp/asteria-console-preview/Asteria
python3 -m http.server 4176 --bind 127.0.0.1 --directory /tmp/asteria-console-preview
# http://127.0.0.1:4176/Asteria/
```

L’export doit être neuf ou vide ; ne pas réutiliser un ancien dossier non vide.
Le préfixe public `/Asteria/` est obligatoire.

## Contrat de données

`scripts/ingest.ts` lit une liste explicite de fichiers JSON existants et le
registre M16. `src/schema.ts` valide le manifeste public strict ;
`src/generated/manifest.json` est versionné pour revue et régénéré avant chaque
build. Les champs inconnus des preuves internes ne sont jamais propagés.
Les métadonnées de topologie sont dans `scripts/topology.ts`, avec une source,
une limite, un périmètre et un type : recorded, historical, proposal ou pedagogical.

Le build exige : CI réussie cohérente avec commit/run/image, digest observé et
imageID concordants, rollback réellement réussi, archives correspondantes,
données synthétiques et images historiques inchangées. Un champ obligatoire
absent ou incohérent bloque le build, sans dégradation trompeuse en « vérifié ».
Les durées intermédiaires absentes restent non mesurées. `presentation.json`
est transformé en historique éditorial visible dans le registre ; ses anciens
statuts ne supplantent pas les observations CI/K3s postérieures.

`scripts/audit-dist.ts` refuse les extensions étrangères à l’allowlist, contrôle
les assets sous `/Asteria/` et recherche les contenus sensibles connus.
`dist/` ne contient pas de JSON brut ni de copie du dépôt. Aucun fichier de
preuve source n’est modifié. Les liens de release utilisent leur commit
immuable ; les liens d’exploitation pointent sur `main`.

## Parcours et accessibilité

Les vues sont partageables via `?view=architecture&layer=apps&node=demo-orders`,
`?view=delivery&step=7`, `?view=incidents&incident=redis&step=2` ou `?tour=1`.
Les étapes utilisent des index à partir de zéro. Le bouton Retour du navigateur
fonctionne entre vues et sélections. La lecture automatique est volontaire,
pausable, à cadence pédagogique ; elle ne reproduit pas les temps réels.

Le graphe offre pan/zoom/recentrage et un mode liste. Les détails et flux sont
accessibles au clavier. Les composants natifs (boutons, details, champs) ont
des labels et un focus visible. Aucun contenu n’exige le hover. Le CSS respecte
`prefers-reduced-motion`. La console reste utilisable avec les preuves cloud
indisponibles : elles sont compilées, jamais interrogées à distance.

## Publier volontairement

Après revue et commit/push effectués par le propriétaire, le workflow
`.github/workflows/demo-site.yml` construit et publie les changements de `main`.
Il peut aussi être lancé depuis **Actions → Asteria Platform Console → Run
workflow → main**. Les PR exécutent le build et les tests sans déployer.
URL attendue : https://boualili-youcef.github.io/Asteria/.
Configurer GitHub Pages sur « GitHub Actions » si cela ne l’est pas déjà.
Le job de build a seulement `contents: read` ; seul deploy a `pages: write`
et `id-token: write`. Aucun secret privé ni accès cluster n’est nécessaire.
Cette mission n’effectue aucun push ni déploiement distant.

## Présenter en cinq minutes

1. **0:00–0:40 — Overview** : le lab et le problème « publié ≠ exécuté ».
2. **0:40–1:40 — Architecture** : infrastructure, source Flannel puis namespace
   de démo et ses propres données ; sélectionner Orders ou un flux.
3. **1:40–2:50 — Delivery** : scan bloqué, digest accepté, run CI et imageID.
4. **2:50–4:00 — Incident Lab** : readiness invalide, événements enregistrés,
   rollback puis test métier ; comparer avant/après.
5. **4:00–5:00 — Décisions et preuves** : risque outbox/BLPOP, audit M16,
   source/staging/proposé ; ouvrir un JSON et expliquer une limite.

Les T08–T18, la HA, le DR, les SLO et la vérification de signatures à l’admission
ne sont pas livrés par la console. Les ADR restent des décisions de trajectoire.

Le [playground opt-in](../playground/README.md) est un produit Docker local séparé :
`bash demo/playground/start.sh`, depuis la racine, ouvre `127.0.0.1:4180`.
Il ne fait pas partie de `dist/` ni du déploiement Pages.
