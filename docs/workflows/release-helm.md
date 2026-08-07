# `release-helm.yml`

Publication des charts Helm sur un registre OCI via `chart-releaser`, qui détecte automatiquement les charts dont la version a changé depuis le dernier tag git, les package et les pousse sur le registre. Adapté à un **dépôt de charts dédié**, où les tags git du dépôt appartiennent aux charts.

Pour un **monorepo** - un chart hébergé aux côtés du code applicatif, où l'espace de tags est dominé par les tags de l'application et où la détection de changement de chart-releaser (basée sur les tags) devient peu fiable - utilisez [`release-helm-local.yml`](./release-helm-local.md) à la place. Les deux sont des workflows séparés plutôt qu'un seul avec un switch de mode : chacun ne déclare que les permissions dont sa propre logique a besoin, pour qu'un appelant monorepo n'ait jamais à accorder `contents: write` pour un chemin de code chart-releaser qu'il n'exécutera jamais. Voir [`release-helm-local.yml`](./release-helm-local.md#pourquoi-un-workflow-séparé) pour le raisonnement complet.

## Inputs

| Input                 | Type    | Description                                                                                                                                                                                                                                                                                                              | Requis | Défaut              |
| --------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| CHARTS_DIR            | string  | Répertoire contenant les charts Helm                                                                                                                                                                                                                                                                                     | Non    | `./charts`          |
| CREATE_GITHUB_RELEASE | boolean | Créer en plus une GitHub Release et un tag git pour chaque chart modifié, et mettre à jour `index.yaml` sur la branche `PAGES_BRANCH`. Nécessite que cette branche existe déjà. Si `false` (défaut), seul le packaging + push OCI est effectué, sans branche GitHub Pages requise.                                    | Non    | `false`             |
| PAGES_BRANCH          | string  | Branche recevant `index.yaml` et les artefacts de release quand `CREATE_GITHUB_RELEASE` est `true`. Doit déjà exister.                                                                                                                                                                                                  | Non    | `gh-pages`          |
| HELM_REPOS            | string  | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules)                                                                                                                                                                                                                                                     | Non    | -                   |
| REGISTRY              | string  | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)                                                                                                                                                                                                                                                                                                              | Non    | `ghcr.io`           |
| REPOSITORY            | string  | Chemin du repository dans le registre OCI (défaut: `github.repository`)                                                                                                                                                                                                                                                                                                                  | Non    | `github.repository` |
| RUNS_ON               | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                                                                                                                   | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                               | Requis |
| ----------------- | --------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre OCI | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre OCI      | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour que chart-releaser authentifie comme une App - contrairement à `GITHUB_TOKEN`, les releases créées peuvent alors déclencher des triggers `release:`. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                        | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux. Comme un token App, il peut déclencher des workflows - la même précaution s'applique au push sur `PAGES_BRANCH`. | Non    |

## Permissions

| Scope    | Accès | Description                                                                          |
| -------- | ----- | ------------------------------------------------------------------------------------ |
| contents | write | Créer des releases GitHub (mode `chart-releaser` avec `CREATE_GITHUB_RELEASE: true`) |
| packages | write | Pousser les charts vers le registre OCI                                              |

## Notes

- Utilise chart-releaser-action pour automatiser le packaging et la publication des charts modifiés. `CREATE_GITHUB_RELEASE: true` crée en plus une GitHub Release, un tag git et met à jour `index.yaml` sur `PAGES_BRANCH`.
- Par défaut, publie vers GitHub Container Registry (ghcr.io), mais supporte n'importe quel registre OCI.
- **Normalisation du nom de repository** : Le chemin du repository OCI est automatiquement normalisé pour être compatible avec les registres OCI :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `My-Org/My_Charts` → `my-org/my-charts`
- Pour ghcr.io, utilise automatiquement les credentials GitHub (pas besoin de fournir REGISTRY_USERNAME/PASSWORD).
- Pour les autres registres, fournissez `REGISTRY_USERNAME` et `REGISTRY_PASSWORD` en tant que secrets.
- Configure Git avec le bot GitHub Actions pour les commits automatiques.
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

### Chart dans un monorepo applicatif

Pour un chart hébergé aux côtés du code applicatif, voir [`release-helm-local.yml`](./release-helm-local.md) à la place - un workflow séparé, à permissions minimales, dédié à ce cas.

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
