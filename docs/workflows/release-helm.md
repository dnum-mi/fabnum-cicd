# `release-helm.yml`

Publication des charts Helm sur un registre OCI, en mode `chart-releaser` (dépôt de charts dédié) ou `local` (chart hébergé dans un monorepo applicatif).

## Inputs

| Input                 | Type    | Description                                                                                                                                                                                                                                                                                                                                                                              | Requis | Défaut              |
| --------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| MODE                  | string  | Stratégie de release. `chart-releaser` (défaut) détecte automatiquement les charts dont la version a changé depuis le dernier tag git - adapté à un dépôt de charts dédié. `local` package un chart précis de ce dépôt à une version explicite et le pousse sur le registre OCI - adapté à un monorepo où le partage de l'espace de tags rend la détection de chart-releaser peu fiable. | Non    | `chart-releaser`    |
| CHARTS_DIR            | string  | Répertoire contenant les charts Helm                                                                                                                                                                                                                                                                                                                                                     | Non    | `./charts`          |
| CREATE_GITHUB_RELEASE | boolean | Créer en plus une GitHub Release et un tag git pour chaque chart modifié, et mettre à jour `index.yaml` sur la branche `PAGES_BRANCH`. Nécessite que cette branche existe déjà. Si `false` (défaut), seul le packaging + push OCI est effectué, sans branche GitHub Pages requise. (mode `chart-releaser` uniquement)                                                                    | Non    | `false`             |
| PAGES_BRANCH          | string  | Branche recevant `index.yaml` et les artefacts de release quand `CREATE_GITHUB_RELEASE` est `true`. Doit déjà exister. (mode `chart-releaser` uniquement)                                                                                                                                                                                                                                | Non    | `gh-pages`          |
| CHART_NAME            | string  | Mode `local` uniquement. Dossier du chart sous `CHARTS_DIR` à packager et pousser (ex: `my-app`). Laisser vide pour packager tous les charts trouvés directement sous `CHARTS_DIR`.                                                                                                                                                                                                      | Non    | -                   |
| CHART_VERSION         | string  | Mode `local` uniquement. Version du chart à appliquer lors du packaging (`helm package --version`). Par défaut, utilise la version déjà présente dans `Chart.yaml`.                                                                                                                                                                                                                      | Non    | -                   |
| APP_VERSION           | string  | Mode `local` uniquement. Version applicative à appliquer lors du packaging (`helm package --app-version`). Par défaut, utilise l'`appVersion` déjà présente dans `Chart.yaml`.                                                                                                                                                                                                           | Non    | -                   |
| CHECKOUT_REF          | string  | Mode `local` uniquement. Ref git (branche ou SHA) à checkout avant le packaging. Utile pour récupérer un commit de bump de chart poussé plus tôt dans le même pipeline (ex: l'output `commit-sha` de `update-helm-chart.yml` en mode local).                                                                                                                                             | Non    | -                   |
| HELM_REPOS            | string  | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules)                                                                                                                                                                                                                                                                                                                     | Non    | -                   |
| REGISTRY              | string  | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)                                                                                                                                                                                                                                                                                                              | Non    | `ghcr.io`           |
| REPOSITORY            | string  | Chemin du repository dans le registre OCI (défaut: `github.repository`)                                                                                                                                                                                                                                                                                                                  | Non    | `github.repository` |
| RUNS_ON               | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                                                                                                                   | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                               | Requis |
| ----------------- | --------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre OCI | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre OCI      | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour que chart-releaser authentifie comme une App - contrairement à `GITHUB_TOKEN`, les releases créées peuvent alors déclencher des triggers `release:`. Ignoré en mode `local`. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                        | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux. Comme un token App, il peut déclencher des workflows - la même précaution s'applique au push sur `PAGES_BRANCH`. Ignoré en mode `local`. | Non    |

## Permissions

| Scope    | Accès | Description                                                                          |
| -------- | ----- | ------------------------------------------------------------------------------------ |
| contents | write | Créer des releases GitHub (mode `chart-releaser` avec `CREATE_GITHUB_RELEASE: true`) |
| packages | write | Pousser les charts vers le registre OCI                                              |

## Notes

### Modes de fonctionnement (`MODE`)

