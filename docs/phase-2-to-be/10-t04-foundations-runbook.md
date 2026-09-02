# Runbook T04 — Stabiliser les fondations avant migration

## 1. But et résultat mesurable

T04 rend le source suffisamment observable et récupérable pour commencer la
landing zone sans masquer ses dettes. La mission est validée seulement si :

- les cinq VM ont `NTPSynchronized=yes` et un écart absolu mesuré ≤ 1 s ;
- l'inventaire privé des cinq VM, du cluster et de PostgreSQL est exporté ;
- un dump PostgreSQL, un backup cohérent K3s SQLite + token et le state
  Terraform sont copiés hors Git, protégés et contrôlés par checksum ;
- le chemin break-glass SSH → bastion → hôtes, `sudo` et Kubernetes fonctionne,
  tandis que l'authentification SSH directe vers les hôtes internes est refusée ;
- la baseline de versions et les contrôles de santé sont rejouables ;
- aucun secret ou inventaire privé n'entre dans Git.

T04 traite `ASIS-019` et prépare `ASIS-003`, `ASIS-005`, `ASIS-022`,
`REQ-SVC-010`, `REQ-DATA-004`, `REQ-DATA-007`, `REQ-DATA-010`.

## 2. Faits vérifiés avant exécution

- le state local contient 39 objets et est ignoré par Git ;
- avant T04, `terraform.tfstate`, son backup, les tfvars et anciens plans sont
  en mode `0664`, trop ouvert pour leur classification ;
- aucun backend distant n'est configuré ;
- la baseline déclarée est K3s `v1.36.2+k3s1`, PostgreSQL 16 et Ubuntu 24.04 ;
- le contrôleur local observé le 30 août 2026 utilise Terraform 1.16.0,
  kubectl 1.35.3, Helm 3.15.0-rc.2 et ne possède pas Ansible ;
- le pré-check T04 confirme `NTP=yes` mais `NTPSynchronized=no`, avec 456 à
  460 secondes de retard sur les cinq VM ;
- SSH via ProxyJump, `sudo`, K3s 3/3 `Ready` et PostgreSQL prêt sont confirmés ;
- conformément à `ASIS-001`, TCP/22 reste joignable sur le réseau provider ; le
  contrôle compensatoire M07 refuse l'authentification directe avec `AllowUsers`
  et autorise uniquement la source du bastion.

## 3. Hypothèses et responsabilités

| Hypothèse | Propriétaire | Réaction si fausse |
|---|---|---|
| le VPN/chemin vers le bastion est disponible lors de la fenêtre | opérateur | arrêter avant toute mutation |
| la source institutionnelle `ntp.univ-lille.fr` reste joignable depuis le provider network | DGDNum/réseau | arrêter et faire confirmer une autre source interne ; ne pas ouvrir largement UDP/123 |
| la clé locale actuelle est le break-glass autorisé | propriétaire du lab | identifier/faire approuver une autre clé avant test |
| le poste opérateur peut conserver temporairement des backups RESTRICTED | propriétaire du lab | choisir une destination chiffrée et contrôlée |
| l'espace disque des VM et du poste suffit | Platform | arrêter avant création des archives |

## 4. Fichiers et responsabilités

| Fichier | Effet |
|---|---|
| `scripts/t04-protect-terraform-state.sh` | resserre les permissions locales et exporte le state hors Git |
| `infra/ansible/playbooks/t04-ntp.yml` | configure `systemd-timesyncd` et attend la synchronisation |
| `infra/ansible/playbooks/t04-safety-backups.yml` | produit et rapatrie les backups PostgreSQL/K3s |
| `scripts/t04-collect-foundations.sh` | collecte en lecture seule versions, temps, services et santé |
| `scripts/t04-validate-foundations.sh` | applique les gates T04 aux rapports/backups privés |

Les rapports et archives restent dans une destination privée hors dépôt. Le
backup K3s contient un token administrateur et les dumps contiennent des données
de classe RESTRICTED : mode `0600`, accès minimal et aucune sortie de chat.

## 5. Pré-check et commandes exactes

Exécuter depuis la racine du dépôt avec le VPN actif. Remplacer le timestamp par
la valeur réelle ; utiliser un stockage persistant privé hors Git. `/tmp` est
interdit pour la copie de clôture, car son nettoyage invaliderait les gates.

```bash
date -u +%FT%TZ
git status --short --branch
test -f /home/youcef/.ssh/tp_cloud
stat -c '%a %n' /home/youcef/.ssh/tp_cloud
terraform -chdir=infra/terraform/openstack state list

export ASTERIA_T04_BACKUP_ROOT=/home/youcef/.local/share/asteria/backups/t04-YYYYMMDDTHHMMSSZ
install -d -m 0700 "${ASTERIA_T04_BACKUP_ROOT}"

./scripts/t04-protect-terraform-state.sh \
  "${ASTERIA_T04_BACKUP_ROOT}/terraform"

./scripts/t04-collect-foundations.sh \
  "${ASTERIA_T04_BACKUP_ROOT}/before" \
  /home/youcef/.ssh/tp_cloud
```

