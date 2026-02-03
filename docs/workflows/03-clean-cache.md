# `clean-cache.yml`

Nettoyage du cache GitHub Actions et des images GHCR (GitHub Container Registry).

## Inputs

| Input                     | Type    | Description                                                                     | Requis | Défaut  |
| ------------------------- | ------- | ------------------------------------------------------------------------------- | ------ | ------- |
| PR_NUMBER                 | number  | Numéro de la pull request associée au cache                                     | Non    | -       |
| BRANCH_NAME               | string  | Nom de la branche associée au cache                                             | Non    | -       |
| IMAGE                     | string  | Nom de l'image à supprimer de ghcr.io (ex: `ghcr.io/owner/repo/service:pr-123`) | Non    | -       |
| CLEAN_GH_CACHE            | boolean | Nettoyer le cache GitHub Actions                                                | Non    | `true`  |
| CLEAN_GHCR_IMAGE          | boolean | Supprimer l'image spécifiée de ghcr.io                                          | Non    | `false` |
| CLEAN_ORPHANED_GHCR_IMAGE | boolean | Supprimer les images orphelines (SHA uniquement) de ghcr.io                     | Non    | `false` |

## Permissions

| Scope    | Accès | Description                    |
| -------- | ----- | ------------------------------ |
| packages | write | Supprimer les images de GHCR   |
| contents | read  | Lire le dépôt                  |
| actions  | write | Supprimer les entrées de cache |

## Notes

- Le nettoyage du cache GitHub Actions nécessite soit `PR_NUMBER` soit `BRANCH_NAME`.
- Les images orphelines sont identifiées par des tags SHA uniquement (sans tags sémantiques).
- Utile pour libérer de l'espace de stockage et nettoyer les artefacts temporaires.
- Peut être déclenché automatiquement lors de la fermeture d'une PR ou manuellement.

## Exemples

### Nettoyer le cache d'une PR fermée

```yaml
name: Cleanup

on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@main
    with:
      PR_NUMBER: ${{ github.event.pull_request.number }}
      CLEAN_GH_CACHE: true
      CLEAN_GHCR_IMAGE: true
      IMAGE: ghcr.io/${{ github.repository }}/app:pr-${{ github.event.pull_request.number }}
```

### Nettoyer le cache d'une branche

```yaml
jobs:
  cleanup:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@main
    with:
      BRANCH_NAME: ${{ github.event.ref }}
      CLEAN_GH_CACHE: true
```

### Nettoyer uniquement les images orphelines

```yaml
jobs:
  cleanup-orphaned:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@main
    with:
      CLEAN_GH_CACHE: false
      CLEAN_ORPHANED_GHCR_IMAGE: true
```
