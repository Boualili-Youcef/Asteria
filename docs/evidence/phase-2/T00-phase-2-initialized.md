# Preuve T00 — Phase 2 TO-BE initialisée

## Métadonnées

- **Date :** 2026-08-30
- **Mission :** T00
- **Statut :** réussi
- **Périmètre :** documentation et gouvernance uniquement

## Objectif

Ouvrir officiellement la transformation TO-BE après la clôture M16, proposer
une première architecture et construire un chemin guidé sans modifier le
runtime AS-IS.

## Prérequis vérifiés

- M00 à M16 sont `Terminée` dans `PHASE_1_BACKLOG.md` ;
- M16 contient 22 constats `ASIS-001` à `ASIS-022` avec impact et preuves ;
- le dépôt contient les livrables et preuves de la phase 1 ;
- l'utilisateur a explicitement approuvé le passage au TO-BE le 30 août 2026.

## Livrables

- `PHASE_2_BACKLOG.md` ;
- `docs/phase-2-to-be/00-transformation-charter.md` ;
- `docs/phase-2-to-be/01-target-architecture-proposal.md` ;
- `docs/phase-2-to-be/02-as-is-to-to-be-traceability.md` ;
- `docs/diagrams/to-be-enterprise-architecture.mmd` ;
- `docs/diagrams/to-be-lab-candidate.mmd` ;
- mise à jour de `PROJECT_CONTEXT.md`, `AGENTS.md` et `README.md`.

## Décisions

- le TO-BE est séparé de l'AS-IS et ne remplace pas `archi.md` ;
- l'architecture entreprise et l'adaptation lab possèdent deux diagrammes ;
- les choix technologiques T00 sont des candidats jusqu'aux ADR T03 ;
- le deuxième projet OpenStack n'a pas encore de rôle définitif ;
- aucune promesse de HA, DR, réseau ou stockage n'est faite avant T02 ;
- aucune modification OpenStack, Kubernetes, PostgreSQL ou GitHub n'appartient
  à T00.

## Couverture

La matrice de traçabilité comporte exactement une ligne pour chacun des 22
constats M16. Chaque ligne précise la réponse candidate, la mission principale
et un critère final observable.

## Validations

```bash
git diff --check
rg --count '^\| ASIS-[0-9]{3} ' \
  docs/phase-2-to-be/02-as-is-to-to-be-traceability.md
rg --files docs/phase-2-to-be docs/evidence/phase-2 docs/diagrams

docker run --rm -v "$PWD:/data" \
  ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:latest \
  -i /data/docs/diagrams/to-be-enterprise-architecture.mmd \
  -o /tmp/asteria-to-be-enterprise.svg

docker run --rm -v "$PWD:/data" \
  ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:latest \
  -i /data/docs/diagrams/to-be-lab-candidate.mmd \
  -o /tmp/asteria-to-be-lab.svg
```

Résultats observés le 30 août 2026 :

- `git diff --check` : succès, aucune erreur d'espacement ;
- constats M16 : 22 identifiants uniques `ASIS-001` à `ASIS-022` ;
- matrice TO-BE : 22 lignes, soit une réponse candidate par constat ;
- fichiers obligatoires T00 : tous présents ;
- diagramme entreprise : rendu SVG et PNG sans erreur Mermaid ;
- diagramme lab : rendu SVG et PNG sans erreur Mermaid ;
- inspection visuelle : zones, flux et légendes lisibles ;
- liens locaux : chemins des livrables T00 vérifiés dans le dépôt.

## Absence d'impact runtime

T00 n'exécute ni Terraform, ni Ansible distant, ni kubectl, ni migration de
données. Les modifications locales préexistantes de `archi.md`, du diagramme
AS-IS, du candidat dual-project et de la synthèse M00-M09 restent hors du
périmètre T00 et ne doivent pas être intégrées à son commit.

## Conclusion

T00 initialise une phase 2 guidée par les risques et les preuves. La prochaine
mission autorisée est T01 : définir les objectifs de service, RTO/RPO et le
modèle de menace avant toute décision technique définitive.
