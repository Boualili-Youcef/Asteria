# Preuve M12 — Observabilité partielle prête

## Métadonnées

- **Date :** 2026-07-23
- **Mission :** M12
- **Statut :** réussi

## Objectif et résultat attendu

Fournir une visibilité minimale avec Prometheus et Grafana sans présenter
l'AS-IS comme une plateforme d'observabilité mature. Les targets et un dashboard
doivent être visibles, tandis que l'absence de SLO, d'alerting homogène et de
centralisation des logs reste explicite.

## Dépendances et prérequis vérifiés

- M10 est terminée et le namespace `monitoring` existe ;
- les trois nœuds K3s sont `Ready` ;
- ingress-nginx répond sur les deux workers ;
- les nœuds consommaient entre 7 et 15 % de leur mémoire avant M12 ;
- les versions ont été vérifiées auprès des projets officiels le 23 juillet
  2026 : Prometheus 3.12.0, node-exporter 1.11.1 et Grafana 13.1.0.

## Faits, hypothèses et décisions

Prometheus découvre les endpoints Kubernetes portant l'annotation
`prometheus.io/scrape: "true"`. M12 fournit trois targets node-exporter et la
target Prometheus elle-même. CoreDNS, déjà annoté par K3s, est également
découvert : cinq targets `UP` ont donc été observées.

La visibilité reste volontairement partielle :

- un seul Prometheus et un seul Grafana ;
- données stockées dans des volumes `emptyDir` ;
- rétention Prometheus limitée à 24 heures et 800 MB ;
- un dashboard artisanal avec targets, CPU et mémoire des nœuds ;
- aucune règle Prometheus, aucun Alertmanager et aucun SLO ;
- aucun Loki, Fluent Bit, Vector ou autre backend/agent de logs ;
- logs toujours consultés manuellement avec `kubectl logs` ;
- consultation Grafana anonyme par le chemin privé ingress-nginx.

## Fichiers livrés

- `monitoring/current-state/prometheus.yml` ;
- `monitoring/current-state/rbac.yaml` ;
- `monitoring/current-state/node-exporter.yaml` ;
- `monitoring/current-state/prometheus.yaml` ;
- `monitoring/current-state/grafana-provisioning.yaml` ;
- `monitoring/current-state/grafana.yaml` ;
- `monitoring/current-state/dashboards/asteria-as-is-nodes.json` ;
- `monitoring/current-state/README.md` ;
- `infra/ansible/playbooks/m12-monitoring.yml` ;
- `infra/ansible/scripts/m12-validate-monitoring.sh`.

## Commandes exécutées

```bash
export ANSIBLE_CONFIG="$PWD/infra/ansible/ansible.cfg"
export ANSIBLE_HOME="$PWD/.ansible"

bash -n infra/ansible/scripts/m12-validate-monitoring.sh
jq empty monitoring/current-state/dashboards/asteria-as-is-nodes.json

docker run --rm --entrypoint /bin/promtool \
  -v "$PWD/monitoring/current-state/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  prom/prometheus:v3.12.0 \
  check config /etc/prometheus/prometheus.yml

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m12-monitoring.yml --syntax-check

.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m12-monitoring.yml
```

Chaque manifest a également été accepté par
`kubectl apply --dry-run=server` avant son application réelle.

## Résultats observés

| Composant | Version/image | État |
|---|---|---|
| Prometheus | `prom/prometheus:v3.12.0-distroless` | `1/1 Running` |
| node-exporter | `quay.io/prometheus/node-exporter:v1.11.1` | `3/3`, un par nœud |
| Grafana | `grafana/grafana:13.1.0` | `1/1 Running` |

Les Services Prometheus et Grafana sont `ClusterIP`. Le Service node-exporter
est headless. Seul Grafana possède un Ingress, avec l'hôte
`grafana.asteria.local`, réutilisant les NodePorts M10.

Le test synthétique exécuté depuis un Pod éphémère a retourné :

```text
Prometheus targets up: 5
Grafana dashboard visible: Asteria AS-IS Nodes
M12 monitoring checks passed
```

`/api/health` Grafana a aussi répondu en HTTP 200 depuis le bastion via chacun
des deux workers.

## Preuve d'idempotence

Le second passage complet donne :

| Hôte | `changed` | `failed` |
|---|---:|---:|
| `bastion-admin-01` | 0 | 0 |

Le Pod de validation est créé puis supprimé sans changement persistant.

## Critères d'acceptation

- configuration Prometheus validée par `promtool` ;
- manifests acceptés côté API Kubernetes ;
- Prometheus, Grafana et trois node-exporters prêts ;
- cinq targets `UP` observées ;
- dashboard artisanal visible via l'API Grafana ;
- Grafana accessible par ingress-nginx depuis les deux workers ;
- absence de règles, Alertmanager et centralisation des logs documentée et
  contrôlée ;
- second passage `changed=0`.

## Risques, limites et erreurs fréquentes

- un redémarrage détruit l'historique Prometheus et l'état local Grafana ;
- aucune alerte ne prévient une panne ;
- l'accès anonyme Grafana serait inacceptable sur une exposition publique ;
- node-exporter monte `/proc`, `/sys` et `/` en lecture seule pour observer les
  hôtes ; ce privilège de visibilité doit rester limité ;
- les annotations de scrape ne garantissent ni couverture homogène ni qualité
  des métriques applicatives ;
- cinq targets `UP` ne signifient pas que les objectifs métier sont surveillés ;
- les traces et les logs centralisés restent absents.

## Conclusion et prochaine mission

M12 est **Terminée**. La pile rend visibles quelques métriques et un dashboard
sans masquer ses lacunes structurelles. M13 — créer les trois applications —
est maintenant la seule mission en cours.
