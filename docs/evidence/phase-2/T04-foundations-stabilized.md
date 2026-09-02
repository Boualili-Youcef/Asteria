# Preuve T04 — Fondations stabilisées avant migration

## Métadonnées

- **Date d'exécution initiale :** 2026-08-30
- **Date de revalidation et clôture durable :** 2026-08-31
- **Mission :** T04
- **Statut :** terminée
- **Branche :** `main`
- **Commit de référence avant mission :** conservé dans les métadonnées privées
- **Runtime modifié :** oui, uniquement temps et outils de sauvegarde décrits
  ci-dessous

## Objectif et résultat mesurable

Corriger `ASIS-019`, protéger le state et produire une baseline récupérable
avant T05. Le résultat requis est : cinq VM synchronisées avec un écart mesuré
≤ 1 s, services sains, break-glass vérifié, state et backups privés lisibles et
contrôlés par checksum.

T04 prépare aussi `ASIS-003`, `ASIS-005` et `ASIS-022`, ainsi que
`REQ-SVC-010`, `REQ-DATA-004`, `REQ-DATA-007` et `REQ-DATA-010`. Elle dépend de
T03, terminée avant toute mutation T04.

## Faits vérifiés avant changement

- les cinq VM sont Ubuntu 24.04 et accessibles via le bastion ;
- K3s `v1.36.2+k3s1` est actif avec trois nœuds `Ready` ;
- PostgreSQL 16 est actif et `pg_isready` réussit ;
- `sudo -n` fonctionne sur les cinq VM et l'usage maximal du filesystem racine
  est 37 % ;
- `systemd-timesyncd` est actif mais `NTPSynchronized=no` sur les cinq VM ;
- l'écart avant correction est compris entre 456 et 460 secondes ;
- le réseau provider laisse TCP/22 joignable malgré les références inter-SG,
  conformément à `ASIS-001`, mais `AllowUsers ubuntu@<IP_BASTION>` refuse
  l'authentification directe et le ProxyJump réussit ;
- le state Terraform local contient 39 ressources, au serial 62, et ses
  artefacts sensibles sont ignorés par Git mais initialement en mode `0664` ;
- Terraform 1.16.0, kubectl 1.35.3 et Helm 3.15.0-rc.2 sont présents sur le
  contrôleur ; Ansible y était absent avant l'environnement temporaire T04.

Quatre changements AS-IS préexistants ont été laissés hors périmètre et ne sont
pas modifiés par T03/T04.

## Hypothèses et limites

- les archives privées persistantes du poste opérateur sont une copie de
  sécurité transitoire du lab, pas une cible entreprise durable ;
- l'espace opérateur est considéré contrôlé pendant T04 ;
- aucune restauration destructive n'est autorisée sur l'AS-IS ;
- l'absence d'OpenRC empêche un refresh OpenStack/Terraform dans cette session,
  mais aucun apply Terraform n'est requis ou exécuté par T04.

## Décisions : entreprise et adaptation lab

La cible entreprise exige des sources de temps internes redondantes et
authentifiées, puis supervision et alerte de dérive. Le lab conserve
`systemd-timesyncd` et utilise `ntp.univ-lille.fr`, source institutionnelle
joignable depuis le réseau provider. Les pools publics restent uniquement en
fallback.

