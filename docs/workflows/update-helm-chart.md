# `update-helm-chart.yml`

Mise à jour automatique de la version d'un chart Helm et de l'`appVersion` dans `Chart.yaml`.

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                                                                                                                                          | Requis | Défaut                   |
| --------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------ |
| RUN_MODE              | string | Mode d'exécution : `caller` déclenche le workflow dans un dépôt chart séparé, `called` met à jour le chart dans le dépôt actuel via une Pull Request, `local` met à jour le chart et commit directement sur la branche courante (pipelines monorepo - la nouvelle version est exposée via l'output `chart-version`). | Oui    | -                        |
| WORKFLOW_NAME         | string | Nom du workflow à déclencher dans le dépôt chart (ex: `update-chart.yml`)                                                                                                                                                                                                                                            | Non    | `update-app-version.yml` |
| CHART_REPO            | string | Nom du dépôt chart (ex: `this-is-tobi/helm-charts`)                                                                                                                                                                                                                                                                  | Non    | -                        |
| CHART_DIR             | string | Nom du dossier contenant le chart (dans CHART_REPO)                                                                                                                                                                                                                                                                  | Non    | `charts`                 |
| CHART_NAME            | string | Nom du chart à mettre à jour (dans CHART_DIR)                                                                                                                                                                                                                                                                        | Oui    | -                        |
| APP_VERSION           | string | Version de l'application à injecter dans `Chart.yaml` (`appVersion`). Laisser vide pour conserver l'`appVersion` actuelle - une release "chart-only" où seule la version du chart évolue.                                                                                                                            | Non    | `""`                     |
| UPGRADE_TYPE          | string | Type de mise à jour : `major`, `minor`, `patch` ou `prerelease`                                                                                                                                                                                                                                                      | Non    | `patch`                  |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release (utilisé seulement si UPGRADE_TYPE est `prerelease`)                                                                                                                                                                                                                                      | Non    | `rc`                     |
| HELM_DOCS_VERSION     | string | Version de helm-docs utilisée pour régénérer le README du chart (ex: `v1.14.2`). Épinglée plutôt que `:latest`, pour qu'une nouvelle release amont ne change pas silencieusement ce que le job exécute sur votre chart.                                                                                              | Non    | `v1.14.2`                |
| AUTOMERGE_PRERELEASE  | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` est `prerelease` (nécessite `APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`)                                                                                                                                                                                | Non    | `false`                  |
| AUTOMERGE_RELEASE     | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` n'est pas `prerelease` (nécessite `APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`)                                                                                                                                                                          | Non    | `false`                  |
| AUTOMERGE_METHOD      | string | Méthode de fusion de la PR de mise à jour du chart quand l'automerge est activé : `auto` (file d'attente, nécessite *Allow auto-merge*) ou `admin` (fusion immédiate en contournant la protection de branche)                                                                                                        | Non    | `auto`                   |
| BASE_BRANCH           | string | Branche de base contre laquelle ouvrir la Pull Request de mise à jour du chart (mode `called`)                                                                                                                                                                                                                       | Non    | `main`                   |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                                               | Non    | `["ubuntu-24.04"]`       |

## Secrets

| Secret            | Description                                                                                                                                       | Requis |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| APP_CLIENT_ID      | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour authentifier comme une App — prend le pas sur `GH_PAT`. Requis (avec `APP_PRIVATE_KEY`) ou `GH_PAT` en mode `caller`, et pour l'automerge dans tous les modes. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY    | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                    | Non    |
| GH_PAT             | Personal Access Token GitHub. Alternative historique à `APP_CLIENT_ID`/`APP_PRIVATE_KEY`, toujours supportée mais l'authentification App est préférée. | Non    |

## Outputs

| Output                 | Description                                          | Disponibilité           |
| ---------------------- | ---------------------------------------------------- | ----------------------- |
| chart-version          | Nouvelle version du chart calculée par le bump       | modes `called`/`local`  |
| previous-chart-version | Version du chart avant le bump                       | modes `called`/`local`  |
| commit-sha             | SHA du commit de bump poussé sur la branche courante | mode `local` uniquement |

## Permissions

| Scope         | Accès | Description                                                                      |
| ------------- | ----- | -------------------------------------------------------------------------------- |
| pull-requests | write | Créer des PRs pour les mises à jour (mode `called`)                              |
| contents      | write | Modifier les fichiers Chart.yaml et pousser les commits (modes `called`/`local`) |

## Notes

### Modes de fonctionnement (`RUN_MODE`)