Arrêter si un hôte est inaccessible, si `sudo -n` échoue, si PostgreSQL/K3s
n'est pas sain, si l'usage du filesystem racine dépasse 85 %, ou si la
destination est dans Git.

## 6. Stabiliser le temps

Installer Ansible dans un environnement contrôlé si nécessaire, puis valider la
syntaxe avant exécution. Un autre démon NTP actif provoque un refus explicite.

```bash
ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml --syntax-check

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml --check --diff

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml
```

Le lab utilise `ntp.univ-lille.fr`, vérifié live en stratum 2. La cible
entreprise doit fournir au moins deux sources internes, authentifiées et
supervisées. Les pools publics sont seulement des fallbacks et peuvent être
bloqués par le réseau provider.

Impact : installation/activation de `systemd-timesyncd`, création de
`/etc/systemd/timesyncd.conf.d/50-asteria.conf` et redémarrage du service de
temps. Le premier passage peut avancer l'horloge de plusieurs minutes. Aucun
service applicatif, K3s ou PostgreSQL n'est redémarré.

Rollback si les sources sont invalides : restaurer le fichier précédent s'il
existait ou retirer uniquement le drop-in T04, puis redémarrer le service. Ne
jamais laisser deux démons actifs.

```bash
ansible all -i infra/ansible/inventory/terraform_inventory.sh --become \
  -m ansible.builtin.file \
  -a 'path=/etc/systemd/timesyncd.conf.d/50-asteria.conf state=absent'
ansible all -i infra/ansible/inventory/terraform_inventory.sh --become \
  -m ansible.builtin.systemd_service \
  -a 'name=systemd-timesyncd state=restarted daemon_reload=true'
```

## 7. Produire les backups de sécurité

```bash
export ASTERIA_T04_BACKUP_ROOT=/home/youcef/.local/share/asteria/backups/t04-YYYYMMDDTHHMMSSZ

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-safety-backups.yml --syntax-check

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-safety-backups.yml

find "${ASTERIA_T04_BACKUP_ROOT}" -maxdepth 2 -type f \
  -printf '%m %f\n'
```

Le dump PostgreSQL utilise le script M08 sans interruption. Le backup K3s
utilise l'API `.backup` SQLite en ligne, puis copie le token serveur requis au
déchiffrement du datastore. `sqlite3` est installé sur le control-plane si
nécessaire. Fichiers internes, archives et catalogues sont forcés en mode
`0600`. Les archives transitoires distantes sont conservées par défaut afin
qu'aucun nettoyage destructif ne soit implicite.

T04 contrôle checksums et lisibilité ; la restauration destructive est réservée
à une cible isolée en T15. Ces copies de sécurité ne prouvent donc pas encore
RTO/RPO ou DR.

## 8. Collecte finale et gates

```bash
./scripts/t04-collect-foundations.sh \
  "${ASTERIA_T04_BACKUP_ROOT}/after" \
  /home/youcef/.ssh/tp_cloud

./scripts/t04-validate-foundations.sh \
  "${ASTERIA_T04_BACKUP_ROOT}/after" \
  "${ASTERIA_T04_BACKUP_ROOT}"

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml

git status --short
git diff --check
```

Résultat attendu : `RESULTAT: PASS T04 foundations`, cinq hôtes synchronisés,
services actifs, trois nœuds K3s Ready, PostgreSQL prêt, state `0600`, archives
présentes et checksums valides. Sur les quatre hôtes internes, la tentative SSH
directe sans configuration implicite doit être refusée, `AllowUsers` doit viser
le bastion et le ProxyJump doit réussir. Le second passage NTP doit annoncer
`changed=0`.

## 9. Tests négatifs et sécurité

```bash
./scripts/t04-protect-terraform-state.sh ./dans-le-depot
./scripts/t04-collect-foundations.sh ./dans-le-depot
git ls-files '*.tfstate*' '*.tfvars' '*.tfplan' '*.key' '*.pem'
rg -l --hidden -g '!.git/**' \
  'BEGIN (RSA |OPENSSH )?PRIVATE KE[Y]|OS_PASSWOR[D]=[^<[:space:]]+|K1[0][0-9a-f]{64}::' .
```

Les deux premières commandes doivent refuser une destination relative. Ajouter
un test d'authentification SSH direct avec `ssh -F /dev/null` : `Permission
denied` est attendu sur les quatre VM internes, car le réseau provider ne prouve
pas à lui seul l'isolement inter-SG. La liste Git et le scan doivent rester vides
pour les artefacts/valeurs sensibles. Tout match est inspecté sans imprimer la
valeur complète dans une preuve publique.

## 10. Critères de clôture et dette restante

T04 est passée à `Terminée` durablement le 31 août 2026 après revalidation live,
backups persistants hors Git, preuve publique agrégée et absence de secret dans
le diff. Restent à T15 :
cible S3 externe, planification/rétention, restauration isolée, RTO/RPO et DR.
La prochaine mission autorisée est T05, sans apply implicite.