La source publique Canonical a d'abord été testée puis refusée : DNS répondait,
mais UDP/123 expirait sur toutes les VM. La source institutionnelle, issue des
[recommandations SSI de l'Université de Lille](https://ssi.univ-lille.fr/fileadmin/user_upload/ssi/documents/MFP-recommandations-mis_en_forme.pdf),
a répondu à un probe live de 48 octets, stratum 2, avant son application.

Pour la reprise, l'entreprise cible un stockage externe chiffré, immuable et
multi-domaines avec restauration testée. T04 fournit seulement des copies
initiales PostgreSQL, K3s et Terraform hors Git ; T15 reste propriétaire de la
planification, rétention, restauration, RTO/RPO et DR.

## Fichiers livrés

- `docs/phase-2-to-be/10-t04-foundations-runbook.md` ;
- `scripts/t04-protect-terraform-state.sh` ;
- `scripts/t04-collect-foundations.sh` ;
- `scripts/t04-validate-foundations.sh` ;
- `infra/ansible/group_vars/all.yml` ;
- `infra/ansible/playbooks/t04-ntp.yml` ;
- `infra/ansible/playbooks/t04-safety-backups.yml` ;
- `infra/ansible/README.md` ;
- cette preuve.

## Commandes exécutées dans l'ordre

```bash
./scripts/t04-protect-terraform-state.sh \
  /home/youcef/.local/share/asteria/backups/t04-20260831/terraform

./scripts/t04-collect-foundations.sh \
  /tmp/asteria-t04-20260830/before-v5 \
  /home/youcef/.ssh/tp_cloud

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml --check --diff

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml

ASTERIA_T04_BACKUP_ROOT=/home/youcef/.local/share/asteria/backups/t04-20260831 \
ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-safety-backups.yml

ansible-playbook -i infra/ansible/inventory/terraform_inventory.sh \
  infra/ansible/playbooks/t04-ntp.yml

./scripts/t04-collect-foundations.sh \
  /tmp/asteria-t04-20260831/verify \
  /home/youcef/.ssh/tp_cloud

./scripts/t04-validate-foundations.sh \
  /tmp/asteria-t04-20260831/verify \
  /home/youcef/.local/share/asteria/backups/t04-20260831
```

Les chemins privés sont publiés pour la reproductibilité, mais leurs contenus,
IP, tokens, state et dumps ne sont pas reproduits dans Git ou cette preuve.

## Écarts rencontrés et corrections

1. Le premier collecteur confondait une erreur d'échappement de commande
   Kubernetes avec un échec SSH. La collecte sépare désormais transport et
   santé, et mesure l'horloge sur l'intervalle local début/fin.
2. Le test TCP/22 initial contredisait le contrôle compensatoire documenté en
   M07. Le gate vérifie maintenant le vrai invariant : authentification directe
   refusée, ProxyJump réussi et `AllowUsers` limité au bastion.
3. `ntp.ubuntu.com` résolvait mais ne recevait aucune réponse UDP/123. Aucune
   ouverture réseau n'a été ajoutée ; la source institutionnelle vérifiée a été
   retenue.
4. Le double `become` Ansible vers l'utilisateur `postgres` échouait sur les ACL
   temporaires. Les commandes sont maintenant lancées par root via `runuser`,
   sans élargir les permissions Ansible.
5. Les fichiers internes K3s et les catalogues sont explicitement forcés en
   mode `0600` avant archivage.
6. La première copie hors Git utilisait `/tmp` et a disparu au nettoyage du
   poste. La revalidation du 31 août a donc correctement échoué, puis les trois
   backups ont été régénérés sous
   `/home/youcef/.local/share/asteria/backups/t04-20260831`, en mode privé. Le
   validateur a ensuite repassé tous les gates.

## Impact observé

- permissions locales du state, de son backup, des tfvars et des cinq anciens
  plans resserrées à `0600` ; aucun fichier supprimé ;
- création du drop-in `/etc/systemd/timesyncd.conf.d/50-asteria.conf` sur cinq
  VM et redémarrage de `systemd-timesyncd` uniquement ;
- correction initiale d'environ 7 min 40 s sur les horloges ;
- installation de `sqlite3` sur le control-plane ;
- création de dumps/transitoires sous `/var/backups/asteria-postgresql/` et
  `/var/backups/asteria-k3s/`, conservés sans nettoyage implicite ;
- création hors Git de `postgresql.tar.gz`, `k3s.tar.gz`, du state exporté et de
  leurs catalogues SHA-256 sous le répertoire persistant privé T04 du poste ;
- aucun redémarrage K3s/PostgreSQL, aucune bascule, migration de données,
  destruction ou application Terraform.

## Résultats des tests

| Contrôle | Avant | Après | Résultat |
|---|---:|---:|---|
| VM inventoriées | 5 | 5 | PASS |
| `NTPSynchronized=yes` | 0/5 | 5/5 | PASS |
| écart absolu mesurable | 456–460 s | 0 s sur 5/5 | PASS |
| nœuds K3s `Ready` | 3/3 | 3/3 | PASS |
| PostgreSQL prêt | oui | oui | PASS |
| SSH via ProxyJump + `sudo` | 5/5 | 5/5 | PASS |
| SSH direct interne | authentification refusée 4/4 | refusée 4/4 | PASS |
| state Terraform | `0664` | `0600`, checksum valide | PASS |
| archives runtime | absentes | deux archives `0600`, checksums valides | PASS |

Le second passage réel du playbook NTP donne `changed=0`, `failed=0` sur les
cinq VM. Les scripts refusent une destination relative (code 64) ou absolue
dans le dépôt (code 65) et n'écrasent pas un répertoire de rapport/state non
vide. Les trois
scripts passent `bash -n`; les deux playbooks passent `--syntax-check`,
`yamllint` et `ansible-lint --profile production` sans erreur ni warning.

Le contrôle final agrégé, rejoué le 31 août avec inventaire live et backups
persistants, retourne :

```text
PASS: cinq hôtes inventoriés
PASS: AllowUsers limité au bastion contrôlé sur quatre VM
PASS: state Terraform en mode 0600
PASS: checksums des archives runtime
PASS: checksums du state Terraform
RESULTAT: PASS T04 foundations
```

Le scan de secrets suivi par Git et le scan de motifs sensibles restent vides.

## Backup, rollback et critères d'arrêt

Le rollback NTP consiste à retirer uniquement le drop-in T04, recharger systemd,
redémarrer `systemd-timesyncd` et restaurer explicitement la source précédente.
Il n'est pas exécuté puisque le gate final passe. Les archives privées sont
conservées ; aucune suppression automatique distante ou locale n'est autorisée.

La mission se serait arrêtée sur hôte inaccessible, `sudo` refusé, service
dégradé, filesystem > 85 %, démon NTP concurrent, source non synchronisée,
checksum invalide, destination dans Git ou authentification directe interne
réussie. Ces critères ont bien arrêté les premières tentatives défectueuses.

## Gates de clôture

| Gate | Résultat requis | État |
|---|---|---|
| GATE-T04-01 | cinq VM NTP synchronisées, écart ≤ 1 s | validée |
| GATE-T04-02 | state hors Git, mode 0600, backup/checksum | validée |
| GATE-T04-03 | dump PostgreSQL rapatrié et checksum valide | validée |
| GATE-T04-04 | K3s SQLite + token rapatriés et checksum valide | validée |
| GATE-T04-05 | ProxyJump/sudo/Kubernetes positifs, SSH direct refusé | validée |
| GATE-T04-06 | baseline cinq hôtes et santé reproductible | validée |
| GATE-T04-07 | tests négatifs, sécurité et idempotence propres | validée |

## Dettes et conclusion

T04 est **terminée** et corrige la mesure runtime de `ASIS-019`. L'alerte de
dérive relève encore de T14. Les backups T04 ne prouvent ni restauration,
RTO/RPO, rétention, immutabilité, chiffrement externe ou DR ; ces dettes restent
à T15. `ASIS-001` reste ouvert jusqu'à la segmentation cible et aux tests T07/T17.

T05 est la prochaine mission autorisée, sans apply Terraform implicite. Elle
n'est pas démarrée par T04.
