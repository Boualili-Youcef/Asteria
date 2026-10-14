# Limites et état d'acceptation

Le but est de montrer une chaîne vérifiable, pas de revendiquer une plateforme
de production. Le registre [EVIDENCE](EVIDENCE.md) fait foi pour les résultats.

- Le second compte OpenStack est inaccessible et hors périmètre. Les preuves
  T05–T07 sont historiques ; leurs capacités ne sont pas supposées disponibles.
- Les quotas source ont été reconfirmés par la collecte du propriétaire :
  9/10 vCPU et 17/20 Gio, 5/8 instances. Cette marge Nova ne constitue pas
  une réservation de ressources Kubernetes pour la démo.
- Un control plane unique, PostgreSQL et Redis uniques ne constituent pas de
  HA. Les archives existantes ne prouvent ni restauration ni RPO/RTO ni DR.
- Les tests unitaires simulent les dépendances. Les tests du rollback simulent
  Helm/Kubernetes. Un test Docker fonctionnel ne prouve pas un rollback K3s.
- La promotion réelle et son échec contrôlé exigent une release de démo
  initialisée, un artefact CI valide, un accès privé borné et une autorisation.
- Le chart conserve ses valeurs AS-IS par défaut. Les nouvelles valeurs Demo
  changent uniquement une release séparée lors d'une activation future.
- La supply chain proposée demande SBOM/provenance et un scan HIGH/CRITICAL.
  Elle n'est pas certifiée : aucune vérification Sigstore à l'admission, aucune
  politique Kyverno de consommation. La variante Demo utilise une base figée
  par digest ; le Dockerfile historique, conservé, utilise encore un tag.
- L'image candidate est publiée avant scan ; le run et son artefact constituent
  le gate de promotion, pas la seule présence d'une image dans GHCR.
- Les métriques Prometheus sont partielles et volatiles. Les compteurs des
  processus peuvent repartir à zéro ; aucun SLO de parcours n'est démontré.
- L'application conserve l'absence d'authentification métier, d'outbox et de
  DLQ. Les tests rendent ces limites visibles sans les corriger en silence.
- Le scénario CI suspend Redis en conservant son réseau. La disparition du
  nom DNS lors d'un arrêt complet du conteneur Alpine a dépassé le budget HTTP
  du test ; ce cas reste à instrumenter. Le timeout socket et l'absence de
  retry ne bornent pas toute résolution DNS.
- Le namespace, PSA et RBAC ne suffisent pas à démontrer l'isolation réseau.
  Les refus inter-namespaces restent à tester avant données synthétiques K3s.
- La présentation publique est statique. Ses boutons explorent les preuves et
  un scénario préparé ; ils ne pilotent pas le cloud. Aucun replay de promotion
  réussie n'est annoncé sans enregistrement correspondant.
- Le [site public](https://boualili-youcef.github.io/Asteria/) est publié sur
  GitHub Pages et contrôlé en HTTP 200. Sa revue visuelle automatisée n'a pas
  pu être réalisée faute de navigateur disponible dans cette session.

Les dettes M16 restent ouvertes globalement. La reprise T08–T18 exige une
requalification de capacité et de répétition selon ADR-015.
