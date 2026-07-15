# Preuve M04 — Conception réseau approuvée

## Métadonnées

- **Date :** 2026-07-15
- **Mission :** M04
- **Résultat :** validé

## Objectif

Définir le plan réseau, le dimensionnement et les flux avant toute création de
ressources.

## Livrables

- `docs/phase-1-as-is/03-network-design.md` ;
- `docs/phase-1-as-is/04-instance-sizing.md` ;
- `docs/phase-1-as-is/05-security-groups.md`.

## Décisions validées

- quatre réseaux internes dans `10.20.0.0/16` ;
- `prive` référencé comme réseau externe existant et non géré ;
- routeur unique connecté aux quatre sous-réseaux ;
- NodePort privé 30080/30443 accessible uniquement depuis le bastion ;
- cinq security groups Asteria ;
- image `ubuntu24.04` et flavors `normale`/`puissante` ;
- baseline de cinq instances, 9 vCPU et 17 Go.

## Validation

```bash
python3 -c 'import ipaddress; n=[ipaddress.ip_network(x) for x in ["172.28.0.0/16","10.20.10.0/24","10.20.20.0/24","10.20.30.0/24","10.20.40.0/24","10.42.0.0/16","10.43.0.0/16"]]; assert all(not a.overlaps(b) for i,a in enumerate(n) for b in n[i+1:]); print("CIDR_OK")'
rg -n '30080|30443|6443|10250|8472|5432' \
  docs/phase-1-as-is/05-security-groups.md
git diff --check
```

Résultats attendus :

- `CIDR_OK` ;
- chaque port apparaît avec une source, une destination et une justification ;
- aucune erreur de format Git.

## Conformité à M03

- aucun chevauchement avec `172.28.0.0/16` ;
- deux workers seulement ;
- aucun usage de Floating IP ou Octavia ;
- cinq nouveaux SG maintiennent le total nominal sous dix ;
- les informations non observées restent des prérequis d'apply.

## Écarts

La consommation actuelle des quotas et des règles n'est pas connue. Ce point ne
bloque pas la conception, mais bloque tout apply non précédé d'un nouvel
inventaire.

## Conclusion

Le design M04 est suffisamment précis pour être traduit en Terraform. Aucune
ressource OpenStack n'a été créée ou modifiée.
