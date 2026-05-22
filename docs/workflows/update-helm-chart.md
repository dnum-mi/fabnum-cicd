# `update-helm-chart.yml`

Mise à jour automatique de la version d'un chart Helm et de l'appVersion dans Chart.yaml.

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                                                                               | Requis | Défaut                   |
| --------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------ |
| RUN_MODE              | string | Mode d'exécution : `caller` déclenche le workflow dans le dépôt chart séparé, `called` met à jour le chart dans le dépôt actuel et crée une PR, `local` met à jour le chart dans le dépôt actuel et amende directement la branche release-please courante | Oui    | -                        |
| WORKFLOW_NAME         | string | Nom du workflow à déclencher dans le dépôt chart (ex: `update-chart.yml`)                                                                                                                                                                                 | Non    | `update-app-version.yml` |
| CHART_REPO            | string | Nom du dépôt chart (ex: `this-is-tobi/helm-charts`)                                                                                                                                                                                                       | Non    | -                        |
| CHART_DIR             | string | Nom du dossier contenant le chart (dans CHART_REPO)                                                                                                                                                                                                       | Non    | `charts`                 |
| CHART_NAME            | string | Nom du dossier contenant le chart (dans CHART_DIR)                                                                                                                                                                                                        | Oui    | -                        |
| APP_VERSION           | string | La version de l'application à injecter dans Chart.yaml                                                                                                                                                                                                    | Oui    | -                        |
| UPGRADE_TYPE          | string | Type de mise à jour : `major`, `minor`, `patch` ou `prerelease`                                                                                                                                                                                           | Non    | `patch`                  |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release (utilisé seulement si UPGRADE_TYPE est `prerelease`)                                                                                                                                                                           | Non    | `rc`                     |
| AUTOMERGE_PRERELEASE  | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` est `prerelease` (nécessite `GH_PAT`)                                                                                                                                                          | Non    | `false`                  |
| AUTOMERGE_RELEASE     | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` n'est pas `prerelease` (nécessite `GH_PAT`)                                                                                                                                                    | Non    | `false`                  |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                    | Non    | `["ubuntu-24.04"]`       |

## Secrets

| Secret | Description                                                             | Requis |
| ------ | ----------------------------------------------------------------------- | ------ |
| GH_PAT | Personal Access Token GitHub (nécessaire pour déclencher des workflows) | Non    |

## Permissions

| Scope         | Accès | Description                                         |
| ------------- | ----- | --------------------------------------------------- |
| pull-requests | write | Créer des PRs pour les mises à jour (mode `called`) |
| contents      | write | Modifier les fichiers Chart.yaml (mode `called`)    |

## Notes

### Modes de fonctionnement (`RUN_MODE`)

| Mode     | Utilisation                                                                                   | Comportement                                                                                                                                                     |
| -------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `caller` | Le dépôt applicatif veut mettre à jour un chart dans un **dépôt chart séparé**                | Déclenche le workflow `WORKFLOW_NAME` dans `CHART_REPO` via `workflow_dispatch`. Nécessite `GH_PAT`.                                                             |
| `called` | Le dépôt chart reçoit l'appel de `caller` et effectue la mise à jour                          | Met à jour `Chart.yaml` et le README, puis crée une Pull Request. Supporte l'automerge.                                                                          |
| `local`  | Le chart est dans le **même dépôt** que l'application, avec une branche release-please active | Met à jour `Chart.yaml` et le README, puis amende le dernier commit de la branche `release-please--branches--<branche-courante>` et force-push. Aucune PR créée. |

> **Quand utiliser `local` ?** Lorsque le chart Helm est hébergé dans le même dépôt que l'application et que release-please gère déjà une PR de release. Le mode `local` injecte les mises à jour du chart directement dans cette PR au lieu d'en créer une seconde.

### Autres comportements

- Deux modes de fonctionnement :
  - **caller** : Déclenche le workflow de mise à jour dans un dépôt chart séparé
  - **called** : Effectue la mise à jour directement dans le dépôt actuel
  - **local** : Amende la branche release-please courante directement
- Met à jour automatiquement `appVersion` dans Chart.yaml avec la version fournie.
- Incrémente la version du chart selon le type de mise à jour spécifié.
- **Logique prerelease** : 
  - Si la version actuelle est stable (ex: `0.2.0`), passe à la version prerelease suivante en incrémentant le patch (ex: `0.2.1-rc`)
  - Si la version actuelle est déjà une prerelease sans numéro (ex: `0.2.1-rc`), ajoute `.1` (ex: `0.2.1-rc.1`)
  - Si la version actuelle a un numéro de prerelease (ex: `0.2.1-rc.1`), l'incrémente (ex: `0.2.1-rc.2`)
  - **Changement d'identifiant** : Si l'identifiant actuel est différent de celui demandé (ex: `1.0.0-alpha.2` avec identifier `beta`), remplace par le nouvel identifiant sans numéro (ex: `1.0.0-beta`)
- **Logique standard (major/minor/patch)** :
  - Si la version actuelle est une prerelease (ex: `1.2.3-rc.1`), publie d'abord la version officielle (ex: `1.2.3`)
  - Si la version actuelle est stable, applique le bump classique (major/minor/patch)
- Crée une pull request avec les changements.
- **Automerge (mode `called`)** : Si `AUTOMERGE_PRERELEASE: true` (quand `UPGRADE_TYPE: prerelease`) ou `AUTOMERGE_RELEASE: true` (sinon), et qu'un `GH_PAT` est fourni, tente de fusionner la PR automatiquement :
  - Si le dépôt a l'option *Allow auto-merge* activée, utilise `--auto` (merge déclenché après passage des checks).
  - Sinon, utilise `--admin` pour forcer le merge immédiatement.
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  update-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    with:
      RUN_MODE: caller
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor
      AUTOMERGE_PRERELEASE: true
      AUTOMERGE_RELEASE: false
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
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

### Changement d'identifiant de pré-release (alpha -> beta)

```yaml
jobs:
  # Passage de alpha à beta (ex: 1.2.3-alpha.2 -> 1.2.3-beta)
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    with:
      RUN_MODE: caller
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: 1.2.3-beta.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: beta  # Different from current 'alpha'
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Mode local — chart dans le même dépôt que l'application

Utiliser `local` quand le chart Helm est dans le même dépôt et que release-please gère déjà une branche de release. Le workflow retrouve automatiquement la branche `release-please--branches--<branche-courante>` et y amende le commit existant.

```yaml
name: Update Helm Chart on Release

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  update-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

> **Prérequis** : Une branche `release-please--branches--<branche-courante>` doit exister au moment de l'exécution. Si aucune branche release-please n'est trouvée, le step est ignoré sans erreur.

