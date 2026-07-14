# Règles de travail du projet Asteria

Ce fichier s'applique à l'ensemble du dépôt. Il constitue le contrat de travail
des agents IA et des contributeurs pendant la construction du projet.

## 1. Contexte obligatoire

Avant toute mission :

1. lire `PROJECT_CONTEXT.md` ;
2. lire la mission courante dans `PHASE_1_BACKLOG.md` ;
3. consulter `archi.md` si la tâche affecte l'architecture ou les flux ;
4. inspecter l'état réel du dépôt avant toute modification ;
5. signaler toute contradiction entre documentation, code et environnement.

`contexte.md` contient du matériau de réflexion. Il ne remplace pas les
documents de pilotage validés.

## 2. Phase courante et maîtrise du périmètre

La phase courante est la **phase 1 : reconstruction de l'architecture AS-IS**.

- Ne pas proposer ni construire l'architecture cible TO-BE pendant cette phase.
- Ne pas sauter une mission ou une dépendance du backlog.
- Ne pas démarrer la mission suivante avant validation de la mission courante.
- Ne pas corriger les défauts AS-IS volontairement conservés.
- Ne pas ajouter un outil ou service sans besoin défini dans la mission.
- Toujours distinguer la référence d'entreprise et l'implémentation du lab.

Si une bonne pratique appartient à la phase 2, la consigner comme dette ou
recommandation future au lieu de l'implémenter silencieusement.

## 3. Format obligatoire d'une mission

Pour chaque mission, fournir ou documenter :

1. l'objectif et le résultat attendu ;
2. les dépendances et prérequis ;
3. les hypothèses, séparées des faits vérifiés ;
4. les décisions et leurs raisons ;
5. les fichiers à créer ou modifier ;
6. les commandes exactes, dans leur ordre d'exécution ;
7. le code ou la configuration complets lorsque nécessaire ;
8. les tests et validations ;
9. les résultats attendus et critères d'acceptation ;
10. les risques, limites et erreurs fréquentes ;
11. la preuve à enregistrer sous `docs/evidence/phase-1/` ;
12. la prochaine mission autorisée.

Les explications commencent par le but, puis détaillent les fichiers, commandes
et validations. Elles doivent rester accessibles à une personne construisant sa
première architecture depuis zéro.

## 4. Règles d'infrastructure

- Respecter la baseline de 5 instances, 9 vCPU et 17 Go tant que M03 n'a pas
  produit un inventaire justifiant explicitement une autre décision.
- Ne jamais inventer flavors, images, réseaux externes, quotas ou services
  OpenStack.
- Ne créer manuellement aucune ressource appartenant au périmètre Terraform.
- Exécuter `terraform fmt`, `terraform validate` et examiner
  `terraform plan` avant tout `terraform apply`.
- Ne jamais lancer un apply, une destruction ou une opération irréversible sans
  validation explicite de son périmètre et de son impact.
- Ne jamais recréer une ressource pour contourner une erreur sans diagnostic.
- Utiliser le bastion comme point d'administration lorsque prévu.

## 5. Sécurité et secrets

- Ne jamais écrire dans Git un mot de passe, token, `clouds.yaml`, clé privée,
  kubeconfig sensible ou secret en clair.
- Utiliser des exemples neutralisés pour les variables sensibles.
- Vérifier les changements Git avant chaque commit.
- Appliquer le moindre privilège nécessaire au fonctionnement du lab.

Une imperfection AS-IS peut être simulée ; une fuite de secret ou une exposition
dangereuse de l'environnement réel ne doit jamais l'être.

## 6. Validation et preuves

- Ne jamais déclarer une mission terminée sans validation observable.
- Enregistrer les preuves en Markdown dans `docs/evidence/phase-1/` avec le
  préfixe de mission.
- Indiquer dans chaque preuve : date, objectif, commandes, résultat utile,
  écarts et conclusion.
- Ne jamais placer de secrets ou sorties sensibles dans une preuve.
- Si un test n'est pas exécuté, le dire ; ne pas le présenter comme réussi.
- Mettre à jour le backlog seulement après satisfaction des critères.

## 7. Qualité des changements

- Réaliser des changements petits et limités à la mission courante.
- Préserver les modifications existantes hors périmètre.
- Préférer des fichiers lisibles et réutilisables aux réponses seulement
  conversationnelles.
- Documenter les arbitrages importants au moment où ils sont pris.
- Ne jamais présenter une hypothèse comme un fait vérifié.
- Ne pas ajouter de complexité pour donner une apparence plus avancée au projet.

## 8. Dettes à ne pas corriger prématurément

Pendant la phase 1, conserver et rendre visibles :

- les déploiements YAML, Helm et manuels hétérogènes ;
- l'absence de GitOps commun et de golden path ;
- les scans et SBOM non systématiques ;
- le control plane et PostgreSQL non HA ;
- Redis partagé ;
- le RBAC et les NetworkPolicies incomplets ;
- l'observabilité partielle et les logs non centralisés ;
- les restaurations de sauvegardes non testées.

Leur correction sera étudiée en phase 2 sur la base des preuves de la phase 1.
