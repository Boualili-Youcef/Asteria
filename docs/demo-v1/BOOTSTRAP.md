# Installation initiale isolée — périmètre à approuver

But : initialiser une release saine `orders-demo` pour pouvoir mesurer ensuite
une promotion et un rollback réels. Cette procédure prépare une extension du
cluster source ; elle ne migre aucune application historique. Rattachement :
ADR-015, ASIS-004/009/012/015/020/022 et REQ-SEC-003, REQ-SVC-008/009/011.

## État vérifié et limites

Le 14 octobre 2026, le cluster source compte trois nœuds Ready. Le namespace
`asteria-demo` n'existe pas. Les deux workers peuvent lire anonymement le
manifeste OCI du digest Orders validé (HTTP 200 et digest identique). Le pull
complet sur le poste a réussi. Les workers disposent respectivement d'environ
14,2 et 13,1 Go libres. Le control plane porte un taint NoSchedule ; aucun
workload proposé ne le tolère. Les options lues ne désactivent pas le
contrôleur NetworkPolicy K3s ; son efficacité reste à mesurer par les probes.

Hypothèses à valider avant succès : pulls complets depuis les workers,
admission PSA, scheduling réel, réseau, probes et parcours métier. Les quotas
Nova confirmés précédemment ne réservent pas de capacité Kubernetes.

## Ajouts et impact

- Un namespace, ResourceQuota, LimitRange et huit NetworkPolicies.
- Quatre Deployments : Orders, worker, PostgreSQL et Redis de démo.
- Trois Services ClusterIP, un ConfigMap et un Secret PostgreSQL synthétique ;
  les Secrets de révisions Helm restent dans ce namespace.
- Deux ServiceAccounts sans montage automatique de token ; rôle et bindings
  de promotion limités au namespace. Un ClusterRole permet uniquement `get`
  sur les namespaces `kube-system` et `asteria-demo`.
- Deux Pods de contrôle temporaires, sans droits API : client autorisé et
  client refusé. Leur sortie contient uniquement le résultat du contrôle.

Les quatre services demandent au total **80m CPU et 288 MiB RAM**, avec limites
de **1 CPU et 864 MiB RAM**. Le quota borne le namespace à 500m/768Mi demandés,
2 CPU/2Gi de limites et huit Pods, y compris les probes et le surge Orders.
PostgreSQL utilise un `emptyDir` de 512Mi ; aucune VM, PVC, adresse publique,
modification Terraform ou écriture dans les données historiques.

Les données sont jetables : la disparition du Pod PostgreSQL peut les perdre.
Le retour à une version Orders antérieure conserve le Pod de données mais ne
prouve aucune restauration de base ni RPO/RTO d'entreprise. Aucune donnée
utilisateur ne doit entrer dans cette base.

Écart lab à approuver explicitement avant activation : les clients applicatifs
existants utilisent ici PostgreSQL et Redis sans TLS interne. Les
NetworkPolicies limitent les sources et destinations, mais ne chiffrent pas
les flux. Cette proposition ne satisfait donc pas la règle générale de
chiffrement des flux data d'AGENTS.md. Elle ne peut être acceptée que pour ces
données factices jetables, sans credential ni donnée historique réutilisés.
Sans cet accord d'exception, arrêter le bootstrap et préparer une variante TLS.
La cible entreprise conserve chiffrement et validation d'identité des serveurs.

Orders, PostgreSQL et Redis sont épinglés par digest. Le worker réutilise le
cache M13 des deux workers, avec `imagePullPolicy: Never`. Vérifier avant installation l'ID commun observé sur les deux workers :
`sha256:adda677a5cd48ae49d3a4c17f765c83a344d9844dedb79dfe6e23c3741fcd80a`.
Cet ID diffère de l'image locale ; les fichiers Python et requirements du
worker historique ont en revanche été comparés au dépôt avec succès.
Ce compromis évite de refondre sa livraison, mais ne fournit pas un worker
reproductible depuis un registre public. Il reste une dette explicite.

## Préparation locale sans accès cluster

Les commandes suivantes ne créent rien dans Kubernetes :

```bash
python3 demo/scripts/prepare-bootstrap.py --output /tmp/asteria-demo-bootstrap
helm template orders-demo k8s/current-state/orders-api/chart \
  --namespace asteria-demo -f demo/values.yaml \
  -f /tmp/asteria-demo-bootstrap/release-values.json
```

Le générateur refuse un répertoire existant et toute sortie dans le dépôt.
Le répertoire est privé (0700), ses fichiers sont en 0600. `runtime.json`
contient le mot de passe aléatoire : ne pas afficher, committer ou publier ce
fichier. Le rendu Helm ci-dessus ne contient que des références au Secret.

