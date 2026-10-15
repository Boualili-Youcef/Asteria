# Rejouer la démonstration

Le [parcours court](README.md) suffit pour une présentation. Ce guide sert
à l'opérateur authentifié. Le cluster est privé ; le site n'administre rien.

## Vérifier les sources sans cloud

```bash
bash demo/scripts/test-offline.sh
# Node 22.22+ et npm requis pour la console React :
cd demo/web
npm ci
npm run build
npm run preview
# http://127.0.0.1:4175/Asteria/
```

Export vers un dossier neuf, depuis la racine du dépôt :

```bash
python3 demo/web/build.py --output /tmp/asteria-site-preview
```

Le répertoire de sortie doit être neuf ou vide. Arrêter le preview par Ctrl+C.
La console remplace l’ancien bundle de quatre fichiers : seuls HTML, JS, CSS,
SVG, polices et licences sont exportés, avec les preuves filtrées compilées.
Le préfixe `/Asteria/` est obligatoire. Voir le
[guide de la console](web/README.md) pour tests, publication et contrat de données.

## Préparer l'accès privé

Activer le VPN pour les opérations infra. Vérifier le projet source, les UID
`kube-system` et `asteria-demo`, les nœuds et la capacité :

```bash
python3 demo/scripts/preflight.py --read-source
# Dans le terminal où seul l'OpenRC source a été chargé :
python3 demo/scripts/openstack-read.py
```

Utiliser **Helm 3.19.0**, la version stable validée. Helm 4 sur le bastion ne
convient pas à cette procédure. Si nécessaire, télécharger l'archive officielle
et son checksum depuis `https://get.helm.sh/helm-v3.19.0-linux-amd64.tar.gz`,
vérifier le SHA-256 puis utiliser ce binaire dans le PATH du poste opérateur.

Préparer hors Git un kubeconfig pour `demo-promoter` avec token de 30 minutes,
CA vérifiée et tunnel SSH limité à la boucle locale. Le bootstrap requiert
initialement l'accès d'administration source ; les promotions utilisent ensuite
le rôle borné dans `asteria-demo`. Aucun token CI ni kubeconfig administrateur
ne doit être copié dans le dépôt ou le runner.

Renseigner uniquement dans cette session les variables `DEMO_CONTEXT`,
`DEMO_CLUSTER_UID`, `DEMO_NAMESPACE_UID` et `DEMO_EVIDENCE_DIR` (répertoire privé).
Les UID doivent correspondre à la référence source contrôlée ; ne pas les
choisir seulement parce que le nom du contexte semble correct.

## Promouvoir, vérifier, revenir en arrière

L'artefact conservé est celui de l'image réellement exécutée. Pour une nouvelle
version, télécharger l'artefact de son run CI réussi ; ne pas éditer son digest.

```bash
python3 demo/scripts/promote.py demo/evidence/orders-release.json \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID"

python3 demo/scripts/promote.py demo/evidence/orders-release.json \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID" --execute \
  --evidence "$DEMO_EVIDENCE_DIR/promotion.jsonl"

apps/.venv/bin/python demo/scripts/kubernetes-e2e.py demo/evidence/orders-release.json \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID" --execute \
  --output "$DEMO_EVIDENCE_DIR/business.json"

python3 demo/scripts/promote.py demo/evidence/orders-release.json \
  --context "$DEMO_CONTEXT" --cluster-uid "$DEMO_CLUSTER_UID" \
  --namespace-uid "$DEMO_NAMESPACE_UID" --failure-drill --execute \
  --evidence "$DEMO_EVIDENCE_DIR/failure.jsonl"
```

Sans `--execute`, la promotion ne modifie rien. Les sorties sont nouvelles et
privées ; elles ne sont jamais écrasées. Le test métier écrit une seule commande
synthétique dans la base `demo`, puis vérifie son archive et les métriques.
Après le rollback, répéter ce test avec un nouveau fichier de preuve.

Le drill remplace uniquement la readiness de la nouvelle révision. Attendre
le timeout de 180 s ; le résultat requis est `failed_then_rolled_back`, avec
image précédente, rollout et probes vérifiés. Ce n'est pas une panne destructive.
Pour un diagnostic privé, définir `ASTERIA_OPERATOR_LOG` vers un fichier hors
Git en 0600 ; aucun message CLI brut n'est publié par le script.

Rollback manuel si nécessaire, uniquement vers une révision saine relevée avant :

```bash
helm --kube-context "$DEMO_CONTEXT" -n asteria-demo rollback \
  orders-demo "$PREVIOUS_HELM_REVISION" --wait --timeout 180s
```

Vérifier ensuite les probes, le digest et le test métier ; le code retour Helm
seul ne suffit pas. Ne pas poursuivre si le rollback reste incertain.

## Installation initiale — seulement dans un namespace neuf

La démo est déjà installée. **Ne pas réinitialiser le namespace existant.**
Pour une reconstruction expressément autorisée, les sources sont le
[générateur](scripts/prepare-bootstrap.py) et le [socle](manifests/isolation.yaml).
Les données sont jetables, sans TLS interne pour cette adaptation de lab.

```bash
python3 demo/scripts/prepare-bootstrap.py --output /tmp/asteria-demo-bootstrap
# Après contrôle du projet, de l'UID source et de l'absence du namespace :
kubectl --context "$DEMO_ADMIN_CONTEXT" apply -f demo/manifests/isolation.yaml
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply \
  -f /tmp/asteria-demo-bootstrap/network.json
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply \
  -f /tmp/asteria-demo-bootstrap/runtime.json
```

Le bundle contient un mot de passe généré : répertoire 0700, fichiers 0600,
hors Git. Ne jamais le régénérer pour une base déjà initialisée. Il crée deux
Services ClusterIP et les trois dépendances synthétiques. Attendre leur rollout,
puis installer Orders avec l'identité bornée, Helm 3.19.0 et le même bundle :

```bash
helm --kube-context "$DEMO_CONTEXT" -n asteria-demo install orders-demo \
  k8s/current-state/orders-api/chart -f demo/values.yaml \
  -f /tmp/asteria-demo-bootstrap/release-values.json --atomic --wait --timeout 180s
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply \
  -f /tmp/asteria-demo-bootstrap/network-probes.json
```

Exiger le succès des Pods `demo-network-allowed` et `demo-network-denied`
avant une commande métier. Contrôler aussi le refus inter-namespaces, sans
modifier les workloads historiques. Le worker doit avoir l'ID de cache vérifié
sur les deux workers : `sha256:adda677a5cd48ae49d3a4c17f765c83a344d9844dedb79dfe6e23c3741fcd80a`.

Le budget des quatre services est 80m CPU / 288 MiB demandés, 1 CPU / 864 MiB
limités ; le quota conserve de la marge pour le rollout et les probes.
Aucun PVC, Ingress, NodePort ou nouvelle VM. Arrêter si capacité, réseau,
identité ou droits sont incertains. Aucune suppression de namespace automatique.

Après validation, retirer les seuls Pods de test, fermer le tunnel et retirer
le fichier du token temporaire. Conserver le bundle de données en privé.
La suppression des services et de leurs données temporaires reste une
opération séparée ; ne jamais nettoyer un namespace historique.
