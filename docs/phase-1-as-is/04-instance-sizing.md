# Dimensionnement des instances — Baseline M04

## 1. Objectif

Figer le dimensionnement et les interfaces réseau des cinq VMs avant leur
création en M06. M04 ne crée aucune instance.

## 2. Image de référence

`ubuntu24.04` est retenue comme image de référence pour les cinq VMs, car elle
est active dans l'inventaire M03 et permet une base homogène pour Ansible,
Kubernetes et PostgreSQL.

Le nom est validé, mais son ID ne sera pas codé en dur. Terraform M06 devra la
rechercher comme data source et refuser une sélection ambiguë.

## 3. Tableau de dimensionnement

| Instance | Flavor | vCPU | RAM | Disque flavor | Interfaces | Security groups |
|---|---|---:|---:|---:|---|---|
| `bastion-admin-01` | `normale` | 1 | 1 Go | 10 Go | Port dédié sur `prive` | `asteria-bastion-sg` |
| `k8s-control-plane-01` | `puissante` | 2 | 4 Go | 20 Go | Port dédié sur `prive` | `asteria-control-plane-sg` |
| `k8s-worker-01` | `puissante` | 2 | 4 Go | 20 Go | Port dédié sur `prive` | worker + ingress SG |
| `k8s-worker-02` | `puissante` | 2 | 4 Go | 20 Go | Port dédié sur `prive` | worker + ingress SG |
| `db-postgres-01` | `puissante` | 2 | 4 Go | 20 Go | Port dédié sur `prive` | `asteria-postgres-sg` |
| **Total** | — | **9** | **17 Go** | **90 Go** | — | — |

La DMZ, le management, l'application et la data sont des zones logiques portées
par les SG. Le bastion n'est plus multi-homed.

## 4. Conformité aux quotas

| Quota | Limite | Baseline | Marge nominale |
|---|---:|---:|---:|
| Instances | 8 | 5 | 3 |
| vCPU | 10 | 9 | 1 |
| RAM | 20 Go | 17 Go | 3 Go |

Cette marge est théorique : l'usage actuel du tenant reste à contrôler avant
M06. La capacité disque globale n'a pas été fournie par M03 ; les 90 Go
correspondent aux disques inclus dans les flavors, pas à une demande Cinder
validée.

## 5. Décisions d'exploitation

- aucun troisième worker ;
- un seul control plane, volontairement non HA ;
- un seul PostgreSQL primaire, volontairement non HA ;
- les workloads applicatifs seront planifiés sur les workers ;
- les cinq VMs sont reliées à `prive` par des ports précréés ;
- seul le bastion accepte SSH depuis le CIDR administrateur ;
- les workers portent le SG Ingress en plus de leur SG Kubernetes ;
- aucune ressource de réserve n'est créée.

## 6. Risques

- le flavor `normale` laisse peu de RAM au bastion ;
- la marge d'un seul vCPU interdit tout ajout non planifié ;
- une consommation existante du tenant peut empêcher M06 ;
- la création de ports sur `prive` doit réussir avant M06 ;
- le stockage réel disponible n'est pas encore confirmé.

## 7. Validation attendue avant M06

```bash
openstack limits show --absolute
openstack server list
openstack flavor show normale
openstack flavor show puissante
openstack image show ubuntu24.04
```

M06 ne doit pas commencer si la capacité restante est inférieure à la baseline.
