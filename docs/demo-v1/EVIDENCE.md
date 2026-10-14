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
| Identité et quotas du projet source | script openstack-read.py, sortie transmise par le propriétaire | identité par token et cinq IDs concordants ; cinq VM ACTIVE, 5/8 instances, 9/10 vCPU, 17408/20480 MiB RAM |
| Intégrité des archives T04 locales | sha256sum --check --quiet, runtime et Terraform | deux catalogues valides ; aucune restauration démontrée |
| Baseline logicielle | venv existant, trois suites pytest | 5 Identity + 5 Orders + 6 Worker réussis avant ajouts |
| Validation, dette publication et readiness | quatre tests Orders ajoutés | total applicatif : 20 ; publication après persistance peut échouer ; readiness Redis en refus de connexion attendue sous 2 s |
| Garde-fous de livraison | unittest + rendu Helm réel | sept tests, dont mauvais cluster, artefact invalide, ancien workflow sans E2E et rollback simulé ; pas une preuve de panne K3s |
| Compatibilité chart | helm lint et helm template | tag m13 par défaut ; image@digest sans suffixe tag en mode Demo ; digest incorrect refusé |
| Parcours métier Docker | script local-e2e.py, sources des images comparées au dépôt | PASS en 12,228 s à 16:31 UTC ; commande persistée/relue, événement archivé, Redis arrêté → ready 503/health 200, reprise et seconde archive, compteur worker 2, nettoyage PASS |
| CI complète | run 38614847670, commit 640fd0396d5669aec5fe028fe639d503a453ddc1 | PASS : tests, build unique, scan 0 HIGH/CRITICAL, smoke et parcours métier réel sur le digest produit |
| Parcours métier de l'image CI | rapport orders-functional-38614847670 | PASS en 10,445 s ; Redis suspendu avec réseau conservé, ready 503/health 200, reprise, seconde archive et nettoyage |
| Promotion / rollback K3s | promote.py, opérateur privé | NON EXÉCUTÉ ; bootstrap, autorisation et données isolées requis |
| Site statique public | workflow Pages 38600626583, puis requêtes HTTP | PASS : page et evidence.json en HTTP 200 ; replay Docker présent ; contrôle visuel navigateur indisponible |
| Santé source finale | lecture SSH, 17:57 UTC | cinq services VM actifs et NTP=yes ; PostgreSQL prêt ; trois APIs /ready=200 ; Prometheus prêt, huit targets UP, compteurs Orders/Worker à 1 |

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
complémentaires avec port-forward ont d'abord été interrompus par la coupure
du VPN. Après réactivation, ils ont réussi, sans écriture métier :
[collecte source](../../demo/evidence/source-audit-20261014.json),
[collecte Kubernetes](../../demo/evidence/kubernetes-audit-20261014.json).
L'identité/les quotas ont été confirmés séparément par le propriétaire :
[sortie neutralisée](../../demo/evidence/openstack-audit-20261014.json).
La readiness et les compteurs ne prouvent pas un nouveau parcours métier cloud.

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