## Ordre d'activation après accord explicite

Exécuter via le canal privé avec un contexte administrateur source choisi
explicitement. Vérifier son UID `kube-system` contre la référence privée
relevée pendant le préflight ; arrêter si le namespace existe déjà ou si le
projet est ambigu. Vérifier les IDs du worker et la marge réelle des nœuds.

Les variables `DEMO_ADMIN_CONTEXT`, `DEMO_BUNDLE` et les UID restent locales.
`DEMO_BUNDLE` désigne le répertoire privé généré, jamais un dossier Git.

```bash
kubectl --context "$DEMO_ADMIN_CONTEXT" get namespace kube-system \
  -o jsonpath='{.metadata.uid}'
kubectl --context "$DEMO_ADMIN_CONTEXT" get namespace asteria-demo
# Continuer seulement si la seconde lecture retourne NotFound et si l'UID est vérifié.
kubectl --context "$DEMO_ADMIN_CONTEXT" apply -f demo/manifests/isolation.yaml
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply -f "$DEMO_BUNDLE/network.json"
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply -f "$DEMO_BUNDLE/runtime.json"
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo rollout status \
  deployment/demo-postgres --timeout=180s
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo rollout status \
  deployment/demo-redis --timeout=180s
helm --kube-context "$DEMO_ADMIN_CONTEXT" -n asteria-demo install orders-demo \
  k8s/current-state/orders-api/chart -f demo/values.yaml \
  -f "$DEMO_BUNDLE/release-values.json" --atomic --wait --timeout 180s
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo rollout status \
  deployment/demo-notifications --timeout=180s
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo apply \
  -f "$DEMO_BUNDLE/network-probes.json"
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo wait \
  --for=jsonpath='{.status.phase}'=Succeeded pod/demo-network-allowed --timeout=60s
kubectl --context "$DEMO_ADMIN_CONTEXT" -n asteria-demo wait \
  --for=jsonpath='{.status.phase}'=Succeeded pod/demo-network-denied --timeout=60s
```

Le script d'installation initiale a besoin des droits de bootstrap. La suite
utilise une identité `demo-promoter` à token court (30 minutes), stockée dans
un kubeconfig privé hors Git et un tunnel SSH sur la boucle locale. Ne pas
transférer le kubeconfig administrateur ou le token GitHub vers la CI.

Vérifier les refus avec cette identité : pas d'accès aux Secrets historiques,
pas de création de namespace, pas de modification de nœud. Vérifier aussi les
succès nécessaires au chart : Deployments, Services, ConfigMaps, Secrets de
démo et port-forward. Le rôle peut supprimer ces trois dernières sortes
d'objets dans le namespace pour le nettoyage de révisions Helm ; ce n'est pas
une identité applicative.

Les probes préparées testent les clients autorisé/refusé du namespace.
Elles ne prouvent pas à elles seules un refus inter-namespaces. Compléter ce
contrôle sans créer de Pod ni modifier de policy dans les namespaces historiques.

## Validation, rollback et arrêt

Avant toute promotion : vérifier les quatre Deployments, `/health`, `/ready`,
`/metrics`, le digest demandé et les imageID. Créer une commande synthétique,
la relire et vérifier dans cette seule base l'archive du même `order_id`.
Relever ressources, compteurs et état des workloads historiques avant/après.

Le [runbook](DEMO-5-MINUTES.md) porte la promotion et l'échec readiness contrôlé.
L'exercice ne touche qu'à la nouvelle révision Orders ; il doit revenir à la
révision saine avec probes et parcours métier revérifiés. L'accès privilégié
initial ne doit pas servir à contourner les refus de l'identité de promotion.

Arrêter si les refus réseau ou RBAC échouent, si un workload historique se
dégrade, si la capacité est insuffisante ou si le rollback reste incertain.
Un échec du bootstrap ne justifie aucune destruction de namespace automatique.
Conserver ses preuves privées, couper le tunnel et attendre le diagnostic.
La désinstallation des seules ressources Demo sera une opération séparée,
avec accord dédié ; aucune suppression de données historiques n'est prévue.

La préparation peut être répétée dans un nouveau répertoire ; elle génère un
nouveau secret. Ne jamais réappliquer un bundle régénéré sur une base déjà
initialisée : le mot de passe du Secret et celui de PostgreSQL divergeraient.
Après succès, conserver le bundle privé de cette installation pour sa durée
de vie. Une restauration n'est pas annoncée : seules des données jetables sont utilisées.
