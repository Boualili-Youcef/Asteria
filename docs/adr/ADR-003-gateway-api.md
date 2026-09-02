# ADR-003 — Retenir Gateway API avec Envoy Gateway

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T08/T17

## Contexte

L'entrée AS-IS utilise ingress-nginx archivé, sans VIP, Floating IP, Octavia,
DNS autoritatif OpenStack ni certificat métier. Le provider network reste le
seul underlay des deux projets.

## Décision

- La référence entreprise utilise Gateway API, **Envoy Gateway**, cert-manager,
  DNS et un LB/VIP fourni par l'infrastructure.
- Le lab utilise les mêmes ressources `GatewayClass`, `Gateway` et `HTTPRoute`,
  mais expose Envoy par NodePort privé limité au chemin d'administration.
- Les routes applicatives appartiennent aux équipes ; Gateway, certificats,
  `ReferenceGrant` et politiques d'attachement appartiennent à Platform.
- La version exacte est épinglée en T08 après contrôle de la matrice Envoy
  Gateway/Gateway API/Kubernetes. Au 30 août 2026, Envoy Gateway v1.9 couvre
  Kubernetes 1.36 ; ce constat devra être revérifié au moment du déploiement.

## Alternatives et conséquences

Cilium Gateway réduit le nombre de produits mais couple le cycle d'entrée au
CNI. Traefik est viable, mais Envoy Gateway sépare mieux les rôles Gateway API
et fournit une trajectoire explicite. Conserver ingress-nginx est rejeté.

Le NodePort lab n'est pas une exposition B2B HA. Le TLS de test utilise une CA
privée ou un DNS réellement contrôlé ; aucun certificat public n'est simulé.

## Capacité, compatibilité et rollback

- budget mesuré contrôleur + data plane avant retrait de l'ancien Ingress ;
- coexistence sur ports distincts jusqu'aux tests de routes et de TLS ;
- rollback : remettre le trafic privé vers ingress-nginx, sans supprimer Envoy
  avant analyse ; aucune bascule DNS n'est exécutée par T03.

## Traçabilité et validation

Traite `ASIS-002`, `ASIS-021` et prépare `ASIS-010`, `REQ-SVC-001`,
`REQ-SEC-004`, `REQ-DATA-002`.

Tests : bon host/route/TLS en 2xx, mauvais host refusé, référence
inter-namespace sans `ReferenceGrant` refusée, certificat invalide refusé et
rollback dans la fenêtre T01.

## Source

- [Envoy Gateway — matrice de compatibilité](https://gateway.envoyproxy.io/news/releases/matrix/)
