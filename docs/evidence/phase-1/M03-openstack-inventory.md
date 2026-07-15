# Preuve M03 — Inventaire OpenStack

## Métadonnées

- **Date :** 2026-07-15
- **Mission :** M03
- **Résultat :** validé avec limitations documentées

## Objectif

Remplacer les hypothèses de capacité OpenStack par un inventaire exploitable
avant la conception réseau et toute infrastructure as code.

## Provenance

Le propriétaire du tenant a fourni les sorties des commandes suivantes depuis
un terminal authentifié :

```bash
openstack quota show
openstack flavor list
openstack image list
openstack network list
openstack network show prive
openstack subnet show prive
openstack security group list
openstack floating ip list
```

Les UUID de ressources, l'identifiant de projet et l'URL exacte de l'endpoint
ont été volontairement retirés de cette preuve. Aucun secret n'était présent
dans les données conservées.

## Résultats synthétiques

- quotas : 8 instances, 10 cœurs et 20 480 Mo de RAM ;
- flavors utiles : `normale` (1 vCPU / 1 Go) et
  `puissante` (2 vCPU / 4 Go) ;
- huit images actives, dont `ubuntu24.04` et `debian-12-custom` ;
- un réseau externe partagé et actif : `prive` ;
- sous-réseau externe `172.28.0.0/16`, passerelle `172.28.0.1`, DHCP actif ;
- pool d'allocation `172.28.100.0` à `172.28.200.255` ;
- sécurité des ports activée et MTU de 1500 ;
- trois security groups visibles : `default`, `moodle-lab-sg` et
  `k8s_sg_defense` ;
- la commande Floating IP reçoit une réponse HTTP 404 de Neutron ;
- l'extension `router` n'est pas exposée et `router list` retourne 404 ;
- `network agent list` ne retourne aucun agent visible ;
- les créations de réseaux internes retournent HTTP 503.

## Contrôles complémentaires

Les commandes suivantes ont été tentées depuis l'environnement local :

```bash
openstack network list --external
openstack server list
openstack router list
openstack subnet list
openstack loadbalancer provider list
```

Les quatre premières n'ont pas interrogé le cloud, car `auth-url` n'était pas
chargé dans cet environnement. La dernière n'est pas reconnue par le client
local, ce qui indique l'absence du plugin Octavia local sans prouver l'absence
du service côté cloud.

## Validation de la baseline

La baseline à deux workers utilise :

- 5 instances sur 8 ;
- 9 vCPU sur 10 ;
- 17 Go sur 20 Go.

La variante à trois workers utiliserait 6 instances, 11 vCPU et 21 Go. Elle
dépasse donc les quotas et est rejetée.

## Décisions

- conserver un control plane et deux workers ;
- référencer `prive` comme unique underlay existant, sans le gérer ;
- précréer un port Neutron par VM et appliquer les SG par rôle ;
- ne pas retenir Floating IP ou Octavia dans la baseline actuelle ;
- concevoir le fallback NodePort prévu dans `archi.md` ;
- contrôler l'usage réel et le réseau `prive` avant tout apply.

## Validation documentaire

```bash
rg -n '^## ' docs/phase-1-as-is/02-openstack-lab-constraints.md
rg -n '8 instances|10 vCPU|20 Go|11 vCPU|21 Go|NodePort' \
  docs/phase-1-as-is/02-openstack-lab-constraints.md
git diff --check
```

## Écarts et limitations

- l'usage actuel des quotas n'a pas été fourni ;
- les réseaux self-service et routeurs L3 ne sont pas disponibles ;
- l'API Floating IP répond 404 ;
- Octavia côté cloud n'est pas confirmé.

Ces limitations imposent la topologie provider-network-only formalisée dans
ADR-001. Elles n'empêchent pas la création de ports et de security groups.

## Conclusion

L'inventaire et l'échec contrôlé M05 fixent la topologie du lab. Les cinq
security groups et leurs règles restent suivis par Terraform ; aucun réseau ni
routeur n'a été créé.
