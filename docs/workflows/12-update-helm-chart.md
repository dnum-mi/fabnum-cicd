# `update-helm-chart.yml`

Mise à jour automatique de la version d'un chart Helm et de l'appVersion dans Chart.yaml.

## Inputs

| Input                 | Type   | Description                                                                                                                           | Requis | Défaut                   |
| --------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------ |
| RUN_MODE              | string | Mode d'exécution. `caller` pour déclencher le workflow dans le dépôt chart, `called` pour mettre à jour le chart dans le dépôt actuel | Oui    | -                        |
| WORKFLOW_NAME         | string | Nom du workflow à déclencher dans le dépôt chart (ex: `update-chart.yml`)                                                             | Non    | `update-app-version.yml` |
| CHART_REPO            | string | Nom du dépôt chart (ex: `this-is-tobi/helm-charts`)                                                                                   | Non    | -                        |
| CHART_DIR             | string | Nom du dossier contenant le chart (dans CHART_REPO)                                                                                   | Non    | `charts`                 |
| CHART_NAME            | string | Nom du dossier contenant le chart (dans CHART_DIR)                                                                                    | Oui    | -                        |
| APP_VERSION           | string | La version de l'application à injecter dans Chart.yaml                                                                                | Oui    | -                        |
| UPGRADE_TYPE          | string | Type de mise à jour : `major`, `minor`, `patch` ou `prerelease`                                                                       | Non    | `patch`                  |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release (utilisé seulement si UPGRADE_TYPE est `prerelease`)                                                       | Non    | `rc`                     |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                | Non    | `["ubuntu-24.04"]`       |

## Secrets

| Secret | Description                                                             | Requis |
| ------ | ----------------------------------------------------------------------- | ------ |
| GH_PAT | Personal Access Token GitHub (nécessaire pour déclencher des workflows) | Non    |

## Permissions

| Scope         | Accès | Description                                   |
| ------------- | ----- | --------------------------------------------- |
| pull-requests | write | Créer des PRs pour les mises à jour           |
| contents      | write | Modifier les fichiers Chart.yaml              |
| actions       | write | Déclencher des workflows dans d'autres dépôts |

## Notes

- Deux modes de fonctionnement :
  - **caller** : Déclenche le workflow de mise à jour dans un dépôt chart séparé
  - **called** : Effectue la mise à jour directement dans le dépôt actuel
- Met à jour automatiquement `appVersion` dans Chart.yaml avec la version fournie.
- Incrémente la version du chart selon le type de mise à jour spécifié.
- **Logique prerelease** : 
  - Si la version actuelle est stable (ex: `0.2.0`), passe à la version prerelease suivante en incrémentant le patch (ex: `0.2.1-rc`)
  - Si la version actuelle est déjà une prerelease sans numéro (ex: `0.2.1-rc`), ajoute `.1` (ex: `0.2.1-rc.1`)
  - Si la version actuelle a un numéro de prerelease (ex: `0.2.1-rc.1`), l'incrémente (ex: `0.2.1-rc.2`)
- Crée une pull request avec les changements.
- Régénère automatiquement la documentation du chart avec helm-docs.
- Utile pour synchroniser les versions d'application avec les versions de chart.
- Suit le versioning sémantique (semver).

## Exemples

### Mode caller - Déclencher la mise à jour dans un dépôt chart externe

```yaml
name: Update Chart

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  update-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    with:
      RUN_MODE: caller
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Mode called - Mise à jour dans le même dépôt

```yaml
name: Update Chart Version

on:
  workflow_dispatch:
    inputs:
      app_version:
        description: 'Application version'
        required: true
      upgrade_type:
        description: 'Upgrade type'
        required: true
        default: 'patch'
        type: choice
        options:
        - major
        - minor
        - patch
        - prerelease

jobs:
  update:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      APP_VERSION: ${{ inputs.app_version }}
      UPGRADE_TYPE: ${{ inputs.upgrade_type }}
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Mise à jour avec pré-release

```yaml
jobs:
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    with:
      RUN_MODE: caller
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: 1.2.3-rc.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: rc
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```
