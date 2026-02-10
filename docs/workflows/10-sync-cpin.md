# `sync-cpin.yml`

Synchronisation avec l'instance GitLab CPiN (Cloud Pi Natif) pour déclencher des pipelines de déploiement.

## Inputs

| Input                 | Type    | Description                                                                                  | Requis | Défaut             |
| --------------------- | ------- | -------------------------------------------------------------------------------------------- | ------ | ------------------ |
| GITLAB_URL            | string  | URL de l'instance GitLab CPiN                                                                | Oui    | -                  |
| GIT_MIRROR_PROJECT_ID | string  | ID du projet GitLab du dépôt miroir                                                          | Oui    | -                  |
| BRANCH_TO_SYNC        | string  | Branche Git à synchroniser                                                                   | Non    | -                  |
| SYNC_ALL              | boolean | Synchroniser toutes les branches au lieu d'une seule                                         | Non    | `false`            |
| REPOSITORY_NAME       | string  | Nom du dépôt GitLab à synchroniser                                                           | Oui    | -                  |
| ADDITIONAL_VARIABLES  | string  | Variables supplémentaires à passer au pipeline GitLab (format JSON, ex: `{"VAR1":"value1"}`) | Non    | -                  |
| RUNS_ON               | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)       | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret           | Description                                            | Requis |
| ---------------- | ------------------------------------------------------ | ------ |
| GIT_MIRROR_TOKEN | Token GitLab utilisé pour effectuer la synchronisation | Oui    |

## Notes

- Déclenche un pipeline GitLab sur l'instance CPiN pour synchroniser le code depuis GitHub.
- Passe automatiquement les informations de branche, commit SHA et nom du projet.
- Permet d'ajouter des variables personnalisées au format JSON pour configurer le pipeline.
- **Mode SYNC_ALL** : Si activé, synchronise toutes les branches au lieu d'une seule (passe `SYNC_ALL=true` à GitLab au lieu de `GIT_BRANCH_DEPLOY`)
- Supprime automatiquement les trailing slashes de `GITLAB_URL` pour éviter les erreurs d'URL
- Utile pour les organisations qui utilisent à la fois GitHub et GitLab CPiN.
- Le pipeline GitLab doit être configuré pour accepter les triggers avec token.

## Exemples

### Exemple simple

```yaml
name: Sync to CPiN

on:
  push:
    branches:
    - main
    - develop

jobs:
  sync:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    with:
      GITLAB_URL: https://gitlab.cpin.example.com
      GIT_MIRROR_PROJECT_ID: "12345"
      BRANCH_TO_SYNC: ${{ github.ref_name }}
      REPOSITORY_NAME: my-app
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_GITLAB_TOKEN }}
```

### Avec variables supplémentaires

```yaml
jobs:
  sync:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    with:
      GITLAB_URL: https://gitlab.cpin.example.com
      GIT_MIRROR_PROJECT_ID: "12345"
      BRANCH_TO_SYNC: ${{ github.ref_name }}
      REPOSITORY_NAME: my-app
      ADDITIONAL_VARIABLES: '{"ENVIRONMENT":"production","DEPLOY_TYPE":"blue-green"}'
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_GITLAB_TOKEN }}
```

### Synchronisation après une release

```yaml
name: Release and Sync

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  sync:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    with:
      GITLAB_URL: https://gitlab.cpin.example.com
      GIT_MIRROR_PROJECT_ID: "12345"
      BRANCH_TO_SYNC: ${{ format('v{0}', needs.release.outputs.version) }}
      REPOSITORY_NAME: my-app
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_GITLAB_TOKEN }}
```

### Synchronisation de toutes les branches

```yaml
jobs:
  sync-all:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    with:
      GITLAB_URL: https://gitlab.cpin.example.com
      GIT_MIRROR_PROJECT_ID: "12345"
      SYNC_ALL: true
      REPOSITORY_NAME: my-app
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_GITLAB_TOKEN }}
```

      REPOSITORY_NAME: my-app
      ADDITIONAL_VARIABLES: '{"VERSION":"${{ needs.release.outputs.version }}"}'
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_GITLAB_TOKEN }}
```
