# Preuve T07 — Fondation Kubernetes cible validée

## Résultat au 2 septembre 2026

- **Mission :** T07
- **Statut :** terminée sur staging
- **Dépendances :** T05, T06, ADR-002, ADR-004 et ADR-014 terminées
- **Traite/prépare :** `ASIS-001`, `ASIS-003`, `ASIS-004`, `ASIS-020`,
  `REQ-SEC-003`, `REQ-SEC-009`, `REQ-DATA-010`, `REQ-SVC-011`

Le staging CAP-05 exécute K3s `v1.36.2+k3s1` avec Cilium `1.20.1`. Le test
place le client sur le control plane et le serveur autorisé sur le worker afin
de prouver le VXLAN inter-nœuds. Le cluster source n'a pas été reconstruit.

## Faits observés

- `staging-k8s-control-plane-01` et `staging-k8s-worker-01` : 2/2 `Ready` ;
- Cilium DaemonSet : 2/2 ; operator, CoreDNS, Hubble Relay,
  local-path-provisioner et metrics-server : prêts ;
- CNI : `cilium_vxlan` présent, `flannel.1` absent, chart `1.20.1` ;
- DNS : `echo.t07-validation.svc.cluster.local` résout une ClusterIP `10.43.x` ;
- flux autorisé : le client lit `allowed-by-explicit-policy` sur le worker ;
- flux refusé : le même client n'atteint pas `blocked` ;
- export Hubble : le namespace T07 contient des verdicts `FORWARDED` et
  `DROPPED` ;
- RBAC : l'observateur peut lister les Pods, ne peut ni en créer ni lire les
  Secrets ;
- PSA : un Pod privilégié est refusé par le profil `restricted` v1.36 ;
- stockage : PVC `t07-local-path` `Bound`, contenu `t07-storage-ok` relu ;
- quota observé : 4/10 Pods, 40m/500m CPU demandé, 64Mi/512Mi mémoire
  demandée, 64Mi/1Gi stockage ;
- idempotence : control plane `changed=0`, worker `changed=0`, aucun échec ;
- Teleport reste actif sur les deux hôtes et aucun kubeconfig T07 n'est copié
  dans le compte `ubuntu` ;
- source : trois nœuds `Ready`, K3s `v1.36.2+k3s1`, `flannel.1` toujours
  présent.

Mesure après installation :

| Hôte staging | Mémoire disponible | Service principal | Teleport |
|---|---:|---:|---:|
| control plane | 2602 Mio | K3s 2 393 403 392 octets | 33 857 536 octets |
| worker | 3066 Mio | K3s agent 1 326 247 936 octets | 32 821 248 octets |

Ces chiffres sont une photographie, pas un test de charge. Le projet secondaire
reste à 0 vCPU et 0 Mio de quota libres.

## Incident détecté et correction

Le premier bootstrap a installé les deux nœuds et Cilium, puis Hubble Relay,
CoreDNS, metrics-server et local-path sont restés non prêts. Les règles
`KUBE-SERVICES` existaient ; les journaux UFW montraient explicitement :

```text
UFW BLOCK SRC=10.42.0.182 DST=172.28.100.8 PROTO=TCP DPT=6443
```

La cause était l'absence du flux Pods `10.42.0.0/16` vers l'API hôte après
DNAT de `10.43.0.1`. Le playbook autorise désormais uniquement ce CIDR vers
TCP/6443 sur le control plane, et vers TCP/10250 et TCP/4244 sur les nœuds.
UFW reste `deny incoming` et `deny routed`; aucune ouverture globale n'a été
faite. La reprise d'un provisioning signé T07 est maintenant gérée sans
accepter un cluster non géré.

Le contrôle DNS a aussi été corrigé : BusyBox retournait `1` après avoir
résolu le FQDN, car il poursuivait les suffixes de recherche en NXDOMAIN. La
validation vérifie dorénavant le nom canonique et la ClusterIP observée.

## Commandes de preuve

```bash
scripts/t07-provision-kubernetes.sh preflight
scripts/t07-provision-kubernetes.sh validate
# PASS: DNS, VXLAN inter-nœuds, allow/deny, Hubble, RBAC, PSA, quotas et stockage.
# PASS: cluster source AS-IS intact et capacité staging mesurée.

scripts/t07-provision-kubernetes.sh idempotence
# control plane: changed=0, failed=0
# worker:        changed=0, failed=0
```

Les manifestes YAML se chargent correctement, `bash -n`, Ansible
`--syntax-check`, `terraform fmt -check`, `terraform validate` et
`git diff --check` passent. Le state OpenStack staging reste à 14 ressources
gérées et 4 data sources. Aucun plan/apply Terraform n'était requis : les
règles runtime T07 sont gérées par UFW/Ansible, contrôle effectif du lab.

## Acceptation, limites et suite

| Gate | Résultat |
|---|---|
| compatibilité noyau/K3s/Cilium et guards | validée |
| 2/2 nœuds et composants système prêts | validée |
| DNS et flux inter-nœuds autorisé | validée |
| default-deny et refus observable | validée |
| RBAC minimal et PSA restricted | validée |
| quota, limites et stockage synthétique | validée |
| source inchangé et idempotence `changed=0` | validée |

T07 ne ferme pas encore `ASIS-003` sur le source et ne prouve pas un RTO de
reconstruction/restauration : ces contrôles restent T15/T17. Le lab est non-HA,
SQLite et `local-path`, sans marge de quota, Cinder ni stockage objet. T08 est
la prochaine mission autorisée sur ce staging ; l'intégration des identités et
politiques avancées reste T09.
