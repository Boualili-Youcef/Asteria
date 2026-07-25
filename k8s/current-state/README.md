# Déploiements Kubernetes AS-IS — M14

## But

M14 déploie les trois applications M13 sans leur donner de golden path commun :

| Application | Namespace | Méthode |
|---|---|---|
| `identity-api` | `team-identity` | YAML brut |
| `orders-api` | `team-orders` | chart Helm interne |
| `notifications-worker` | `team-notifications` | `kubectl apply` manuel |

Les commandes de cette page doivent être lancées sur le poste **LOCAL**, depuis
la racine du dépôt, avec le VPN actif. Le bastion ne contient ni le dépôt local,
ni les images Docker, ni les fichiers `.secrets/`.

## 1. Préparer les images et la configuration

M14 précède le CI/CD M15. Les images locales M13 sont donc importées
manuellement dans containerd sur les trois nœuds K3s :

```bash
export ASTERIA_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/tp_cloud"
./k8s/current-state/scripts/m14-import-local-images.sh
./k8s/current-state/scripts/m14-configure-runtime.sh
```

Le second script dérive l'adresse PostgreSQL des outputs Terraform, crée les
ConfigMaps non sensibles et transmet les mots de passe M08 directement à
`kubectl` par l'entrée standard. Aucune valeur sensible n'est écrite dans Git,
dans un argument de processus ou sur le bastion.

## 2. Déployer Identity avec du YAML brut

```bash
BASTION_IP="$(
  terraform -chdir=infra/terraform/openstack \
    output -json compute_instances |
  jq -r '.bastion.access_ip_v4'
)"

ssh -F /dev/null -i "$ASTERIA_SSH_PRIVATE_KEY_FILE" \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@${BASTION_IP}" \
  'kubectl apply --filename=-' \
  < k8s/current-state/identity-api/identity-api.yaml
```

## 3. Déployer Orders avec Helm

Le chart doit produire une vraie release Helm. Il est transféré dans un
répertoire temporaire du bastion, utilisé, puis supprimé :

```bash
tar -C k8s/current-state/orders-api/chart -czf - . |
  ssh -F /dev/null -i "$ASTERIA_SSH_PRIVATE_KEY_FILE" \
    -o StrictHostKeyChecking=accept-new \
    "ubuntu@${BASTION_IP}" '
      chart_dir="$(mktemp -d /tmp/asteria-orders-chart.XXXXXX)"
      tar -xzf - -C "${chart_dir}"
      helm upgrade --install orders-api "${chart_dir}" \
        --namespace team-orders \
        --wait \
        --timeout 5m
      rm -r "${chart_dir}"
    '
```

## 4. Déployer Notifications manuellement

Cette étape reste une commande opérateur directe, sans release Helm ni
automatisation partagée :

```bash
ssh -F /dev/null -i "$ASTERIA_SSH_PRIVATE_KEY_FILE" \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@${BASTION_IP}" \
  'kubectl apply --filename=-' \
  < k8s/current-state/notifications-worker/notifications-worker.yaml
```

## 5. Valider

```bash
scp -F /dev/null -i "$ASTERIA_SSH_PRIVATE_KEY_FILE" \
  -o StrictHostKeyChecking=accept-new \
  k8s/current-state/scripts/m14-validate-applications.sh \
  "ubuntu@${BASTION_IP}:/home/ubuntu/.local/bin/asteria-m14-validate-applications"

WORKER_01_IP="$(
  terraform -chdir=infra/terraform/openstack \
    output -json compute_instances |
  jq -r '.worker_01.access_ip_v4'
)"
WORKER_02_IP="$(
  terraform -chdir=infra/terraform/openstack \
    output -json compute_instances |
  jq -r '.worker_02.access_ip_v4'
)"

ssh -F /dev/null -i "$ASTERIA_SSH_PRIVATE_KEY_FILE" \
  -o StrictHostKeyChecking=accept-new \
  "ubuntu@${BASTION_IP}" "
    chmod 0750 /home/ubuntu/.local/bin/asteria-m14-validate-applications
    /home/ubuntu/.local/bin/asteria-m14-validate-applications \
      '${WORKER_01_IP}' '${WORKER_02_IP}' busybox:1.37.0
  "
```

Le script teste les trois méthodes, les probes, les routes Ingress, l'écriture
Identity, le flux Orders vers Redis puis Notifications et les métriques.

## Limites AS-IS visibles

- import manuel des images avant la disponibilité du registre M15 ;
- trois formats et trois commandes de déploiement ;
- secrets Kubernetes créés hors Git, sans gestionnaire centralisé ;
- un seul replica par application ;
- aucune NetworkPolicy applicative ;
- schémas PostgreSQL créés au premier besoin, sans migration versionnée ;
- aucune promotion, aucun rollback commun et aucun GitOps.
