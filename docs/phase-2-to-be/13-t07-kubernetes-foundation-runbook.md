# T07 — Fondation Kubernetes cible sur staging

## But, statut et périmètre

T07 construit sur les deux VM CAP-05 un cluster K3s `v1.36.2+k3s1` avec
Cilium/Hubble, sécurité par défaut et stockage de test. La mission est
**terminée sur staging**. Conformément à ADR-014, le cluster source K3s/Flannel
reste intact jusqu'aux répétitions T15/T17 et à une fenêtre approuvée.

T07 traite ou prépare `ASIS-001`, `ASIS-003`, `ASIS-004`, `ASIS-020`,
`REQ-SEC-003`, `REQ-SEC-009`, `REQ-DATA-010` et `REQ-SVC-011`.

## Faits vérifiés et hypothèses

- staging : un control plane et un worker Ubuntu 24.04, 2 vCPU/4 Gio chacun ;
- budget : 4 vCPU/8 Gio, soit 100 % du quota secondaire et aucune marge ;
- noyau `6.8.0-71-generic`, sans swap, avec les sept options eBPF exigées ;
- Cilium `1.20.1` supporte Kubernetes 1.36 et un noyau Linux >= 5.10 ;
- le réseau provider contourne les security groups dans ce lab : UFW reste le
  contrôle hôte effectif, testé en T05 puis étendu ici ;
- le stockage `local-path` et toutes les données T07 sont synthétiques et
  jetables.

L'hypothèse restante est que les contrôleurs T08 à T16 tiennent dans la marge
mémoire observée. Chaque mission doit encore mesurer avant/après ; l'absence de
marge de quota demeure l'exception CAP-05 approuvée, pas une capacité HA.

## Cible et adaptation lab

La référence entreprise reste RKE2 avec trois serveurs et au moins trois
workers répartis sur trois domaines de panne prouvés. Le lab utilise un serveur
K3s SQLite et un worker : aucune HA, aucun DR et aucun stockage durable ne sont
revendiqués.

K3s démarre avec Flannel et son moteur de policy désactivés. Cilium fournit le
CNI VXLAN, les NetworkPolicies et les flux Hubble ; `kube-proxy` est conservé.
Hubble Relay est actif, mais son UI est désactivée pour limiter la consommation.
Pod Security Admission applique `restricted`, les ServiceAccounts ne montent
pas de token par défaut et le namespace de validation possède quota,
LimitRange, default-deny et ouvertures explicites.

## Livrables et impact

- `infra/ansible/playbooks/t07-kubernetes-foundation.yml` : guards, K3s,
  Cilium, UFW et convergence ;
- `k8s/target-foundation/` : chart Cilium, PSA et ressources de validation ;
- `scripts/t07-provision-kubernetes.sh` : préflight, déploiement et idempotence ;
- `scripts/t07-validate-kubernetes.sh` : tests positifs, négatifs et source ;
- ce runbook et `docs/evidence/phase-2/T07-target-kubernetes-foundation.md`.

L'impact runtime est limité aux deux VM staging : installation K3s/Cilium,
règles UFW internes et ressources synthétiques. Aucun Terraform plan/apply,
aucune ressource OpenStack et aucun hôte source ne sont modifiés par T07.

## Ordre exact

```bash
cd /home/youcef/Documents/Docs/M2/Asteria
export ASTERIA_ANSIBLE_PLAYBOOK="$HOME/.local/share/asteria/venvs/t06-ansible/bin/ansible-playbook"

scripts/t07-provision-kubernetes.sh preflight
scripts/t07-provision-kubernetes.sh deploy
scripts/t07-provision-kubernetes.sh validate
scripts/t07-provision-kubernetes.sh idempotence
```

Le playbook refuse un nom hors staging, une topologie autre que 1+1, un noyau
incompatible, du swap ou un état K3s non signé T07. Il ne copie aucun
kubeconfig sur le poste, le bastion ou dans Git. Le ProxyJump existant sert
uniquement au bootstrap contrôlé ; l'accès quotidien reste Teleport T06.

## Arrêt, reprise et rollback

Arrêter si un guard échoue, si un nœud/Cilium n'est pas `Ready`, si un refus
attendu réussit, si UFW est ouvert globalement, si le source change ou si la
mémoire disponible devient insuffisante pour l'étape suivante.

Le marqueur `/etc/asteria/t07-staging-managed` distingue un provisioning
interrompu d'un cluster étranger et permet une reprise idempotente. En cas
d'échec, stopper `k3s` et `k3s-agent` conserve les VM et les journaux ; rejouer
le playbook restaure la cible. Un retour complet à T05 utilise les scripts
désinstallation K3s ou la recréation du staging depuis son state séparé,
uniquement après plan et autorisation destructive explicite. Le source et ses
backups T04 ne participent jamais à ce rollback.

## Acceptation

1. deux nœuds `Ready`, Cilium 2/2, CoreDNS, Hubble et composants K3s prêts ;
2. DNS et client control-plane vers serveur worker réussissent ;
3. default-deny refuse le service non autorisé ; Hubble voit succès et refus ;
4. le rôle observateur lit les Pods, mais ne crée pas de Pod et ne lit pas les
   Secrets ; un Pod privilégié est refusé par PSA ;
5. quota/LimitRange appliqués et PVC `local-path` écrit puis relit la preuve ;
6. source 3/3 `Ready` avec `flannel.1`, capacité staging mesurée ;
7. second passage Ansible : `changed=0`, aucun échec.

La reconstruction complète dans le RTO et la restauration depuis backup restent
des preuves T15/T17. T08 peut maintenant installer Gateway API/TLS sur staging.

## Documentation et références

Pour éviter la duplication, T07 produit exactement un runbook et une preuve ;
le backlog et le README restent les index. Les ADR existantes portent les
arbitrages, sans nouveau document de synthèse.

- [Cilium sur K3s](https://docs.cilium.io/en/stable/installation/k3s/)
- [Compatibilité Kubernetes de Cilium](https://docs.cilium.io/en/stable/network/kubernetes/compatibility/)
- [Prérequis et ports Cilium](https://docs.cilium.io/en/stable/operations/system_requirements/)
- [Pod Security Admission](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/)
