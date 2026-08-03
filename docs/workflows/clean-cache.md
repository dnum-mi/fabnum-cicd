# `clean-cache.yml`

Nettoyage du cache GitHub Actions et des images GHCR (GitHub Container Registry).

## Inputs

| Input                     | Type    | Description                                                                            | Requis | Défaut             |
| ------------------------- | ------- | -------------------------------------------------------------------------------------- | ------ | ------------------ |
| PR_NUMBER                 | number  | Numéro de la pull request associée au cache                                            | Non    | -                  |
| BRANCH_NAME               | string  | Nom de la branche associée au cache                                                    | Non    | -                  |
| IMAGE                     | string  | Nom de l'image à supprimer de ghcr.io (ex: `ghcr.io/owner/repo/service:pr-123`)        | Non    | -                  |
| CLEAN_GH_CACHE            | boolean | Nettoyer le cache GitHub Actions                                                       | Non    | `true`             |
| CLEAN_GHCR_IMAGE          | boolean | Supprimer l'image spécifiée de ghcr.io                                                 | Non    | `false`            |
| CLEAN_ORPHANED_GHCR_IMAGE | boolean | Supprimer les images dont tous les tags sont de type SHA (orphelines) de ghcr.io       | Non    | `false`            |
| RUNS_ON                   | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description                    |
| -------- | ----- | ------------------------------ |
| packages | write | Supprimer les images de GHCR   |
| actions  | write | Supprimer les entrées de cache |

## Notes

- Le nettoyage du cache GitHub Actions nécessite soit `PR_NUMBER` soit `BRANCH_NAME`.
- Une image est considérée comme orpheline lorsque **tous** ses tags restants ressemblent à un SHA git (7 à 40 caractères hexadécimaux) : un tag mobile comme `pr-<N>` ou un nom de branche a été réassigné à un build plus récent, et plus rien de significatif (branche, PR, semver, `latest`) ne la maintient en vie.
- Si l'image orpheline est une manifest list multi-arch, les images par plateforme qu'elle référence (jamais taguées elles-mêmes) sont également supprimées pour éviter qu'elles restent orphelines indéfiniment.
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@v0
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@v0
    with:
      BRANCH_NAME: ${{ github.event.ref }}
      CLEAN_GH_CACHE: true
```

### Nettoyer uniquement les images orphelines

```yaml
jobs:
  cleanup-orphaned:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@v0
    with:
      CLEAN_GH_CACHE: false
      CLEAN_ORPHANED_GHCR_IMAGE: true
```