| Mode     | Utilisation                                                                                 | Comportement                                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `caller` | Le dépôt applicatif veut mettre à jour un chart dans un **dépôt chart séparé**              | Déclenche le workflow `WORKFLOW_NAME` dans `CHART_REPO` via `workflow_dispatch`. Nécessite `APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT` - `GITHUB_TOKEN` ne peut pas dispatcher un workflow dans un autre dépôt. En mode App, le token est réduit au dépôt `CHART_REPO` uniquement (l'App doit y être installée). |
| `called` | Le dépôt chart reçoit l'appel de `caller` et effectue la mise à jour                        | Met à jour `Chart.yaml` et le README, puis crée une Pull Request contre `BASE_BRANCH`. Supporte l'automerge.                                           |
| `local`  | Le chart est dans le **même dépôt** que l'application (monorepo), pipeline CI/CD applicatif | Met à jour `Chart.yaml` et le README, commit et pousse directement sur la branche courante (`git push origin HEAD:$GITHUB_REF_NAME`). Aucune PR créée. |

> **Quand utiliser `local` ?** Lorsque le chart Helm est hébergé dans le même dépôt que l'application, généralement enchaîné après [`release-app.yml`](./release-app.md) pour committer le bump de version directement sur la branche qui vient d'être libérée, avant d'appeler [`release-helm.yml`](./release-helm.md) en mode `local` avec l'output `commit-sha`.

### Autres comportements

- **Release "chart-only"** : si `APP_VERSION` est laissé vide, l'`appVersion` du chart n'est pas modifiée - seule la version du chart est incrémentée. Utile pour publier un changement du chart lui-même (templates, values...) sans changement applicatif.
- Incrémente la version du chart selon le type de mise à jour spécifié.
- **Logique prerelease** :
  - Si la version actuelle est stable (ex: `0.2.0`), passe à la version prerelease suivante en incrémentant le patch (ex: `0.2.1-rc`)
  - Si la version actuelle est déjà une prerelease sans numéro (ex: `0.2.1-rc`), ajoute `.1` (ex: `0.2.1-rc.1`)
  - Si la version actuelle a un numéro de prerelease (ex: `0.2.1-rc.1`), l'incrémente (ex: `0.2.1-rc.2`)
  - **Changement d'identifiant** : Si l'identifiant actuel est différent de celui demandé (ex: `1.0.0-alpha.2` avec identifier `beta`), remplace par le nouvel identifiant sans numéro (ex: `1.0.0-beta`)
- **Logique standard (major/minor/patch)** :
  - Si la version actuelle est une prerelease (ex: `1.2.3-rc.1`), publie d'abord la version officielle (ex: `1.2.3`)
  - Si la version actuelle est stable, applique le bump classique (major/minor/patch)
- **Mode `local`** : commit et push directement sur `$GITHUB_REF_NAME`, avec un `git pull --rebase` préalable pour tolérer les push concurrents d'autres jobs du même pipeline. Les push authentifiés avec `GITHUB_TOKEN` ne redéclenchent jamais de nouveau workflow (anti-récursion GitHub), ce qui permet d'enchaîner un job de release du chart dans le même run en toute sécurité.
- **Automerge (mode `called`)** : Si `AUTOMERGE_PRERELEASE: true` (quand `UPGRADE_TYPE: prerelease`) ou `AUTOMERGE_RELEASE: true` (sinon), tente de fusionner la PR automatiquement selon `AUTOMERGE_METHOD` :
  - `auto` (défaut) : met la PR en file d'attente, GitHub la fusionne une fois les checks requis passés. Nécessite *Allow auto-merge* activé sur le dépôt.
  - `admin` : fusionne immédiatement, en contournant la protection de branche et les checks requis.
  - Sans credential (`APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`) fourni, le job échoue plutôt que de silencieusement ne rien fusionner. Voir [`authentication.md`](./authentication.md#automerge).
- La documentation du chart est régénérée avec la version de helm-docs fixée par `HELM_DOCS_VERSION`.
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
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

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
      AUTOMERGE_METHOD: auto
    secrets:
      # Requires the App to also be installed on CHART_REPO (my-org/helm-charts).
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

> En mode `caller`, l'App doit être installée sur le dépôt `CHART_REPO`, pas sur le dépôt qui exécute ce job. Voir [`authentication.md`](./authentication.md#dispatch-cross-repository-update-helm-chart-mode-caller).

### Mode called - Mise à jour dans le même dépôt via Pull Request

```yaml
name: Update Chart Version

on:
  workflow_dispatch:
    inputs:
      app_version:
        description: Application version
        required: true
      upgrade_type:
        description: Upgrade type
        required: true
        default: patch
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
      BASE_BRANCH: main
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Release "chart-only" (sans changement applicatif)

```yaml
jobs:
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      UPGRADE_TYPE: patch
      # APP_VERSION omis : seule la version du chart est incrémentée
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
      PRERELEASE_IDENTIFIER: beta # Different from current 'alpha'
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Mode local — chart dans un monorepo, enchaîné avec release-helm.yml

Utiliser `local` quand le chart Helm est dans le même dépôt que l'application. Le workflow commit et pousse directement la mise à jour du chart sur la branche courante, puis expose `chart-version` et `commit-sha` pour les jobs suivants (par exemple pour packager et publier le chart via [`release-helm.yml`](./release-helm.md) en mode `local`).

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
    permissions:
      contents: write
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor

  release-chart:
    needs:
    - release
    - update-chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      packages: write
    with:
      MODE: local
      CHART_NAME: my-app
      CHART_VERSION: ${{ needs.update-chart.outputs.chart-version }}
      APP_VERSION: ${{ needs.release.outputs.version }}
      CHECKOUT_REF: ${{ needs.update-chart.outputs.commit-sha }}
```
