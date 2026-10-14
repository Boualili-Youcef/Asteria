# Registre des preuves Demo v1

Date de session : **2026-10-14**. Référence initiale du dépôt : `fe8596b`.
Les commits de la branche identifient les fichiers livrés ; aucune version
Demo CI ni aucun digest déployé sur K3s n'est annoncé sans résultat observable.

| Affirmation | Environnement / méthode | Résultat et portée |
|---|---|---|
| Cinq VM attendues dans le state source | lecture JSON locale, sans refresh | confirmé comme contenu local, pas comme inventaire Nova actuel |
| Source K3s sain à la lecture | SSH bastion ; kubectl get nodes/deployments, 14 octobre vers 15:38 UTC | 3/3 Ready, K3s v1.36.2+k3s1 ; APIs, Worker, Redis, Prometheus/Grafana disponibles |
| Image historique Orders encore exécutée | image du Deployment source | `docker.io/asteria/orders-api:m13`, aucun digest Demo observé |
| Ressources observées | metrics-server source | mémoire 951/650/1589 Mi lors du premier passage ; voir audit D0 pour CPU et bastion |
| Quotas actuels du projet source | OpenRC fourni, mot de passe non hérité par la session de travail | NON VÉRIFIÉ, aucune mutation cloud permise sur cette base |
| Intégrité des archives T04 locales | sha256sum --check --quiet, runtime et Terraform | deux catalogues valides ; aucune restauration démontrée |
| Baseline logicielle | venv existant, trois suites pytest | 5 Identity + 5 Orders + 6 Worker réussis avant ajouts |
| Validation des payloads et dette publication | trois tests Orders ajoutés | total applicatif : 19 réussis ; panne Redis après persistance produit 500 avec écriture déjà effectuée |
| Garde-fous de livraison | unittest + rendu Helm réel | six tests réussis, dont mauvais cluster, artefact invalide et rollback simulé ; pas une preuve de panne K3s |
| Compatibilité chart | helm lint et helm template | tag m13 par défaut ; image@digest sans suffixe tag en mode Demo ; digest incorrect refusé |
| Parcours métier Docker | script local-e2e.py, sources des images comparées au dépôt | PASS en 12,228 s à 16:31 UTC ; commande persistée/relue, événement archivé, Redis arrêté → ready 503/health 200, reprise et seconde archive, compteur worker 2, nettoyage PASS |
| CI, scan, SBOM/provenance | nouveau workflow orders-demo.yml | PRÉPARÉ ; run GitHub non exécuté à ce stade |
| Promotion / rollback K3s | promote.py, opérateur privé | NON EXÉCUTÉ ; bootstrap, autorisation et données isolées requis |
| Site statique | build allowlist, syntaxe JS, HTTP local | build local ; contrôle visuel navigateur indisponible dans la session |

## Commandes exécutées et reproduction

```bash
git status --short
git log -5 --oneline
# Puis lecture du contexte, backlog, constats M16, ADR et sources.

# Lecture source uniquement, via la clé locale existante :
python3 demo/scripts/preflight.py --read-source

# Suites existantes puis gardes et chart :
bash demo/scripts/test-offline.sh

python3 demo/web/build.py --output /tmp/asteria-demo-site
node --check demo/web/app.js
python3 -m http.server 4175 --bind 127.0.0.1 --directory /tmp/asteria-demo-site
```

L'utilisation directe des ClusterIP depuis le bastion n'a pas abouti ; ces
adresses ne doivent pas être présumées routables hors cluster. Les contrôles
complémentaires avec port-forward ont été interrompus par la coupure du VPN.
La readiness métier actuelle et les compteurs Prometheus restent donc non
vérifiés ; la disponibilité des Deployments ne les remplace pas.

Les catalogues SHA-256 T04 privés ont été vérifiés en lecture sans publier
state, dumps, clés, IP ni endpoints. Les actions CI ont été résolues depuis les
référentiels officiels puis figées par SHA. Références techniques utilisées :
[Helm 3 upgrade](https://docs.helm.sh/docs/v3/helm/helm_upgrade/) et
[attestations Docker](https://docs.docker.com/build/ci/github-actions/attestations/).

Le premier test Docker a échoué à l'étape de mapping des ports API sur un
réseau `--internal` ; son nettoyage a réussi. Le second utilise un bridge
dédié, les APIs liées à `127.0.0.1` et aucun port DB/Redis publié. Les deux
rapports restent disponibles : [tentative initiale](../../demo/evidence/local-e2e-20261014.json)
et [exécution réussie](../../demo/evidence/local-e2e-20261014-r2.json).
Les objets Kubernetes produits par les valeurs par défaut du chart modifié
ont été comparés au chart de `fe8596b` : ils sont sémantiquement identiques.
YAML, liens des nouveaux documents, motifs de credentials et `git diff --check`
passent ; `actionlint` 1.7.7 valide le nouveau workflow. Le navigateur de
contrôle n'est pas disponible ; aucune validation visuelle n'est revendiquée.

Reproduction du test local (Redis doit être déjà chargé ; l'ID d'image du
rapport peut être utilisé sur le même poste) :

```bash
python3 demo/scripts/local-e2e.py \
  --postgres-image postgres@sha256:0ea6700a3b4f0ae6ce746519073558aed4d88a79d8d07622a9a644946c7319c4 \
  --redis-image sha256:978f0e01593e65eed801f2402944efcd936d43b5027e4908a7897baf88ed6241 \
  --output /tmp/asteria-e2e-new.json
```

## Règle de publication

Seuls des résultats neutralisés et datés entrent dans `demo/evidence/`.
Les JSONL opérateur restent d'abord hors Git, en mode `0600`. Ils ne doivent
être publiés qu'après contrôle de leur contenu. Ne jamais archiver un kubeconfig,
un OpenRC, une sortie `kubectl get secrets`, un manifest Helm contenant un
Secret, une adresse privée ou un export brut de l'environnement.

Une durée non mesurée reste absente. Un test simulé est identifié comme tel.
Le site présente ces états ; il ne convertit pas un scénario préparé en replay.
