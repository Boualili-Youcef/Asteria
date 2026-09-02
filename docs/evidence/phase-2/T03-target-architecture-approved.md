# Preuve T03 — Architecture cible et ADR approuvées

## Métadonnées

- **Date :** 2026-08-30
- **Mission :** T03
- **Statut :** terminée
- **Runtime modifié :** non

## Objectif et résultat

Transformer la proposition T00 en décisions compatibles avec T01 et T02.
Treize ADR, ADR-002 à ADR-014, approuvent les choix minimaux et leur stratégie
de migration. Le green de production candidat T00 est rejeté pour le lab ; le
second projet devient staging CAP-05 uniquement.

## Faits et hypothèses

Les faits de capacité viennent des deux inventaires authentifiés T02. Les
hypothèses restantes sont HYP-T03-01 à 05 dans
`09-target-architecture-decisions.md`. La cible S3 et la fenêtre de
reconstruction ne sont pas présentées comme acquises.

## Fichiers

- `docs/adr/ADR-002-*.md` à `ADR-014-*.md` ;
- `docs/phase-2-to-be/09-target-architecture-decisions.md` ;
- diagrammes entreprise et frontières mis à jour, plus
  `docs/diagrams/to-be-lab-approved.mmd` ;
- candidat T00 marqué comme historique ;
- cette preuve et le statut T03 du backlog.

## Validation documentaire

```bash
for id in $(seq -w 2 14); do
  test "$(find docs/adr -maxdepth 1 -name "ADR-0${id}-*.md" | wc -l)" -eq 1
done

rg -n 'Statut :.*accepté|Référence entreprise|lab|Rollback|ASIS-' \
  docs/adr/ADR-0{02,03,04,05,06,07,08,09,10,11,12,13,14}-*.md

rg -n 'CIBLE LAB APPROUVEE T03|staging CAP-05|pas de green' \
  docs/diagrams/to-be-lab-approved.mmd
```

Résultat attendu et observé après création : une ADR par ID 002-014, toutes
acceptées ; chaque domaine décrit adaptation lab, rollback et traçabilité ; le
diagramme ne revendique ni green complet, ni HA de zone, ni DR.

## Impact, sécurité et rollback

Aucun apply, paquet, VM, cluster, donnée ou trafic n'a été modifié. Le rollback
documentaire consiste à rouvrir une ADR avec de nouveaux faits, jamais à
réécrire silencieusement la décision acceptée.

## Conclusion

T03 est terminée. T04 est autorisée ; T05 reste interdite tant que les gates de
stabilisation T04 ne sont pas prouvés.
