# `dispatch-helm-chart.yml`

Déclenche la mise à jour d'un chart Helm hébergé dans un **dépôt séparé**, via `workflow_dispatch`.

Le dépôt applicatif ne touche à rien : il envoie la version au dépôt chart, qui exécute son propre workflow d'entrée (généralement [`update-helm-chart.yml`](./53-update-helm-chart.md) en mode `called`) et ouvre la Pull Request chez lui.

> Si le chart est dans le **même dépôt** que l'application, ce workflow n'est pas celui qu'il vous faut : utilisez directement [`update-helm-chart.yml`](./53-update-helm-chart.md).

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                                                                                                                    | Requis | Défaut                   |
| --------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------ |
| CHART_REPO            | string | Dépôt chart cible (`owner/repo`)                                                                                                                                                                                                                                                               | Oui    | -                        |
| CHART_NAME            | string | Nom du chart à mettre à jour (dans `CHART_DIR`)                                                                                                                                                                                                                                                | Oui    | -                        |
| WORKFLOW_NAME         | string | Nom du fichier de workflow à déclencher dans le dépôt chart                                                                                                                                                                                                                                    | Non    | `update-app-version.yml` |
| CHART_DIR             | string | Dossier contenant les charts Helm (dans `CHART_REPO`)                                                                                                                                                                                                                                          | Non    | `charts`                 |
| APP_VERSION           | string | Version de l'application à injecter dans `Chart.yaml` (`appVersion`). Laisser vide pour conserver l'`appVersion` actuelle - une release "chart-only"                                                                                                                                           | Non    | -                        |
| UPGRADE_TYPE          | string | Partie SemVer à incrémenter : `auto` (défaut), `major`, `minor`, `patch` ou `prerelease` - transmis tel quel au dépôt chart, où [`update-helm-chart.yml`](./53-update-helm-chart.md#mode-auto) dérive le niveau du delta d'appVersion (repli sur `patch` avec avertissement sans delta à lire) | Non    | `auto`                   |
| PRERELEASE_IDENTIFIER | string | Identifiant utilisé quand le bump entre dans le flux prerelease - `UPGRADE_TYPE: prerelease`, ou `auto` avec une `APP_VERSION` en pré-release (ex: `rc`)                                                                                                                                       | Non    | `rc`                     |
| AUTOMERGE_PRERELEASE  | bool   | Demander au dépôt chart de fusionner sa PR quand le bump est une pré-release                                                                                                                                                                                                                   | Non    | `false`                  |
| AUTOMERGE_RELEASE     | bool   | Demander au dépôt chart de fusionner sa PR quand le bump n'est pas une pré-release                                                                                                                                                                                                             | Non    | `false`                  |
| AUTOMERGE_METHOD      | string | Méthode de fusion demandée au dépôt chart : `auto` (file d'attente jusqu'à la réussite des checks requis, nécessite *Allow auto-merge* sur le dépôt chart) ou `admin` (fusion immédiate en contournant la protection de branche)                                                               | Non    | `auto`                   |
| BASE_BRANCH           | string | Branche de `CHART_REPO` sur laquelle le workflow est dispatché, et base de la Pull Request ouverte par le dépôt chart                                                                                                                                                                          | Non    | `main`                   |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                         | Non    | `["ubuntu-24.04"]`       |

## Secrets

| Secret          | Description                                                                                                                                                                                            | Requis | Défaut |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ |
| APP_CLIENT_ID   | **Client ID** d'une GitHub App (pas l'App ID numérique). À fournir avec `APP_PRIVATE_KEY` pour authentifier comme une App — prend le pas sur `GH_PAT`. Voir [Authentification](./05-authentication.md) | Non\*  | -      |
| APP_PRIVATE_KEY | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`                                                                                                                                         | Non\*  | -      |
| GH_PAT          | Personal Access Token GitHub. Alternative historique, toujours supportée (voir [Configuration du token](#configuration-du-token))                                                                      | Non\*  | -      |

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

## Configuration du token

Le credential sert à `gh workflow run --repo <CHART_REPO>`, et est minté avec pour seul périmètre ce dépôt.

### GitHub App (recommandé)

Définir `APP_CLIENT_ID` et `APP_PRIVATE_KEY` comme secrets du dépôt dans le **dépôt applicatif** (celui qui appelle ce workflow).

| Exigence             | Valeur                                                     |
| -------------------- | ---------------------------------------------------------- |
| App installée sur    | le dépôt **chart** (`CHART_REPO`), pas le dépôt applicatif |
| Permissions de l'App | Actions : Read & Write, Metadata : Read                    |
| Token limité à       | `CHART_REPO` uniquement — jamais le dépôt courant          |

`CHART_REPO` doit être renseigné sous la forme `owner/repository` ; un nom de dépôt seul est rejeté avant toute émission de token, car il ferait sinon résoudre le propriétaire au nom du dépôt.

`APP_CLIENT_ID` et `APP_PRIVATE_KEY` doivent être fournis **ensemble**. En fournir un seul fait échouer le job au lieu de se rabattre sur `GH_PAT` ou `GITHUB_TOKEN`, ce qui authentifierait silencieusement autre chose que l'App.

### PAT fine-grained

Créer un [fine-grained personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) limité au **dépôt chart cible** (`CHART_REPO`) avec :

| Permission | Accès        | Raison                                              |
| ---------- | ------------ | --------------------------------------------------- |
| Actions    | Read & Write | Déclencher un workflow dispatch dans le dépôt chart |

### PAT classique

Créer un [token classique](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) avec le scope **`repo`** (donne accès à tous les dépôts auxquels l'utilisateur a accès).

### Où le stocker

Ajouter le token comme **secret de dépôt** nommé `GH_PAT` dans le **dépôt source (applicatif)** — celui qui appelle ce workflow :  
**Settings > Secrets and variables > Actions > New repository secret**

> Si le dépôt chart utilise aussi l'automerge, il a besoin de son **propre** credential pour `gh pr merge` — voir [`update-helm-chart.yml`](./53-update-helm-chart.md). Le même PAT peut servir aux deux s'il a les permissions sur les deux dépôts.

## Notes

- Le dispatch est **asynchrone** : ce job réussit dès que le `workflow_dispatch` est accepté, sans attendre le résultat de la mise à jour dans `CHART_REPO`.
- **`BASE_BRANCH` est toujours transmis explicitement** (`gh workflow run --ref`). Sans lui, `gh` résout lui-même la branche par défaut de `CHART_REPO` via une requête GraphQL `defaultBranchRef` qui dépasse le scope `actions: write` du token et échoue (`unable to determine default branch for <repo>: GraphQL: Resource not accessible by integration (repository.defaultBranchRef)`). Si la branche par défaut de `CHART_REPO` n'est pas `main`, renseignez `BASE_BRANCH`, quel que soit le credential utilisé (App ou `GH_PAT`).
- **Compatibilité `AUTOMERGE_METHOD`** : un dépôt chart dont le workflow d'entrée ne déclare pas cet input fait rejeter tout le dispatch par l'API (`422 Unexpected inputs provided`), et non ignorer la valeur en trop. Le workflow réessaie donc une fois sans l'input et émet un `::warning::` indiquant que c'est le défaut du dépôt chart qui s'applique. Ajoutez l'input `AUTOMERGE_METHOD` au workflow d'entrée du dépôt chart pour piloter la méthode de fusion depuis ici — l'exemple « Côté dépôt chart » plus bas l'inclut.
- **Validation en amont du token** : `CHART_REPO` est vérifié (`owner/repository`, une seule ligne) et `BASE_BRANCH` ne doit pas contenir d'espace, *avant* que le token ne soit émis, pour qu'une valeur mal formée échoue à peu de frais au lieu de ressortir en erreur d'API opaque.

## Contrat de dispatch

Le workflow d'entrée de `CHART_REPO` doit être déclenchable par `workflow_dispatch` et déclarer les inputs suivants — GitHub rejette un dispatch qui transporte un input non déclaré au lieu de l'ignorer :

| Input                   | Envoyé par ce workflow                                   |
| ----------------------- | -------------------------------------------------------- |
| `RUN_MODE`              | toujours `called`                                        |
| `APP_VERSION`           | `inputs.APP_VERSION`                                     |
| `CHART_NAME`            | `inputs.CHART_NAME`                                      |
| `CHART_DIR`             | `inputs.CHART_DIR` (slashs finaux retirés)               |
| `UPGRADE_TYPE`          | `inputs.UPGRADE_TYPE`                                    |
| `PRERELEASE_IDENTIFIER` | `inputs.PRERELEASE_IDENTIFIER`                           |
| `AUTOMERGE_PRERELEASE`  | `inputs.AUTOMERGE_PRERELEASE`                            |
| `AUTOMERGE_RELEASE`     | `inputs.AUTOMERGE_RELEASE`                               |
| `AUTOMERGE_METHOD`      | `inputs.AUTOMERGE_METHOD` (voir compatibilité ci-dessus) |

Un workflow d'entrée prêt à l'emploi figure dans l'exemple « Côté dépôt chart » plus bas.

## Exemples

> Ces exemples utilisent les credentials d'une GitHub App, le mode recommandé. Pour utiliser un personal access token à la place, remplacez les deux lignes `APP_*` par <span v-pre>`GH_PAT: ${{ secrets.GH_PAT }}`</span> — rien d'autre ne change. L'App doit être installée sur le dépôt désigné par `CHART_REPO`, puisque le token est minté avec ce seul périmètre. Voir [Authentification](./05-authentication.md) pour la mise en place complète de l'un ou l'autre.

### Déclencher la mise à jour après une release applicative

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write

  trigger-chart-update:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    needs:
    - release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    # Rien n'est écrit sur ce dépôt : tout passe par le token App vers
    # CHART_REPO.
    permissions: {}
    with:
      WORKFLOW_NAME: update-app-version.yml
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor
      AUTOMERGE_RELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Bump de pré-release avec automerge

`UPGRADE_TYPE: prerelease` incrémente la version de pré-release du chart (`1.2.3` → `1.2.4-rc` → `1.2.4-rc.1` → `1.2.4-rc.2` : depuis une version stable, le patch est incrémenté d'abord, puis le compteur). `APP_VERSION` est écrit tel quel dans `appVersion` ; seul le champ `version` du chart suit la logique de bump de pré-release. `AUTOMERGE_PRERELEASE: true` demande au dépôt chart de fusionner la PR résultante.

```yaml
jobs:
  bump-chart-prerelease:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    permissions: {}
    with:
      WORKFLOW_NAME: update-app-version.yml
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: 1.4.0-rc.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: rc
      AUTOMERGE_PRERELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Dépôt chart dont la branche par défaut n'est pas `main`

```yaml
jobs:
  trigger-chart-update:
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
        description: auto, major, minor, patch ou prerelease
        required: false
        default: auto
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