| Mode             | Utilisation                                                                               | Comportement                                                                                                                                                            |
| ---------------- | ----------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `chart-releaser` | Dépôt de charts Helm dédié (versionnage git indépendant de l'application)                 | Détecte les charts dont la version a changé depuis le dernier tag, les package et les pousse sur le registre OCI (job `release`).                                       |
| `local`          | Chart hébergé dans le même dépôt qu'une application (monorepo), pipeline CI/CD applicatif | Package un chart précis (ou tous les charts sous `CHARTS_DIR`) à la version fournie et le pousse sur le registre OCI (job `release-local`), sans dépendre des tags git. |

> **Pourquoi `local` ?** Dans un monorepo, l'application et le chart Helm partagent le même espace de tags git. La détection de changement de chart-releaser (basée sur les tags) devient alors peu fiable. Le mode `local` package explicitement le chart à la version souhaitée (généralement calculée par [`update-helm-chart.yml`](./update-helm-chart.md) en mode `local`), sans dépendre de git tags.

### Autres comportements

- **Mode `chart-releaser`** : Utilise chart-releaser-action pour automatiser le packaging et la publication des charts modifiés. `CREATE_GITHUB_RELEASE: true` crée en plus une GitHub Release, un tag git et met à jour `index.yaml` sur `PAGES_BRANCH`.
- **Mode `local`** : Package `CHART_NAME` (ou tous les charts sous `CHARTS_DIR` si `CHART_NAME` est vide), en appliquant `CHART_VERSION`/`APP_VERSION` si fournis, puis pousse chaque chart packagé vers le registre OCI. `CHECKOUT_REF` permet de checkout un commit précis (ex: le commit de bump du chart) avant le packaging.
- Par défaut, publie vers GitHub Container Registry (ghcr.io), mais supporte n'importe quel registre OCI.
- **Normalisation du nom de repository** : Le chemin du repository OCI est automatiquement normalisé pour être compatible avec les registres OCI :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `My-Org/My_Charts` → `my-org/my-charts`
- Pour ghcr.io, utilise automatiquement les credentials GitHub (pas besoin de fournir REGISTRY_USERNAME/PASSWORD).
- Pour les autres registres, fournissez `REGISTRY_USERNAME` et `REGISTRY_PASSWORD` en tant que secrets.
- Les dépôts Helm peuvent être ajoutés pour résoudre les dépendances des charts (uniquement lorsque le chart déclare des `dependencies` dans `Chart.yaml`, en mode `local`).
- Configure Git avec le bot GitHub Actions pour les commits automatiques (mode `chart-releaser`).
- **`CREATE_GITHUB_RELEASE: true`** : fournir `APP_CLIENT_ID`/`APP_PRIVATE_KEY` (ou `GH_PAT`) permet aux releases GitHub créées de déclencher des triggers `release:`, ce que `GITHUB_TOKEN` ne peut jamais faire. Le push sur `PAGES_BRANCH` utilise le même token, donc le même credential peut aussi déclencher des workflows sur cette branche - à vérifier avant d'activer. Voir [`authentication.md`](./authentication.md).

## Exemples

### Exemple simple (GitHub Container Registry, mode chart-releaser)

```yaml
name: Release Charts

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
```

### Avec dépôts Helm personnalisés

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    with:
      CHARTS_DIR: ./charts
      HELM_REPOS: "bitnami=https://charts.bitnami.com/bitnami,stable=https://charts.helm.sh/stable"
```

### Avec création de GitHub Release et index.yaml (GitHub Pages)

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      CREATE_GITHUB_RELEASE: true
      PAGES_BRANCH: gh-pages
```

### Mode local — chart dans un monorepo applicatif

```yaml
name: Release Chart

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

  release-chart:
    needs: update-chart
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

### Avec GitLab Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    with:
      REGISTRY: registry.gitlab.com
      REPOSITORY: my-group/my-project
    secrets:
      REGISTRY_USERNAME: ${{ secrets.GITLAB_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.GITLAB_TOKEN }}
```

### Avec Docker Hub

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    with:
      REGISTRY: registry-1.docker.io
      REPOSITORY: my-org/charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Avec Azure Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    with:
      REGISTRY: myregistry.azurecr.io
      REPOSITORY: helm-charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.AZURE_CLIENT_ID }}
      REGISTRY_PASSWORD: ${{ secrets.AZURE_CLIENT_SECRET }}
```

### Avec un répertoire de charts personnalisé

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    with:
      CHARTS_DIR: ./helm-charts
```
