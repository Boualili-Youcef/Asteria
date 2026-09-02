# ADR-002 — Retenir RKE2 en entreprise et K3s avec Cilium dans le lab

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T05/T07/T17

## Contexte

T02 confirme une seule zone `nova`, aucun stockage bloc et un projet secondaire
limité à 4 vCPU et 8 Go. Le cluster source K3s utilise un serveur SQLite unique,
deux agents et Flannel. Un green équivalent n'entre pas dans le second projet.

## Faits vérifiés et hypothèses

Faits : K3s `v1.36.2+k3s1` est observé ; CAP-05 permet seulement un staging à
deux VM ; K3s exige de désactiver Flannel et son moteur de policy pour installer
un CNI tiers. Hypothèse à valider en T07 : une version stable de Cilium supporte
Kubernetes 1.36, le noyau Ubuntu 24.04 et les fonctions eBPF requises.

## Décision

- La référence entreprise utilise **RKE2**, trois serveurs et au moins trois
  workers répartis sur trois domaines de panne prouvés, avec etcd embarqué.
- Le lab conserve **K3s** pour respecter la capacité et réduire l'exploitation.
- Le staging est créé directement avec `flannel-backend: none` et
  `disable-network-policy: true`, puis **Cilium** fournit CNI, politiques réseau
  et Hubble.
- Pod Security Admission et Kyverno complètent Cilium ; les namespaces
  applicatifs commencent en default-deny.
- Le cluster source Flannel n'est pas converti en place. Sa reconstruction ne
  peut intervenir qu'après répétition sur staging, backups T04/T15 et fenêtre
  de maintenance approuvée.

## Alternatives et conséquences

`kubeadm` est plus proche de l'amont mais augmente le coût de bootstrap et de
mise à niveau. RKE2 dans le lab consommerait davantage sans créer de HA réelle.
Calico est valide mais Hubble et les policies L7 de Cilium répondent mieux aux
besoins de visibilité T01. Conserver Flannel ne traite pas l'absence actuelle
de NetworkPolicy.

Le lab ne revendique ni HA de control plane, ni HA de zone. Hubble UI reste
optionnelle et activée seulement si la mesure CPU/RAM le permet.

## Capacité, compatibilité et rollback

- gate : version Cilium épinglée et matrice Kubernetes/noyau validée en T07 ;
- gate : mesure avant/après et budget explicite dans les 4 vCPU/8 Go du staging ;
- rollback staging : recréer le cluster CAP-05 depuis son state séparé ;
- rollback source : conserver K3s/Flannel jusqu'à la bascule finale, puis
  restaurer le datastore SQLite et le token avec la version K3s sauvegardée.

## Traçabilité et validation

Traite ou prépare `ASIS-001`, `ASIS-003`, `ASIS-004`, `ASIS-020` et
`REQ-SEC-003`, `REQ-SEC-009`, `REQ-DATA-010`, `REQ-SVC-011`.

Validation : nœuds Ready, DNS et flux inter-nœuds positifs ; default-deny puis
ouvertures explicites ; flux interdit refusé ; Hubble observe les deux cas ;
reconstruction chronométrée sans utiliser le kubeconfig admin partagé.

## Sources

- [RKE2 — CNI supportés et choix avant bootstrap](https://docs.rke2.io/networking/basic_network_options)
- [K3s — Custom CNI](https://docs.k3s.io/networking/basic-network-options#custom-cni)
- [Cilium — installation K3s](https://docs.cilium.io/en/stable/installation/k3s/)
