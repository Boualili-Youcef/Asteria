# Preuve T06 — Accès Zero Trust prêt

## Résultat au 1er septembre 2026

- **Mission :** T06
- **Statut :** terminée
- **Traite/prépare :** `ASIS-001`, `ASIS-004`, `ASIS-011`, `REQ-SVC-007`,
  `REQ-SEC-002`, `REQ-SEC-010`
- **Dépendances :** T05 et ADR-005 terminées

Teleport Community `18.11.0` protège les accès SSH, Kubernetes et PostgreSQL
du lab. Le proxy mono-instance utilise TCP/3080 sur le bastion ; les six agents
sortent par tunnel inverse. Le chemin SSH/kubeconfig historique reste le
break-glass. Ce résultat ne revendique ni HA ni indépendance de panne.

## Faits vérifiés

- Terraform : 6 règles TCP/3080 ajoutées, aucune modification, aucun
  remplacement et aucune destruction ;
- TLS : certificat proxy et CA privée stockés hors Git, API `/webapi/ping`
  validée avec cette CA ;
- 7 nœuds SSH Teleport connectés : bastion, quatre nœuds standards, un agent
  Kubernetes et un agent PostgreSQL ;
- `kube_server=1`, `db_server=1` et aucun jeton d'enrôlement actif ;
- SSH et Teleport `active` sur les sept hôtes ;
- bastion : 617 Mio disponibles avant T06, 549 à 567 Mio après, au-dessus du
  seuil d'arrêt de 256 Mio ; service plafonné à 512 Mio ;
- Kubernetes : lecture de Pods autorisée au groupe observateur et création de
  `ClusterRole` refusée au groupe plateforme ;
- PostgreSQL : TLS chargé et négocié, rôle `asteria_readonly` non-superuser,
  backup préalable présent, PostgreSQL et SSH actifs ;
- idempotence : control plane, RBAC Kubernetes et mTLS PostgreSQL à
  `changed=0` ; agents Kubernetes et PostgreSQL à `changed=0` lors des reprises
  ciblées finales ; les quatre autres agents avaient déjà passé `changed=0` ;
- le break-glass ProxyJump et les contrôles UFW restent actifs.
- backup à chaud via `teleport backend clone` : 59 éléments clonés, 0 échec ;
  bundle local hors Git et copie distante conservés, trois checksums `OK`.
- GitHub SSO mappe l'équipe privée `Boualili-Youcef-Cloud/asteria-platform` au
  rôle Teleport `asteria-platform` ; le certificat utilisateur est limité à
  `ubuntu`, au groupe Kubernetes `asteria:t06-platform` et à
  `asteria_readonly` ;
- TOTP et WebAuthn sont enrôlés ; les accès privilégiés utilisent le dispositif
  `asteria-t06-webauthn` via MFA navigateur par session ;
- SSH : `ubuntu` retourne `ubuntu` et `root` retourne `access denied` après MFA ;
- Kubernetes : la liste des Pods réussit, `can-i list pods` retourne `yes` et
  `can-i create clusterroles` retourne `no` ;
- PostgreSQL : la requête retourne `asteria_readonly|postgres|f`, alors que la
  connexion comme `postgres` retourne `access to db denied` ;
- le certificat PostgreSQL court expirant à `19:45:20Z` est ensuite refusé avec
  `SSL error: sslv3 alert certificate expired` ;
- l'audit contient `user.login`, les validations WebAuthn, `session.start/end`,
  `kube.request`, `db.session.start/query/end`, le refus `root` et le refus
  PostgreSQL ; `tsh recordings ls` retrouve les sessions SSH et base ;
- l'exercice SSH break-glass retourne `ubuntu`, conserve SSH `active` et écrit
  la trace `T06 controlled exercise reason=mission-validation` ;
- le second passage du connecteur GitHub réussit et la validation finale confirme
  encore 7 nœuds, `kube=1`, `db=1`, `tokens=0`, RBAC et break-glass actifs.

Commande de synthèse :

```bash
scripts/t06-provision-zero-trust.sh validate
# Validation infrastructure T06: proxy TLS, 7 nœuds, kube=1, db=1,
# tokens=0, RBAC et break-glass actifs.

scripts/t06-backup-control-plane.sh
# Backup T06 protégé et vérifié:
# ~/.local/share/asteria/backups/t06-20260901T184651Z
```

## Corrections issues des tests live

Le bootstrap démarre en authentification locale jusqu'à la création du
connecteur GitHub, sinon Teleport renvoie `no github connectors found`. Le test
négatif Kubernetes accepte explicitement le code retour `1` avec `no`. La
sauvegarde des rôles PostgreSQL est écrite par root après exécution de
`pg_dumpall` comme utilisateur `postgres`.

La première activation GitHub a déclenché le rollback prévu : le remplacement
de `type: local` imposait une mauvaise indentation YAML. Le script conserve
désormais l'indentation et exécute `teleport configure --test` avant le
redémarrage. Le service est revenu en mode local, la validation complète a
réussi, puis la tentative corrigée a activé GitHub. Le premier callback a aussi
été refusé avec une liste d'équipes vide jusqu'à l'approbation explicite de
l'OAuth App par l'organisation.

Pour Teleport 18.11, le parseur lit `CA pins:` et Kubernetes utilise
`kubernetes_service.labels`, pas `static_labels`. Une validation de syntaxe et
une fenêtre de stabilisation empêchent désormais de confondre une boucle de
redémarrage avec un service sain. Le mode `resume-agent` retire son jeton local
et distant même après échec.

## Sécurité, rollback et limites

Les clés TLS, jetons, credentials, kubeconfigs et états ne figurent pas dans la
preuve ni dans Git. Les jetons d'enrôlement durent dix minutes au maximum et le
dernier contrôle en compte zéro. UFW limite le proxy aux CIDR administrateur et
aux six IP d'agents ; SSH administratif reste autorisé pour le break-glass.

Rollback : arrêter uniquement Teleport, vérifier SSH, puis conserver
`/var/lib/teleport` et les journaux. PostgreSQL peut restaurer les fichiers de
`/var/backups/asteria-t06-postgresql/pre-change/` et retirer
`98-t06-teleport-tls.conf`. Les six règles Terraform ne doivent être détruites
qu'après un nouveau plan inspecté.

## Conclusion et dette restante

T06 est terminée : le chemin quotidien est nominatif, court, protégé par
WebAuthn et audité ; les privilèges excessifs testés sont refusés. Le secret
OAuth, la CA privée et les credentials restent hors Git. Le lab conserve une
instance Teleport unique et dépend de GitHub ; il ne revendique ni HA ni
indépendance de panne. L'alerte automatique sur l'usage break-glass reste la
dette planifiée de T14. T07 est désormais autorisée.
