# Règles de travail du projet Asteria

Ce fichier s'applique à l'ensemble du dépôt. Il constitue le contrat de travail
des agents IA et des contributeurs pendant la transformation TO-BE.

## 1. Contexte obligatoire

Avant toute mission :

1. lire `PROJECT_CONTEXT.md` ;
2. lire la mission courante dans `PHASE_2_BACKLOG.md` ;
3. lire les constats `ASIS-xxx` concernés dans
   `docs/phase-1-as-is/08-as-is-known-issues.md` ;
4. consulter les ADR et diagrammes relatifs à la mission ;
5. inspecter le dépôt, le runtime et les modifications locales ;
6. signaler toute contradiction entre documentation, code et environnement.

`archi.md` et `docs/phase-1-as-is/` décrivent le point de départ. Ils ne doivent
pas être modifiés pour faire croire qu'une capacité TO-BE existait déjà.

## 2. Phase courante et maîtrise du périmètre

La phase courante est la **phase 2 : transformation TO-BE**.

- Ne pas sauter une mission ou une dépendance du backlog.
- Ne pas implémenter un candidat T00 avant son approbation par ADR en T03.
- Toujours distinguer référence entreprise, cible approuvée et adaptation lab.
- Relier chaque changement à un besoin T01 et à au moins un constat M16.
- Ne jamais déclarer HA/DR sans domaines de panne et tests correspondants.
- Ne pas ajouter un produit uniquement pour rendre le projet plus complexe.
- Préserver les contrôles positifs AS-IS jusqu'à validation de leur remplaçant.
- Une seule mission est `En cours` et un commit reste mission-scoped.

## 3. Format obligatoire d'une mission

Pour chaque mission, fournir ou documenter :

1. l'objectif et le résultat mesurable ;
2. les constats `ASIS-xxx`, exigences et dépendances concernés ;
3. les faits vérifiés et les hypothèses, dans des sections séparées ;
4. les décisions/ADR et leurs alternatives ;
5. la cible entreprise et l'implémentation lab ;
6. les fichiers créés ou modifiés ;
7. les commandes exactes, dans l'ordre ;
8. l'impact prévu : ajouts, modifications, remplacements et destructions ;
9. le backup, le rollback et les critères d'arrêt ;
10. les tests positifs, négatifs, de sécurité et d'idempotence ;
11. les résultats attendus et critères d'acceptation ;
12. la preuve sous `docs/evidence/phase-2/` ;
13. les dettes restantes et la prochaine mission autorisée.

Les explications commencent par le but et restent accessibles à une personne
qui construit sa première plateforme complète.

## 4. Règles de migration et d'infrastructure

- Réinventorier les deux projets OpenStack en T02 avant tout nouveau sizing.
- Ne jamais inventer quota, réseau, stockage, load balancer ou connectivité.
- Utiliser un state et des credentials Terraform distincts par projet.
- Ne créer manuellement aucune ressource appartenant à Terraform ou GitOps.
- Exécuter format, validation et plan ; examiner tout remplacement/destruction.
- Ne jamais lancer apply, destruction, bascule ou migration de données sans
  validation explicite du périmètre et de l'impact.
- Ne jamais réutiliser un plan Terraform après modification du state ou du code.
- Préférer blue/green ; conserver l'AS-IS et un rollback jusqu'aux tests finaux.
- Corriger la source d'une erreur avant de recréer une ressource.
- Mesurer CPU, RAM et stockage avant et après l'ajout d'un contrôleur.

## 5. Données et continuité

- Définir RPO/RTO avant de choisir réplication et sauvegardes.
- Une sauvegarde n'est validée qu'après restauration et contrôle d'intégrité.
- Réplication, sauvegarde et DR sont trois mécanismes différents.
- Chiffrer les flux data et limiter leurs identités/sources.
- Protéger les migrations par pré-check, sauvegarde, répétition et rollback.
- Ne jamais tester une panne destructive sur l'AS-IS sans autorisation dédiée.

## 6. Sécurité, identités et secrets

- Ne jamais écrire dans Git mot de passe, token, clé privée, OpenRC,
  `clouds.yaml`, kubeconfig sensible, secret ou donnée client.
- Préférer identités fédérées, certificats courts et tokens temporaires.
- Conserver un break-glass limité et testé pendant la migration Zero Trust.
- Appliquer moindre privilège, default-deny et ServiceAccounts dédiés.
- Déployer les policies en audit, mesurer, puis enforce avec exceptions datées.
- Vérifier signatures/provenance à la consommation ; produire ne suffit pas.
- Une faiblesse AS-IS peut être démontrée sans reproduire une fuite réelle.

## 7. Livraison et GitOps

- Construire une image une fois et promouvoir son digest.
- Épingler les actions et dépendances de déploiement à des versions immuables.
- Les workflows communs doivent produire tests, scan, SBOM et provenance.
- Git est la source de vérité Kubernetes après T13.
- Toute action d'urgence est documentée puis réconciliée dans Git.
- Un rollback doit être exécutable et testé, pas seulement décrit.

## 8. Validation et preuves

- Ne jamais déclarer une mission terminée sans validation observable.
- Les preuves indiquent date, objectif, commandes, résultats, écarts et conclusion.
- Si un test n'est pas exécuté, le dire explicitement.
- Tester les refus attendus autant que les succès.
- Relier toute clôture `ASIS-xxx` à une mesure avant/après.
- Mettre à jour le backlog seulement après satisfaction des critères.
- Vérifier les secrets, liens, diagrammes et diff Git avant chaque commit.

## 9. Qualité des changements

- Réaliser de petits changements limités à la mission courante.
- Préserver les modifications existantes hors périmètre.
- Préférer fichiers, scripts et runbooks reproductibles aux réponses de chat.
- Documenter arbitrages, propriétaires et risques au moment de la décision.
- Ne jamais présenter une hypothèse ou une recommandation comme un fait.
- Ne pas masquer les limites du lab pour embellir le résultat portfolio.

## 10. Condition de réussite

La phase 2 ne cherche pas une architecture sans compromis. Elle réussit si les
22 constats M16 sont corrigés ou acceptés explicitement, les exigences T01 sont
mesurées, les restaurations et retours arrière sont testés, et une autre équipe
peut comprendre, exploiter et reproduire la plateforme à partir du dépôt.
