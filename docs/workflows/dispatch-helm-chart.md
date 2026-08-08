# `dispatch-helm-chart.yml`

Déclenche la mise à jour d'un chart Helm hébergé dans un **dépôt séparé**, via `workflow_dispatch`.

Le dépôt applicatif ne touche à rien : il envoie la version au dépôt chart, qui exécute son propre workflow d'entrée (généralement [`update-helm-chart.yml`](./update-helm-chart.md) en mode `called`) et ouvre la Pull Request chez lui.

> Si le chart est dans le **même dépôt** que l'application, ce workflow n'est pas celui qu'il vous faut : utilisez directement [`update-helm-chart.yml`](./update-helm-chart.md).

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                     | Requis | Défaut                   |
| --------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------ |
| CHART_REPO            | string | Nom du dépôt chart à mettre à jour (ex: `this-is-tobi/helm-charts`)                                                                                                                             | Oui    | -                        |
| CHART_NAME            | string | Nom du chart à mettre à jour (dans CHART_DIR)                                                                                                                                                   | Oui    | -                        |
| WORKFLOW_NAME         | string | Nom du workflow à déclencher dans le dépôt chart (ex: `update-chart.yml`)                                                                                                                       | Non    | `update-app-version.yml` |
| CHART_DIR             | string | Nom du dossier contenant le chart (dans CHART_REPO)                                                                                                                                             | Non    | `charts`                 |
| APP_VERSION           | string | Version de l'application à injecter dans `Chart.yaml` (`appVersion`). Laisser vide pour conserver l'`appVersion` actuelle - une release "chart-only".                                           | Non    | `""`                     |
| UPGRADE_TYPE          | string | Type de mise à jour : `major`, `minor`, `patch` ou `prerelease`                                                                                                                                 | Non    | `patch`                  |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release (utilisé seulement si UPGRADE_TYPE est `prerelease`)                                                                                                                 | Non    | `rc`                     |
| AUTOMERGE_PRERELEASE  | bool   | Demander au dépôt chart de fusionner sa PR quand `UPGRADE_TYPE` est `prerelease`                                                                                                                | Non    | `false`                  |
| AUTOMERGE_RELEASE     | bool   | Demander au dépôt chart de fusionner sa PR quand `UPGRADE_TYPE` n'est pas `prerelease`                                                                                                          | Non    | `false`                  |
| AUTOMERGE_METHOD      | string | Méthode de fusion demandée au dépôt chart : `auto` (file d'attente, nécessite *Allow auto-merge* sur le dépôt chart) ou `admin` (fusion immédiate en contournant la protection de branche)      | Non    | `auto`                   |
| BASE_BRANCH           | string | Branche de `CHART_REPO` sur laquelle le workflow est dispatché, et base de la Pull Request ouverte par le dépôt chart                                                                            | Non    | `main`                   |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                          | Non    | `["ubuntu-24.04"]`       |

## Secrets

| Secret          | Description                                                                                                                                                                                       | Requis |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| APP_CLIENT_ID   | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour authentifier comme une App — prend le pas sur `GH_PAT`. Voir [`authentication.md`](./authentication.md).                        | Non\*  |
| APP_PRIVATE_KEY | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                                                                   | Non\*  |
| GH_PAT          | Personal Access Token GitHub. Alternative historique à `APP_CLIENT_ID`/`APP_PRIVATE_KEY`, toujours supportée mais l'authentification App est préférée.                                             | Non\*  |

\* Aucun n'est formellement requis, mais **l'un des deux modes doit être fourni** : `APP_CLIENT_ID` + `APP_PRIVATE_KEY`, ou `GH_PAT`. `GITHUB_TOKEN` ne peut pas déclencher un workflow dans un autre dépôt ; sans credential, le job échoue explicitement plutôt que de ne rien faire.

## Permissions

| Scope | Accès | Description |
| ----- | ----- | ----------- |
| -     | -     | Aucune      |

C'est la raison d'être de ce workflow séparé. Tout ce qu'il fait s'authentifie auprès de `CHART_REPO` avec le token App (ou `GH_PAT`) ; **rien ne touche au dépôt appelant**. Le job appelant doit donc déclarer `permissions: {}` :

```yaml
  dispatch-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    permissions: {}
    with:
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

> **Pourquoi le dispatch a son propre workflow.** GitHub valide au parsing les permissions demandées par **tous** les jobs d'un workflow réutilisable appelé, quel que soit leur `if:`. L'appelant accorde toujours l'union : un job qui partagerait ce workflow imposerait ses propres scopes à chaque appel de dispatch, pour un travail qui ne s'exécute jamais. Un job par niveau de privilège est ce qui rend `permissions: {}` réellement atteignable ici. La règle est vérifiée sur l'ensemble des workflows réutilisables par `ci/tests/permission-union.test.sh`.

## Notes

- **Authentification** : en mode App, le token est réduit à `actions: write` **sur le seul dépôt `CHART_REPO`**. L'App doit donc être installée sur `CHART_REPO`, pas sur le dépôt qui exécute ce job. Voir [`authentication.md`](./authentication.md#dispatch-cross-repository-dispatch-helm-chart).
- **`BASE_BRANCH` est toujours transmis explicitement** (`gh workflow run --ref`). Sans lui, `gh` résout lui-même la branche par défaut de `CHART_REPO` via une requête GraphQL `defaultBranchRef` qui dépasse le scope `actions: write` du token et échoue (`unable to determine default branch for <repo>: GraphQL: Resource not accessible by integration (repository.defaultBranchRef)`). Si la branche par défaut de `CHART_REPO` n'est pas `main`, renseignez `BASE_BRANCH`, quel que soit le credential utilisé.
- **Compatibilité `AUTOMERGE_METHOD`** : un dépôt chart dont le workflow d'entrée ne déclare pas cet input fait rejeter tout le dispatch par l'API (`422 Unexpected inputs provided`), et non ignorer la valeur en trop. Le workflow réessaie donc sans l'input et émet un `::warning::` indiquant que c'est le défaut du dépôt chart qui s'applique. Ajoutez l'input `AUTOMERGE_METHOD` au workflow d'entrée du dépôt chart pour piloter la méthode de fusion depuis ici.
- **Validation en amont du token** : `CHART_REPO` est validé (`owner/repository`, une seule ligne) *avant* que le token App ne soit émis — une valeur sans `/` ferait sinon émettre un token pour un propriétaire portant le nom du dépôt.
- Le dispatch est asynchrone : ce job réussit dès que le `workflow_dispatch` est accepté, sans attendre le résultat de la mise à jour dans `CHART_REPO`.

## Contrat de dispatch

Le workflow d'entrée de `CHART_REPO` doit être déclenchable par `workflow_dispatch` et accepter les inputs suivants :

| Input                   | Envoyé par ce workflow                        |
| ----------------------- | --------------------------------------------- |
| `RUN_MODE`              | toujours `called`                             |
| `APP_VERSION`           | `inputs.APP_VERSION`                          |
| `CHART_NAME`            | `inputs.CHART_NAME`                           |
| `CHART_DIR`             | `inputs.CHART_DIR` (slashs finaux retirés)    |
| `UPGRADE_TYPE`          | `inputs.UPGRADE_TYPE`                         |
| `PRERELEASE_IDENTIFIER` | `inputs.PRERELEASE_IDENTIFIER`                |
| `AUTOMERGE_PRERELEASE`  | `inputs.AUTOMERGE_PRERELEASE`                 |
| `AUTOMERGE_RELEASE`     | `inputs.AUTOMERGE_RELEASE`                    |
| `AUTOMERGE_METHOD`      | `inputs.AUTOMERGE_METHOD` (voir compatibilité ci-dessus) |

Côté dépôt chart, ce workflow d'entrée relaie ces inputs vers [`update-helm-chart.yml`](./update-helm-chart.md) — voir l'exemple « Dépôt chart » plus bas.

## Exemples

### Déclencher la mise à jour après une release applicative

```yaml
name: Update Chart

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
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  dispatch-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    # Rien n'est fait sur ce dépôt : tout passe par le token App vers CHART_REPO.
    permissions: {}
    with:
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor
      AUTOMERGE_PRERELEASE: true
      AUTOMERGE_RELEASE: false
      AUTOMERGE_METHOD: auto
    secrets:
      # L'App doit être installée sur CHART_REPO (my-org/helm-charts).
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Pré-release, et changement d'identifiant

```yaml
jobs:
  # Passage de alpha à beta (ex: 1.2.3-alpha.2 -> 1.2.3-beta)
  dispatch-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    permissions: {}
    with:
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: 1.2.3-beta.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: beta # Différent de l'identifiant courant 'alpha'
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Branche par défaut autre que `main`

```yaml
jobs:
  dispatch-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    permissions: {}
    with:
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: 1.4.0
      # Dispatché sur cette branche de CHART_REPO, et base de la PR ouverte là-bas.
      BASE_BRANCH: develop
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Côté dépôt chart — le workflow d'entrée qui reçoit le dispatch

À placer dans `CHART_REPO`, sous le nom déclaré par `WORKFLOW_NAME` :

```yaml
name: Update app version

on:
  workflow_dispatch:
    inputs:
      RUN_MODE:
        description: Mode de mise à jour (toujours 'called' depuis un dispatch)
        required: false
        default: called
      APP_VERSION:
        description: Version de l'application
        required: false
      CHART_NAME:
        description: Nom du chart
        required: true
      CHART_DIR:
        description: Dossier contenant le chart
        required: false
        default: charts
      UPGRADE_TYPE:
        description: major, minor, patch ou prerelease
        required: false
        default: patch
      PRERELEASE_IDENTIFIER:
        description: Identifiant de pré-release
        required: false
        default: rc
      AUTOMERGE_PRERELEASE:
        description: Fusionner automatiquement les pré-releases
        required: false
        default: "false"
      AUTOMERGE_RELEASE:
        description: Fusionner automatiquement les releases
        required: false
        default: "false"
      AUTOMERGE_METHOD:
        description: auto ou admin
        required: false
        default: auto

jobs:
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: ${{ inputs.CHART_NAME }}
      CHART_DIR: ${{ inputs.CHART_DIR }}
      APP_VERSION: ${{ inputs.APP_VERSION }}
      UPGRADE_TYPE: ${{ inputs.UPGRADE_TYPE }}
      PRERELEASE_IDENTIFIER: ${{ inputs.PRERELEASE_IDENTIFIER }}
      AUTOMERGE_PRERELEASE: ${{ inputs.AUTOMERGE_PRERELEASE == 'true' }}
      AUTOMERGE_RELEASE: ${{ inputs.AUTOMERGE_RELEASE == 'true' }}
      AUTOMERGE_METHOD: ${{ inputs.AUTOMERGE_METHOD }}
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```
