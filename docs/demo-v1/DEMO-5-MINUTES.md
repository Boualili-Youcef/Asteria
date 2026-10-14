# Démonstration en cinq minutes

But : expliquer la différence entre une image publiée et une version réellement
exécutée, avec les tests et limites accessibles en quelques clics.

## Présentation autonome — disponible sans VPN

Ouvrir directement [le site publié](https://boualili-youcef.github.io/Asteria/).
Pour le reconstruire sur son propre poste :

1. Construire le site dans un répertoire neuf :

   ```bash
   DEMO_SITE_DIR="$(mktemp -d /tmp/asteria-demo-site.XXXXXX)"
   python3 demo/web/build.py --output "$DEMO_SITE_DIR"
   python3 -m http.server 4175 --bind 127.0.0.1 --directory "$DEMO_SITE_DIR"
   ```

2. Ouvrir `http://127.0.0.1:4175`. Aucun accès cloud ni credential n'est requis.
3. 00:00–00:45 : expliquer le contexte, les cinq VM historiques et les contraintes.
4. 00:45–01:45 : onglet Deploy, tests exécutés, CI réussie, digest et code du workflow.
5. 01:45–02:45 : montrer le contrôle du digest et de l'identité du cluster dans
   le script, en distinguant le code testé et l'exécution K3s non validée.
6. 02:45–03:45 : onglet Applications, replay du test Docker CI en 10,445 s ;
   expliquer la correspondance order_id et archive à partir de son JSON.
7. 03:45–05:00 : Reliability, refus testés, rollback simulé et validation live
   restante. Terminer sur les preuves et les limites.

Ce parcours est une présentation de preuves datées et du scénario préparé.
Ce n'est pas un replay d'un déploiement K3s réussi. Arrêter le serveur local par
Ctrl+C ; aucun nettoyage cloud n'est nécessaire.

## Mode live accompagné — préconditions obligatoires

### Accès au registre pour le portfolio

Choix retenu : téléchargement public de l'image Orders par digest, sans token
de registre sur le poste ni dans le cluster. L'accès cloud demeure privé.
Le 14 octobre 2026, le manifeste et son digest ont été vérifiés anonymement
depuis le poste et les deux workers ; le téléchargement complet sur le poste
a réussi. Les pulls de couches sur les workers restent à valider.

Le réglage effectué par le propriétaire : ouvrir [le package Orders](https://github.com/users/Boualili-Youcef/packages/container/package/asteria%2Forders-api),
puis **Package settings → Change visibility → Public**, et confirme le nom du
package demandé par GitHub. Ce réglage concerne toutes ses versions, y compris
les candidates refusées ; celles-ci restent exclues de toute promotion.
GitHub indique que le retour en privé n'est pas possible, voir
[la procédure officielle](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility#configuring-visibility-of-packages-for-your-personal-account).

Vérifier ensuite le digest retenu dans une configuration Docker temporaire
vide, sans utiliser les identifiants du poste :

```bash
python3 - <<'PY'
import json
from pathlib import Path
import subprocess
import tempfile

release = json.loads(Path('demo/evidence/orders-release.json').read_text())
image = release['image'] + '@' + release['digest']
with tempfile.TemporaryDirectory(prefix='asteria-anonymous-pull-') as config:
    subprocess.run(['docker', '--config', config, 'pull', image], check=True)
print('Téléchargement anonyme du digest validé : réussi')
PY
```

Ce contrôle télécharge seulement l'image sur le poste. Il ne prouve ni l'accès
Internet des workers ni un déploiement K3s ; ces vérifications restent requises
sur le canal privé avant le bootstrap autorisé.

Le recruteur n'obtient aucun accès privilégié. Avant toute activation, vérifier
le projet source, les ressources réelles, le namespace isolé, les backups et
l'autorisation du périmètre. Préparer hors Git un contexte opérateur borné,
les UID du cluster et du namespace et les credentials synthétiques. Ne pas
copier le kubeconfig administratif du bastion dans Git ou dans la CI.

### 1. Préflight de lecture

```bash
python3 demo/scripts/preflight.py --read-source
# Dans le terminal où seul l'OpenRC source a été chargé :
python3 demo/scripts/openstack-read.py
```

Ne pas publier les sorties d'autres commandes OpenStack ou des manifests bruts.
Si le cluster n'est pas joignable, afficher « live indisponible » et utiliser
la présentation autonome. Aucune reconstruction automatique.

### 2. Après une CI réussie et un bootstrap expressément approuvé

Le périmètre initial, ses manifests et les commandes sont dans le
[plan de bootstrap](BOOTSTRAP.md). Aucun composant de ce plan n’est encore installé.

Renseigner les variables locales depuis l'environnement autorisé. Elles sont
volontairement absentes du dépôt : `DEMO_CONTEXT`, `DEMO_CLUSTER_UID`,
`DEMO_NAMESPACE_UID`, `DEMO_RUN_ID`, `DEMO_EVIDENCE_DIR` (répertoire privé).

```bash
gh run download "$DEMO_RUN_ID" --repo Boualili-Youcef/Asteria \
  --name "orders-release-$DEMO_RUN_ID" --dir "$DEMO_EVIDENCE_DIR/release"

python3 demo/scripts/promote.py "$DEMO_EVIDENCE_DIR/release/release.json" \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID"
```

Ce premier passage ne modifie pas le cluster : vérifications de lecture et
rendu Helm local. Il exige déjà une release `orders-demo` saine, épinglée par
digest. Une installation initiale ne doit jamais être improvisée par `--install`.

### 3. Promotion après accord sur l'image et le périmètre

```bash
python3 demo/scripts/promote.py "$DEMO_EVIDENCE_DIR/release/release.json" \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID" --execute \
  --evidence "$DEMO_EVIDENCE_DIR/promotion.jsonl"
```

Le script vérifie le run GitHub, l'artefact, le namespace, la release précédente,
le rollout, l'image demandée et les imageID observés, `/health`, `/ready` et
`/metrics`. Un digest d'index OCI peut différer du digest plateforme de l'imageID :
les deux sont conservés dans la preuve privée. Le test métier cloud reste une
validation séparée sur données synthétiques autorisées.

### 4. Échec contrôlé après accord dédié

```bash
python3 demo/scripts/promote.py "$DEMO_EVIDENCE_DIR/release/release.json" \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID" --failure-drill --execute \
  --evidence "$DEMO_EVIDENCE_DIR/failure-drill.jsonl"
```

La nouvelle révision utilise une readiness inexistante ; l'ancienne reste
disponible selon la stratégie RollingUpdate (un replica, maxUnavailable arrondi
à zéro). Le timeout Helm est de 180 s : le scénario complet peut dépasser
cinq minutes. Une capture datée après exécution serait alors un vrai replay.
Le retour vérifié attend `failed_then_rolled_back`, l'image précédente, puis
des probes réussies. Un rollback incertain bloque toute démonstration live.

Rollback manuel, seulement avec la révision saine notée avant l'opération :

```bash
helm --kube-context "$DEMO_CONTEXT" -n asteria-demo rollback \
  orders-demo "$PREVIOUS_HELM_REVISION" --wait --timeout 180s
kubectl --context "$DEMO_CONTEXT" -n asteria-demo rollout status \
  deployment/orders-api --timeout=180s
```

Vérifier ensuite digest, probes et parcours synthétique. Ne pas déduire la
santé du seul code retour Helm. Aucune suppression distante automatique.
