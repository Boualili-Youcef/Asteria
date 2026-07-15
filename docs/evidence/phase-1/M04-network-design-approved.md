# Preuve M04 — Conception réseau approuvée

## Métadonnées

- **Date initiale :** 2026-07-15
- **Date de révision :** 2026-07-15
- **Mission :** M04
- **Résultat :** validé selon ADR-001

## Objectif

Définir un plan réseau exécutable sur le tenant réel avant la création des VMs.

## Livrables

- `docs/phase-1-as-is/03-network-design.md` ;
- `docs/phase-1-as-is/04-instance-sizing.md` ;
- `docs/phase-1-as-is/05-security-groups.md` ;
- `docs/adr/ADR-001-provider-network-fallback.md`.

## Diagnostic ayant déclenché la révision

La conception initiale multi-réseaux a échoué pendant M05 :

- cinq SG et leurs règles : créés ;
- quatre réseaux self-service : HTTP 503 ;
- routeur : HTTP 404 ;
- extension `router` absente ;
- aucun agent réseau visible ;
- Floating IP déjà en HTTP 404.

Aucun réseau ou routeur en échec n'est entré dans le state.

## Décisions révisées

- underlay unique `prive` (`172.28.0.0/16`) ;
- cinq ports Neutron, un par VM ;
- cinq SG par rôle comme frontières logiques ;
- K3s Flannel VXLAN pour `10.42.0.0/16` ;
- Services Kubernetes sur `10.43.0.0/16` ;
- NodePort 30080/30443 accessible uniquement depuis le bastion ;
- aucun réseau, sous-réseau, routeur, Floating IP ou Octavia.

## Conformité

- dimensionnement inchangé : 5 instances, 9 vCPU, 17 Go ;
- ports : 5 sur quota 500 ;
- SG : 8 utilisés sur quota 10 ;
- règles : sous quota 100 ;
- réseau externe lu, jamais géré ;
- limites du lab visibles, non masquées.

## Validation documentaire

```bash
rg -n 'provider-network|cinq ports|Flannel|NodePort' \
  docs/phase-1-as-is/03-network-design.md
rg -n 'HTTP 503|HTTP 404|security groups' \
  docs/adr/ADR-001-provider-network-fallback.md
git diff --check
```

## Tests différés

La validation effective des ports et flux nécessite :

1. un plan M05 sans destruction ;
2. l'apply explicite de l'utilisateur ;
3. les VMs M06 attachées aux ports ;
4. des tests réseau positifs et négatifs.

## Conclusion

M04 reste terminée avec une révision traçable. M05 peut reprendre sur la
topologie provider-network-only. La référence entreprise segmentée reste
distincte du lab.
