# Preuve M00 — Dépôt et pilotage initialisés

## Métadonnées

- **Date :** 2026-07-14
- **Mission :** M00
- **Résultat :** validé

## Objectif

Initialiser le dépôt Asteria, créer son arborescence de travail et formaliser le
contexte, les règles des agents et le backlog de la phase 1.

## Livrables vérifiés

- `README.md` ;
- `PROJECT_CONTEXT.md` ;
- `AGENTS.md` ;
- `PHASE_1_BACKLOG.md` ;
- `.gitignore` ;
- arborescence `docs/`, `infra/`, `ansible/`, `apps/`, `k8s/`,
  `ci/`, `monitoring/` et `scripts/` ;
- fichiers `.gitkeep` pour conserver les répertoires encore vides ;
- dépôt Git local initialisé sur la branche `main`.

## Commandes de validation

```bash
git init -b main
git status --short --branch
rg --files --hidden -g '!.git/**'
rg -n '`|TODO|TBD' README.md PROJECT_CONTEXT.md AGENTS.md PHASE_1_BACKLOG.md
wc -l README.md PROJECT_CONTEXT.md AGENTS.md PHASE_1_BACKLOG.md
git diff --cached --check
```

## Résultats utiles

- Git indique `No commits yet on main` après son initialisation ;
- tous les fichiers de référence existants et les nouveaux livrables sont
  visibles dans le worktree ;
- aucun marqueur `TODO`, `TBD` ou caractère de substitution ne subsiste dans
  les quatre documents de pilotage ;
- les documents de pilotage représentent 611 lignes avant cette preuve ;
- aucune commande OpenStack ni création de ressource distante n'a été lancée.

## Décision de baseline

La baseline actuelle reste celle du diagramme validé : 5 instances, 9 vCPU et
17 Go de RAM. Le troisième worker évoqué dans le cadrage reste une option à
arbitrer pendant M03 à partir des quotas OpenStack réellement observés.

## Écarts

Aucun écart bloquant. `git diff --cached --check` signale un espace final déjà
présent dans le matériau initial `contexte.md` à la ligne 672. Ce fichier source
n'a pas été réécrit pendant M00 afin d'en préserver le contenu. Les répertoires
applicatifs et d'infrastructure sont volontairement vides à ce stade, car leur
contenu appartient aux missions ultérieures.

## Conclusion

Les critères d'acceptation de M00 sont satisfaits. M01 peut commencer. Aucune
ressource OpenStack n'a été créée ou modifiée.
