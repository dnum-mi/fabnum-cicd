# `update-helm-chart.yml`

Mise à jour automatique de la version d'un chart Helm et de l'`appVersion` dans `Chart.yaml`, **dans le dépôt qui appelle le workflow**.

> Pour mettre à jour un chart hébergé dans un **dépôt séparé**, c'est [`dispatch-helm-chart.yml`](./dispatch-helm-chart.md) qu'il faut appeler : il déclenche le workflow d'entrée du dépôt chart, qui appelle celui-ci de son côté.

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                                             | Requis | Défaut             |
| --------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| RUN_MODE              | string | Mode de livraison du bump : `called` ouvre une Pull Request contre `BASE_BRANCH`, `local` commit directement sur la branche courante (pipelines monorepo - la nouvelle version et le SHA du commit sont exposés en outputs). | Oui    | -                  |
| CHART_NAME            | string | Nom du chart à mettre à jour (dans CHART_DIR)                                                                                                                                                                          | Oui    | -                  |
| CHART_DIR             | string | Nom du dossier contenant le chart                                                                                                                                                                                      | Non    | `charts`           |
| APP_VERSION           | string | Version de l'application à injecter dans `Chart.yaml` (`appVersion`). Laisser vide pour conserver l'`appVersion` actuelle - une release "chart-only" où seule la version du chart évolue.                              | Non    | `""`               |
| UPGRADE_TYPE          | string | Type de mise à jour : `major`, `minor`, `patch` ou `prerelease`                                                                                                                                                        | Non    | `patch`            |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release (utilisé seulement si UPGRADE_TYPE est `prerelease`)                                                                                                                                        | Non    | `rc`               |
| HELM_DOCS_VERSION     | string | Version de helm-docs utilisée pour régénérer le README du chart (ex: `v1.14.2`). Épinglée plutôt que `:latest`, pour qu'une nouvelle release amont ne change pas silencieusement ce que le job exécute sur votre chart. | Non    | `v1.14.2`          |
| AUTOMERGE_PRERELEASE  | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` est `prerelease` (mode `called` ; nécessite `APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`)                                                                  | Non    | `false`            |
| AUTOMERGE_RELEASE     | bool   | Fusionner automatiquement la PR créée quand `UPGRADE_TYPE` n'est pas `prerelease` (mode `called` ; nécessite `APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`)                                                            | Non    | `false`            |
| AUTOMERGE_METHOD      | string | Méthode de fusion de la PR quand l'automerge est activé : `auto` (file d'attente, nécessite *Allow auto-merge*) ou `admin` (fusion immédiate en contournant la protection de branche)                                   | Non    | `auto`             |
| BASE_BRANCH           | string | Branche de base contre laquelle ouvrir la Pull Request de mise à jour du chart (mode `called`)                                                                                                                          | Non    | `main`             |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                 | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret          | Description                                                                                                                                                                                                                                        | Requis |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| APP_CLIENT_ID   | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour authentifier comme une App — prend le pas sur `GH_PAT`. Requis (avec `APP_PRIVATE_KEY`) ou `GH_PAT` pour l'automerge, et pour que la PR déclenche la CI. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                                                                                                                    | Non    |
| GH_PAT          | Personal Access Token GitHub. Alternative historique à `APP_CLIENT_ID`/`APP_PRIVATE_KEY`, toujours supportée mais l'authentification App est préférée.                                                                                              | Non    |

## Outputs

| Output                 | Description                                          | Disponibilité           |
| ---------------------- | ---------------------------------------------------- | ----------------------- |
| chart-version          | Nouvelle version du chart calculée par le bump       | modes `called`/`local`  |
| previous-chart-version | Version du chart avant le bump                       | modes `called`/`local`  |
| commit-sha             | SHA du commit de bump poussé sur la branche courante | mode `local` uniquement |

## Permissions

| Scope         | Accès | Description                                                     |
| ------------- | ----- | --------------------------------------------------------------- |
| contents      | write | Modifier `Chart.yaml` et pousser les commits (les deux modes)   |
| pull-requests | write | Créer et fusionner la PR de mise à jour (mode `called`)         |

> **Mode `local`** : les deux scopes doivent être accordés, alors que ce mode n'utilise pas `pull-requests: write`. Le `permissions:` d'un job ne peut pas dépendre d'un input, et garder les deux modes dans un seul job est ce qui évite de dupliquer la centaine de lignes de calcul de version dans un second fichier. Le surplus porte sur votre propre dépôt, en plus du `contents: write` déjà nécessaire pour pousser.

## Notes

### Modes de livraison (`RUN_MODE`)

| Mode     | Utilisation                                                                                 | Comportement                                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `called` | Le chart est dans ce dépôt et la mise à jour doit passer par une revue (ou un automerge)    | Met à jour `Chart.yaml` et le README, puis crée une Pull Request contre `BASE_BRANCH`. Supporte l'automerge. C'est le mode utilisé par un dépôt chart qui reçoit un dispatch de [`dispatch-helm-chart.yml`](./dispatch-helm-chart.md). |
| `local`  | Le chart est dans le **même dépôt** que l'application (monorepo), pipeline CI/CD applicatif | Met à jour `Chart.yaml` et le README, commit et pousse directement sur la branche courante (`git push origin HEAD:$GITHUB_REF_NAME`). Aucune PR créée. |

Une valeur de `RUN_MODE` non reconnue fait échouer le job explicitement.

> **Quand utiliser `local` ?** Lorsque le chart Helm est hébergé dans le même dépôt que l'application, généralement enchaîné après [`release-app.yml`](./release-app.md) pour committer le bump de version directement sur la branche qui vient d'être libérée, avant d'appeler [`release-helm-local.yml`](./release-helm-local.md) avec les outputs `chart-version` et `commit-sha`.

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
- **Mode `local`** : commit et push directement sur `$GITHUB_REF_NAME`, avec un `git pull --rebase` préalable pour tolérer les push concurrents d'autres jobs du même pipeline. Les push authentifiés avec `GITHUB_TOKEN` ne redéclenchent jamais de nouveau workflow (anti-récursion GitHub), ce qui permet d'enchaîner un job de release du chart dans le même run en toute sécurité - ce commit ne porte volontairement pas `[skip ci]` : `GITHUB_TOKEN` suffit déjà à empêcher la boucle, et `[skip ci]` supprimerait aussi les checks `pull_request` d'une pull request qu'un humain ouvrirait ensuite depuis cette branche (ex : une promotion manuelle `develop` → `main`).
- **Automerge (mode `called`)** : Si `AUTOMERGE_PRERELEASE: true` (quand `UPGRADE_TYPE: prerelease`) ou `AUTOMERGE_RELEASE: true` (sinon), tente de fusionner la PR automatiquement selon `AUTOMERGE_METHOD` :
  - `auto` (défaut) : met la PR en file d'attente, GitHub la fusionne une fois les checks requis passés. Nécessite *Allow auto-merge* activé sur le dépôt.
  - `admin` : fusionne immédiatement, en contournant la protection de branche et les checks requis.
  - Sans credential (`APP_CLIENT_ID`/`APP_PRIVATE_KEY` ou `GH_PAT`) fourni, le job échoue plutôt que de silencieusement ne rien fusionner. Voir [`authentication.md`](./authentication.md#automerge).
- **Injection** : `APP_VERSION` et `PRERELEASE_IDENTIFIER` sont écrits dans `Chart.yaml` avec `yq` + `strenv()`, jamais avec `sed` - ils ne peuvent donc être que stockés, jamais interprétés. Ils sont en plus validés en début de job.
- La documentation du chart est régénérée avec la version de helm-docs fixée par `HELM_DOCS_VERSION`.
- Suit le versioning sémantique (semver).

## Exemples

### Mode called - Mise à jour dans ce dépôt via Pull Request

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
    permissions:
      contents: write
      pull-requests: write
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
    permissions:
      contents: write
      pull-requests: write
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
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      APP_VERSION: 1.2.3-rc.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: rc
      AUTOMERGE_PRERELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Changement d'identifiant de pré-release (alpha -> beta)

```yaml
jobs:
  # Passage de alpha à beta (ex: 1.2.3-alpha.2 -> 1.2.3-beta)
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      APP_VERSION: 1.2.3-beta.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: beta # Different from current 'alpha'
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Mode local — chart dans un monorepo, enchaîné avec release-helm-local.yml

Utiliser `local` quand le chart Helm est dans le même dépôt que l'application. Le workflow commit et pousse directement la mise à jour du chart sur la branche courante, puis expose `chart-version` et `commit-sha` pour les jobs suivants (par exemple pour packager et publier le chart via [`release-helm-local.yml`](./release-helm-local.md)).

```yaml
name: Update Helm Chart on Release

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  update-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor

  release-chart:
    needs:
    - release
    - update-chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm-local.yml@v0
    permissions:
      contents: read
      packages: write
    with:
      CHART_NAME: my-app
      CHART_VERSION: ${{ needs.update-chart.outputs.chart-version }}
      APP_VERSION: ${{ needs.release.outputs.version }}
      CHECKOUT_REF: ${{ needs.update-chart.outputs.commit-sha }}
```
