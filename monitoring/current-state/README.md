# Observabilité partielle — état AS-IS

## But

Cette pile fournit une visibilité minimale et volontairement incomplète :

- Prometheus collecte ses propres métriques et les Services Kubernetes annotés ;
- node-exporter fournit quelques métriques des trois nœuds ;
- Grafana affiche un unique dashboard artisanal `Asteria AS-IS Nodes`.

Grafana est accessible par ingress-nginx avec l'hôte
`grafana.asteria.local`. Prometheus reste un Service `ClusterIP`.

## Déploiement

Depuis la racine du dépôt :

```bash
.venv/bin/ansible-playbook \
  -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/m12-monitoring.yml
```

## Limites AS-IS conservées

- aucune règle d'alerte Prometheus et aucun Alertmanager ;
- aucun SLO, budget d'erreur ou catalogue homogène de métriques ;
- un seul dashboard construit manuellement ;
- aucune centralisation des logs : l'exploitation continue avec
  `kubectl logs` ;
- aucune collecte de traces ;
- données Prometheus et état Grafana sur `emptyDir`, donc perdus au redémarrage ;
- Grafana autorise la consultation anonyme depuis le chemin privé du bastion ;
- aucun mécanisme de haute disponibilité ou de sauvegarde.

Ces limites sont des preuves pour M16. Elles ne doivent pas être corrigées
silencieusement pendant M12.
