# T06 — Accès d'administration Zero Trust

## But et limites

Le lab remplace l'usage quotidien de la clé SSH et du kubeconfig admin par
Teleport Community `18.11.0` : GitHub SSO, MFA WebAuthn par session, RBAC,
certificats courts de 30 minutes au maximum et audit. Le bastion SSH actuel
reste le break-glass.

La référence entreprise sépare Auth/Proxy en HA, utilise un IdP OIDC géré et un
backend d'audit durable. Le lab place une instance unique sur le bastion 1 vCPU /
1 Gio : ce n'est ni HA, ni un domaine de panne indépendant.

## Faits, hypothèses et arrêts

- T05 est terminé ; les deux states OpenStack restent séparés.
- Le bastion avait 617 Mio disponibles et 5,6 Gio disque libres avant T06.
- Seul TCP/3080 est ajouté pour les CIDR admin et les six agents exacts.
- UFW est l'enforcement réel car `ASIS-001` prouve que les SG seuls ne suffisent
  pas sur le réseau provider.
- Arrêt si le plan détruit/modifie une ressource, si SSH ne revient pas ou si la
  mémoire disponible descend sous 256 Mio.
- GitHub exige une organisation, une équipe, une OAuth App et MFA côté IdP. Le
  premier démarrage utilise temporairement l'authentification locale : le script
  SSO crée d'abord le connecteur puis bascule vers GitHub avec rollback si l'API
  ne revient pas.

## Ordre exact

```bash
cd /home/youcef/Documents/Docs/M2/Asteria
python3.12 -m venv "$HOME/.local/share/asteria/venvs/t06-ansible"
"$HOME/.local/share/asteria/venvs/t06-ansible/bin/pip" install ansible-core==2.21.2
export ASTERIA_ANSIBLE_PLAYBOOK="$HOME/.local/share/asteria/venvs/t06-ansible/bin/ansible-playbook"

scripts/t06-provision-zero-trust.sh prepare

source "/home/youcef/Downloads/youcef.boualili.etu-openrc.sh"
scripts/t06-provision-zero-trust.sh plan
terraform -chdir=infra/terraform/openstack show t06-network.tfplan
scripts/t06-provision-zero-trust.sh apply

scripts/t06-provision-zero-trust.sh deploy
scripts/t06-install-client.sh
scripts/t06-provision-zero-trust.sh validate  # validation infrastructure
scripts/t06-backup-control-plane.sh
```

Une reprise ciblée conserve les mêmes jetons courts et garde-fous :
`ASTERIA_T06_AGENT_LIMIT=<hôte> scripts/t06-provision-zero-trust.sh resume-agent`.

Le plan attendu contient 6 ajouts, 0 modification, 0 remplacement et 0
destruction. Un plan doit être recréé si le code ou le state change.

## GitHub et tests utilisateur

Créer l'OAuth App avec :

- homepage : `https://teleport.asteria.lab:3080` ;
- callback : `https://teleport.asteria.lab:3080/v1/webapi/github/callback`.
- organisation : `Boualili-Youcef-Cloud` ;
- équipe privée : `asteria-platform`.

L'OAuth App doit recevoir l'accès explicite à l'organisation. Ne pas désactiver
globalement la restriction des applications tierces.

Placer le secret hors Git en `0600`, puis :

```bash
scripts/t06-configure-github-sso.sh \
  <organisation> <equipe> <client-id> /chemin/hors-git/client-secret

tsh login --proxy=teleport.asteria.lab:3080 --auth=github
tsh status
tsh ls
```

`t06-install-client.sh` installe aussi la résolution privée et la CA dans les
magasins système et NSS de Chrome. Redémarrer Chrome avant l'enrôlement. Le
TOTP reste un secours de compte, mais Teleport 18.11 exige WebAuthn, SSO MFA ou
MFA navigateur pour `require_session_mfa`. Enregistrer un dispositif WebAuthn
depuis **Account Settings > Security > Add MFA**, puis utiliser
`--mfa-mode=browser` avec les commandes `tsh`.

Tests d'acceptation :

1. `asteria-platform` réussit en SSH comme `ubuntu`, jamais comme `root` ;
2. `asteria-platform` lit les Pods mais ne crée pas de `ClusterRole` ;
3. PostgreSQL accepte `asteria_readonly`, refuse `postgres` pour ce rôle ;
4. une nouvelle session après expiration du certificat est refusée ;
5. la session SSH/Kubernetes/PostgreSQL apparaît dans l'audit ;
6. le ProxyJump SSH break-glass réussit et produit une trace manuelle.

L'alerte break-glass en moins de 5 minutes reste une dette T14 ; T06 produit la
trace mais ne prétend pas fournir l'alerting avant l'observabilité.

## Rollback

```bash
ssh -i ~/.ssh/tp_cloud ubuntu@<IP_BASTION> \
  'sudo systemctl disable --now teleport && systemctl is-active ssh'
```

Sur un agent, arrêter uniquement `teleport`; ne pas toucher à SSH/K3s/PostgreSQL.
Pour PostgreSQL, restaurer les fichiers de
`/var/backups/asteria-t06-postgresql/pre-change/`, retirer
`98-t06-teleport-tls.conf`, puis redémarrer PostgreSQL. Conserver les journaux et
`/var/lib/teleport` pour l'audit ; ne supprimer aucun accès break-glass pendant
T06.
