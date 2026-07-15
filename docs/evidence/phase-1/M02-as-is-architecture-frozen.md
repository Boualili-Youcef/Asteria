# Preuve M02 — Architecture AS-IS figée

## Métadonnées

- **Date :** 2026-07-15
- **Mission :** M02
- **Résultat :** validé

## Objectif

Figer le diagramme de référence et expliquer les composants et les flux sans
introduire l'architecture cible.

## Livrables

- `docs/diagrams/as-is-architecture.mmd` ;
- `docs/phase-1-as-is/01-as-is-architecture.md` ;
- inventaire des flux utilisateurs, applicatifs, de livraison,
  d'administration, de sécurité, d'observabilité et de sauvegarde.

## Validation effectuée

Le bloc Mermaid de `archi.md` a été extrait sans les fences Markdown. La
comparaison exacte est réalisée avec :

```bash
sed -n '2,140p' archi.md | diff -u - docs/diagrams/as-is-architecture.mmd
rg -n '^### 6\.' docs/phase-1-as-is/01-as-is-architecture.md
rg -n 'Référence d.entreprise|Implémentation réduite du lab' \
  docs/phase-1-as-is/01-as-is-architecture.md
git diff --check
```

## Résultat attendu et observé

- `diff` ne produit aucune différence ;
- les sept familles de flux sont inventoriées ;
- l'entreprise réelle et le lab sont décrits séparément ;
- la baseline reste à 5 instances, 9 vCPU et 17 Go ;
- les dettes AS-IS sont explicitement conservées ;
- aucune solution TO-BE n'a été ajoutée.

## Écart

Aucun écart bloquant identifié.

## Conclusion

L'architecture AS-IS est figée et expliquée. Les critères de M02 sont satisfaits
et l'inventaire OpenStack M03 peut commencer.

## Amendement après diagnostic Neutron — 2026-07-15

Le premier apply M05 a démontré que le tenant n'expose ni réseaux self-service
ni routeur L3. `archi.md`, le fichier Mermaid figé et l'explication AS-IS ont
été révisés conformément à ADR-001.

La référence entreprise segmentée est conservée, tandis que le lab utilise
`prive` comme underlay unique, des ports Neutron, cinq security groups et
l'overlay K3s. Le PDF racine est désormais historique.

Validation de la révision :

```bash
sed -n '2,$p' archi.md | sed '$d' | diff -u - \
  docs/diagrams/as-is-architecture.mmd
rg -n 'provider|security groups|Flannel|NodePort' \
  docs/phase-1-as-is/01-as-is-architecture.md
```
