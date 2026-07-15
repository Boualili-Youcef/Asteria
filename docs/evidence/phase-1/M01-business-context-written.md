# Preuve M01 — Contexte métier documenté

## Métadonnées

- **Date :** 2026-07-15
- **Mission :** M01
- **Résultat :** validé

## Objectif

Rendre le scénario métier compréhensible sans utiliser l'historique de
conversation comme source obligatoire.

## Livrable

`docs/phase-1-as-is/00-business-context.md` décrit :

- l'entreprise et sa taille ;
- le produit SaaS B2B représenté ;
- le choix d'un cloud OpenStack privé ;
- les équipes et responsabilités ;
- l'état actuel et les irritants ;
- le mandat du futur Platform Engineer ;
- les faits validés et les éléments volontairement non définis.

## Validation effectuée

Comparaison documentaire avec :

- `PROJECT_CONTEXT.md`, sections 1 à 8 ;
- `archi.md`, acteurs, composants, flux et dettes AS-IS.

Contrôles utilisés :

```bash
rg -n '^## ' docs/phase-1-as-is/00-business-context.md
rg -n '100 à 500|OpenStack|identity-api|orders-api|notifications-worker|Platform Engineer' \
  docs/phase-1-as-is/00-business-context.md
git diff --check
```

## Résultat

- la taille, la clientèle B2B et le choix OpenStack correspondent aux sources ;
- les responsabilités décrites correspondent aux acteurs du diagramme ;
- les trois services et leurs dépendances correspondent à l'architecture ;
- les dettes sont conservées et aucune solution TO-BE n'est introduite ;
- le secteur commercial non défini est explicitement présenté comme tel.

## Écart

Aucun écart bloquant identifié.

## Conclusion

Le contexte métier est autonome et cohérent avec les sources de vérité. Les
critères de M01 sont satisfaits et M02 peut commencer.
