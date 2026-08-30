# Runbook T02 — Collecter les deux projets OpenStack

## 1. But

Produire deux inventaires comparables en lecture seule, sans exposer les
OpenRC, tokens, UUID de projet ou endpoints. Le script enregistre les rapports
privés sous `/tmp` et continue lorsqu'une capacité optionnelle est absente ou
refusée afin de conserver l'erreur utile au diagnostic.

## 2. Prérequis

```bash
cd /home/youcef/Documents/Docs/M2/Asteria
openstack --version
bash -n scripts/t02-collect-openstack-inventory.sh
```

Attendus : client OpenStack disponible et aucun message de syntaxe Bash.

Ne jamais afficher, ouvrir dans l'IDE, copier dans Git ou transmettre le contenu
des fichiers OpenRC. On les **source** uniquement dans le terminal local.

## 3. Collecter le projet source

Dans un nouveau terminal :

```bash
cd /home/youcef/Documents/Docs/M2/Asteria
source /chemin/prive/compte-source-openrc.sh
./scripts/t02-collect-openstack-inventory.sh \
  source \
  /tmp/asteria-t02/source
```

Le fichier OpenRC peut demander le mot de passe de manière interactive. Ne pas
mettre ce mot de passe dans la commande, l'historique ou un fichier du dépôt.

Contrôler la collecte :

```bash
column -t -s $'\t' /tmp/asteria-t02/source/source-manifest.tsv
awk -F '\t' '$2 != 0 {print}' /tmp/asteria-t02/source/source-manifest.tsv
sed -n '1,260p' /tmp/asteria-t02/source/source-inventory.md
```

Les erreurs sur Octavia, Designate, Swift, L3 ou Floating IP sont des résultats
à analyser ; elles ne justifient pas de modifier le cloud.

## 4. Effacer le contexte puis collecter le projet candidat

Ne jamais superposer deux OpenRC. Effacer d'abord toutes les variables `OS_*` :

```bash
while IFS='=' read -r name _; do
  if [[ $name == OS_* ]]; then
    unset "$name"
  fi
done < <(env)
```

Puis charger le deuxième compte :

```bash
source /chemin/prive/compte-candidat-openrc.sh
./scripts/t02-collect-openstack-inventory.sh \
  target \
  /tmp/asteria-t02/target
```

Contrôler la seconde collecte :

```bash
column -t -s $'\t' /tmp/asteria-t02/target/target-manifest.tsv
awk -F '\t' '$2 != 0 {print}' /tmp/asteria-t02/target/target-manifest.tsv
sed -n '1,260p' /tmp/asteria-t02/target/target-inventory.md
```

## 5. Vérifier qu'aucun identifiant sensible ne subsiste

Le script neutralise UUID et URLs d'endpoint. Vérifier les rapports avant de
les transmettre :

```bash
rg -n \
  '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|[0-9a-fA-F]{32}|https?://|OS_PASSWORD|OS_TOKEN|BEGIN .*PRIVATE KEY)' \
  /tmp/asteria-t02/source/source-inventory.md \
  /tmp/asteria-t02/target/target-inventory.md
```

Attendu : aucune sortie. Les noms de ressources ne sont pas des secrets, mais
ils seront remplacés par des rôles logiques dans la preuve publique.

## 6. Transmettre les résultats pour synthèse

Fournir les quatre fichiers suivants comme pièces jointes, sans les déplacer
dans le dépôt :

```text
/tmp/asteria-t02/source/source-inventory.md
/tmp/asteria-t02/source/source-manifest.tsv
/tmp/asteria-t02/target/target-inventory.md
/tmp/asteria-t02/target/target-manifest.tsv
```

La synthèse remplira la matrice de capacité, calculera la marge et distinguera :

- service réellement disponible ;
- service absent du catalogue ;
- plugin CLI manquant ;
- API présente mais refusée par policy ;
- ressource disponible mais quota consommé.

## 7. Connectivité inter-projets — seconde porte

La collecte API ne prouve pas le trafic entre deux VMs.

### Cas A — une VM existe déjà dans chaque projet

Le module dédié se trouve dans
`infra/terraform/openstack-t02-probe/`. Il gère uniquement une règle temporaire
TCP/22 sur le SG `default` secondaire, depuis le `/32` du bastion source.

Suivre son `README.md` pour préparer le tfvars, initialiser, valider et examiner
le plan. Aucun apply n'est autorisé avant approbation explicite. Le test exige :

- une source et une destination explicitement identifiées ;
- un port temporairement ou déjà autorisé par la matrice ;
- un succès attendu sur ce port ;
- un refus attendu vers PostgreSQL, Kubernetes API ou un NodePort non autorisé ;
- la vérification indépendante que le service du port refusé écoute bien côté
  cible, sinon l'échec distant ne démontre pas à lui seul le filtrage ;
- journaux SG/hôte si disponibles.

Ne pas utiliser un simple ping comme preuve suffisante : ICMP peut être traité
différemment de TCP et ne valide pas les contrôles applicables.

### Cas B — le projet candidat est vide

Si le projet a été vidé avant le probe, ne pas créer une règle sans destination.
Contrôler d'abord l'état final :

```bash
openstack server list -f table -c Name -c Status
openstack quota show --compute --usage -f yaml
openstack quota show --network --usage -f yaml
openstack port list -f table -c Name -c Status -c "Device Owner"
openstack security group list -f table -c Name -c Description
```

Attendus dans le second projet : aucun serveur, 0/4 instance, 0/4 vCPU,
0/8 Go de RAM, aucun port compute et seulement les security groups conservés
volontairement. Le test inter-projets devient alors un critère bloquant de la
première création T05.

Si une VM de probe devait au contraire être créée pendant T02, sa création
exigerait :

1. un petit module/state Terraform diagnostic séparé ;
2. un plan montrant uniquement le probe et ses règles minimales ;
3. l'examen des quotas et du coût ;
4. l'approbation explicite avant apply ;
5. tests positif et négatif ;
6. plan de destruction du probe, également approuvé.

Ne créer aucune VM, port ou security group manuellement pour accélérer T02.

## 8. Critères d'arrêt

Arrêter immédiatement si :

- le label ou le compte chargé ne correspond pas au projet attendu ;
- une commande affiche un mot de passe, token ou clé ;
- les quotas/usage principaux échouent ;
- une commande propose création, modification ou suppression ;
- un rapport est écrit dans le dépôt ;
- la connectivité nécessite un changement non planifié.

## 9. Fin de mission

T02 restera `En cours` jusqu'à réception des deux collectes et validation de la
connectivité. Après analyse :

1. compléter `07-dual-project-openstack-inventory.md` ;
2. décider le rôle de chaque projet et le sizing du lab ;
3. finaliser `docs/evidence/phase-2/T02-dual-project-openstack-inventory.md` ;
4. valider les huit gates T02 ;
5. passer T02 à `Terminée` et créer le commit de mission ;
6. autoriser seulement alors T03.
