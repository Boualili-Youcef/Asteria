# Observabilité AS-IS

## 1. Objet et portée

Ce document décrit l'état observé le **26 juillet 2026**. La pile permet de
répondre à quelques questions de disponibilité technique, mais elle ne fournit
pas une observabilité de production complète.

## 2. Composants déployés

| Composant | Topologie | Stockage | Accès |
|---|---|---|---|
| Prometheus 3.12.0 | un Deployment, un replica | `emptyDir`, 24 h et 800 MB maximum | Service `ClusterIP` |
| node-exporter 1.11.1 | un Pod par nœud, 3/3 prêts | aucun état durable | Service headless |
| Grafana 13.1.0 | un Deployment, un replica | `emptyDir` de 256 Mi | Ingress privé |
| Dashboard | `Asteria AS-IS Nodes` | ConfigMap versionnée | consultation anonyme `Viewer` sur le chemin privé |

Prometheus et Grafana ne sont ni hautement disponibles, ni sauvegardés. Leur
historique ou état local disparaît avec le remplacement des Pods.

## 3. Couverture Prometheus observée

L'API Prometheus retourne **huit targets `UP`** :

| Groupe | Targets | Couverture |
|---|---:|---|
| Prometheus | 1 | auto-observation |
| CoreDNS | 1 | métriques DNS K3s |
| node-exporter | 3 | control plane et deux workers |
| `identity-api` | 1 | métriques applicatives minimales |
| `orders-api` | 1 | métriques applicatives minimales |
| `notifications-worker` | 1 | métriques applicatives minimales |

La découverte repose sur les annotations `prometheus.io/scrape`. Une target
`UP` confirme qu'un endpoint répond ; elle ne démontre ni la qualité des
métriques, ni la disponibilité d'un parcours métier complet.

Les éléments suivants ne disposent pas de couverture dédiée :

- PostgreSQL ;
- Redis ;
- ingress-nginx ;
- état des objets Kubernetes via kube-state-metrics ;
- disponibilité externe depuis un client B2B ;
- files d'attente, délais métier, erreurs par parcours et saturation des
  dépendances.

## 4. Dashboard Grafana

Le dashboard artisanal `Asteria AS-IS Nodes` est visible et affiche les targets,
le CPU et la mémoire des nœuds. Aucun catalogue commun, dashboard de service,
dashboard PostgreSQL/Redis ou vue métier n'existe.

Grafana désactive le formulaire de connexion et autorise le rôle anonyme
`Viewer`. Ce choix reste limité au chemin privé bastion/Ingress ; il ne serait
pas acceptable tel quel sur une exposition publique.

## 5. Alerting, SLO et incidents

Le contrôle live retourne :

```text
RULE_GROUPS=0
```

Il n'existe :

- aucune règle Prometheus ;
- aucun Alertmanager ;
- aucun SLO, SLI, budget d'erreur ou objectif métier ;
- aucune notification d'incident ;
- aucune politique homogène de sévérité ou d'escalade.

Une panne peut donc être visible a posteriori dans un écran, sans déclencher
d'action automatique.

## 6. Logs et traces

Aucun Loki, Fluent Bit, Fluentd, Vector, Promtail ou collecteur
OpenTelemetry n'est déployé. Les logs restent locaux aux conteneurs et sont
consultés avec :

```bash
kubectl logs --namespace <namespace> deployment/<workload>
```

Il n'existe ni recherche transverse, ni rétention garantie, ni corrélation
centralisée, ni collecte de traces. La dérive d'environ sept minutes observée
sur les cinq VM rend en plus la corrélation temporelle moins fiable.

## 7. Chemin d'accès opérateur

Les commandes qui utilisent le dépôt, Terraform et la clé SSH commencent sur le
poste **LOCAL** connecté au VPN :

```bash
BASTION_IP="$(
  terraform -chdir=infra/terraform/openstack \
    output -json compute_instances |
  jq -r '.bastion.access_ip_v4'
)"

ssh -F /dev/null \
  -i "$HOME/.ssh/tp_cloud" \
  -L 33000:127.0.0.1:3000 \
  "ubuntu@${BASTION_IP}" \
  'kubectl -n monitoring port-forward --address=127.0.0.1 \
     service/grafana 3000:3000'
```

Le navigateur local ouvre ensuite `http://127.0.0.1:33000`. Le bastion ne
contient pas le state Terraform ni la clé privée du poste.

Grafana répond également par ingress-nginx avec l'hôte
`grafana.asteria.local`, via le NodePort privé des workers depuis le bastion.

## 8. Procédure de contrôle

Depuis le bastion :

```bash
kubectl --namespace=monitoring get deployment,pod,service,ingress
/home/ubuntu/.local/bin/asteria-m12-validate-monitoring busybox:1.37.0
```

Résultat du 26 juillet :

```text
Prometheus targets up: 8
Grafana dashboard visible: Asteria AS-IS Nodes
M12 monitoring checks passed
```

## 9. Dettes observées, sans correction en phase 1

- métriques limitées aux nœuds, à CoreDNS et aux trois applications ;
- dépendances data et entrée Ingress non supervisées spécifiquement ;
- un seul Prometheus, un seul Grafana et un seul dashboard ;
- stockage éphémère et rétention Prometheus très courte ;
- zéro règle, Alertmanager, SLO ou notification ;
- logs non centralisés et traces absentes ;
- accès Grafana anonyme sur le chemin privé ;
- synchronisation temporelle défaillante sur les cinq VM.

## 10. Preuves

- [M12 — observabilité partielle](../evidence/phase-1/M12-monitoring-partial-ready.md) ;
- [M14 — targets applicatives](../evidence/phase-1/M14-heterogeneous-deployments.md) ;
- [M16 — audit final](../evidence/phase-1/M16-as-is-audit-complete.md).
