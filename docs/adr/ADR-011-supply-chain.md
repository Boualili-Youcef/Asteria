# ADR-011 — Standardiser la supply chain GitHub/GHCR/Sigstore

- **Statut :** accepté
- **Date :** 2026-08-30
- **Portée :** phase 2, T03 puis T12/T13/T17

## Contexte

Les workflows sont fragmentés, les actions utilisent des tags majeurs et aucun
scan, SBOM, signature ou provenance n'est systématique.

## Décision

- un workflow GitHub Actions réutilisable exécute tests, lint, scan de secrets,
  dépendances et image, puis génère SBOM SPDX/CycloneDX et provenance ;
- les actions et outils sont épinglés par SHA/version immuable ;
- une image est publiée une fois dans GHCR et promue par digest ;
- Cosign keyless utilise l'identité OIDC du workflow ; la vérification impose
  repository, workflow et issuer attendus, pas seulement une signature valide ;
- les résultats et exceptions sont publiés avec rétention et propriétaire ;
- Kyverno bloque en phase enforce les artefacts sans provenance approuvée après
  une période audit mesurée.

## Alternatives et conséquences

Des clés Cosign permanentes ajoutent un secret critique à gérer. Un autre
registre ou moteur CI n'apporte pas de preuve supplémentaire aujourd'hui.
L'échec d'un service existant commence en avertissement seulement si une
exception datée est approuvée ; une vulnérabilité critique exploitable bloque.

## Rollback et validation

Rollback de release par digest antérieur déjà vérifié, jamais par reconstruction
d'un ancien tag. Tests : trois services passent les mêmes gates ; action non
épinglée, image inconnue et identité Sigstore incorrecte sont refusées ; digest
approuvé, GitOps et runtime sont identiques.

Traite `ASIS-013`, `ASIS-014`, `ASIS-015` et `REQ-SEC-006`, `REQ-SEC-007`,
`REQ-SVC-008`.

## Source

- [Sigstore — signature keyless avec Cosign](https://docs.sigstore.dev/cosign/signing/signing_with_containers/)