Les runs CI `38600089860` et `38600626522` ont passé les tests et publié leur
image candidate, puis l'installation du binaire Trivy 0.65.0 a retourné 1 sans
produire de rapport. Le wrapper téléchargeait un installeur depuis sa branche
`main`. La correction utilise directement l'image officielle Trivy 0.76.0,
figée par digest, avec le même gate HIGH/CRITICAL. Aucun défaut n'est ignoré.
Le premier déploiement Pages a été refusé car seule `main` était autorisée à
publier. La seule branche `demo/recruiter-v1` a été ajoutée à cette règle,
dans le périmètre de publication approuvé. Aucune protection cloud modifiée.
La relance Pages a ensuite réussi :
[exécution](https://github.com/Boualili-Youcef/Asteria/actions/runs/38600626583),
[site publié](https://boualili-youcef.github.io/Asteria/). Le bundle est limité
à quatre fichiers publics ; seule la branche de démo supplémentaire peut le
publier, sans élargissement des accès au cloud.

La relance CI a d'abord subi une erreur DNS GitHub `FinalizeArtifact:
ENOTFOUND`, après réussite des tests. La tentative suivante a effectivement
exécuté le scanner : **91 signalements par paquet/CVE** (88 HIGH, 3 CRITICAL),
dont 44 sans version corrigée dans le rapport. Les trois CRITICAL concernent
`perl-base` ; aucune HIGH/CRITICAL dans les dépendances Python détectées.
La candidate `sha256:7d0c3f88c75b84803ce9e20fb0a1709b64d315ae5d10cff01aafc5df3d6658da`
est refusée, sans artefact de promotion réussi. Une base Alpine officielle
figée par digest est introduite dans `demo/orders.Dockerfile`, en conservant
le code et les requirements applicatifs. Le Dockerfile Debian AS-IS reste
inchangé. La compatibilité musl, le fonctionnel et le nouveau scan doivent
réussir avant acceptation ; aucune exception de vulnérabilité n'est ajoutée.

La première variante Alpine a construit correctement avec les dépendances
Python existantes, mais le scan du run `38605759848` a encore refusé neuf
signalements HIGH et zéro CRITICAL : OpenSSL `libcrypto3`/`libssl3` et `libuuid`.
Les versions corrigées annoncées dans le rapport sont installées explicitement :
`libcrypto3=3.5.8-r0`, `libssl3=3.5.8-r0`, `libuuid=2.42.3-r1`.
Le gate reste identique. La candidate intermédiaire n'est pas promouvable.
Le build suivant a révélé que les versions minimales OpenSSL `3.5.8-r0`
étaient déjà remplacées dans le dépôt stable par `3.5.9-r0`. L'index officiel
`v3.24/main/x86_64/APKINDEX.tar.gz` a été lu : `libcrypto3` et `libssl3`
`3.5.9-r0`, `libuuid` `2.42.3-r1`. Ces versions disponibles sont désormais
épinglées. Les paquets retirés d'un dépôt stable peuvent bloquer un futur
rebuild ; l'image publiée par digest reste l'artefact promu, sans reconstruction.

Le run `38608110872` a ensuite passé tests, build, scan et smoke : zéro
HIGH/CRITICAL détecté. Son artefact commit/digest a été vérifié. Le pull local
GHCR a été refusé avec le credential disponible, sans élargissement de scope
ni conservation de token. Un gate métier réel a donc été ajouté sur le runner
déjà authentifié, avant émission de l'artefact promouvable. Le consommateur
refuse les anciens runs ne comportant pas ce gate réussi.

Le premier gate métier CI (`38609992239`) a persisté/archivé la commande, puis
a échoué sur le délai de readiness après arrêt Redis. L'inspection du client
installé `redis-py 8.0.1` confirme dix retries avec attente progressive par
défaut. La vérification Redis de readiness impose désormais zéro retry ; un
test avec un port loopback réservé mais non écouté exige 503 en moins de 2 s.
La publication métier conserve sa politique existante ; l'absence d'outbox
reste visible. La nouvelle image doit repasser tout le gate.

L'arrêt complet du conteneur Redis a encore dépassé le délai HTTP dans la
variante Alpine, malgré le retry de readiness désactivé. Le délai de résolution
DNS n'est pas borné par le timeout socket ; sa responsabilité exacte reste à
instrumenter, sans déclaration de correction. Le scénario CI retenu suspend
le processus Redis en conservant son réseau, puis le reprend : dépendance
réellement non répondante, DNS de service conservé. Le rapport indique ce
mode de panne. Le cas de disparition DNS reste une limite distincte et n'est
pas présenté comme validé.

## Release finale vérifiée

Le [run 38614847670](https://github.com/Boualili-Youcef/Asteria/actions/runs/38614847670)
a passé tous les gates, dont le parcours métier réel avec le digest candidat.
L'artefact a été revérifié par `promote.verify_ci` : identité du workflow,
commit, scan réussi, étape E2E réussie et JSON canonique identique.

```text
commit : 640fd0396d5669aec5fe028fe639d503a453ddc1
image  : ghcr.io/boualili-youcef/asteria/orders-api
digest : sha256:1f6372cbbf2a1534c29921ea860fda8055e1e465f77007dab93e101c659980aa
```

| Mesure | Durée réelle |
|---|---:|
| job tests | 23 s |
| build/publication Orders | 19 s |
| étape scan | 10 s |
| étape smoke | 8 s |
| étape E2E avec préparation de ses images | 26 s |
| test métier proprement dit, avec nettoyage | 10,445 s |
| promotion / rollback K3s | non exécutés, aucune durée annoncée |

Preuves : [release](../../demo/evidence/orders-release.json),
[résumé CI/scan](../../demo/evidence/ci-verification-20261014.json),
[test métier sur le digest CI](../../demo/evidence/ci-functional-20261014.json).
Le résultat zéro HIGH/CRITICAL est limité aux sévérités recherchées et à la
base de vulnérabilités de cette exécution. Les 91 signalements initiaux portent
sur la candidate reconstruite avec le Dockerfile Debian historique, pas sur
un scan des images M13 effectivement en cours dans le cluster source.

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
