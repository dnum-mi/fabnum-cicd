# `release-helm.yml`

Publication des charts Helm sur un registre OCI avec [chart-releaser](https://github.com/helm/chart-releaser-action).

## Inputs

| Input             | Type   | Description                                                                            | Requis | Défaut              |
| ----------------- | ------ | -------------------------------------------------------------------------------------- | ------ | ------------------- |
| CHARTS_DIR        | string | Répertoire contenant les charts Helm                                                   | Non    | `./charts`          |
| HELM_REPOS        | string | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules)                   | Non    | -                   |
| REGISTRY          | string | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)            | Non    | `ghcr.io`           |
| REPOSITORY        | string | Chemin du repository dans le registre OCI (défaut: `github.repository`)                | Non    | `github.repository` |
| REGISTRY_USERNAME | string | Nom d'utilisateur pour l'authentification au registre OCI                              | Non    | -                   |
| REGISTRY_PASSWORD | string | Mot de passe pour l'authentification au registre OCI                                   | Non    | -                   |
| RUNS_ON           | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`  |

## Permissions

| Scope    | Accès | Description                             |
| -------- | ----- | --------------------------------------- |
| contents | write | Créer des releases GitHub               |
| packages | write | Pousser les charts vers le registre OCI |

## Notes

- Utilise chart-releaser-action pour automatiser le packaging et la publication des charts.
- Par défaut, publie vers GitHub Container Registry (ghcr.io), mais supporte n'importe quel registre OCI.
- **Normalisation du nom de repository** : Le chemin du repository OCI est automatiquement normalisé pour être compatible avec les registres OCI :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `My-Org/My_Charts` → `my-org/my-charts`
- Pour ghcr.io, utilise automatiquement les credentials GitHub (pas besoin de fournir REGISTRY_USERNAME/PASSWORD).
- Pour les autres registres, fournissez REGISTRY_USERNAME et REGISTRY_PASSWORD.
- Seuls les charts modifiés sont packagés et publiés.
- Les dépôts Helm peuvent être ajoutés pour résoudre les dépendances des charts.
- Configure Git avec le bot GitHub Actions pour les commits automatiques.

## Exemples

### Exemple simple (GitHub Container Registry)

```yaml
name: Release Charts

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
```

### Avec dépôts Helm personnalisés

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      CHARTS_DIR: ./charts
      HELM_REPOS: "bitnami=https://charts.bitnami.com/bitnami,stable=https://charts.helm.sh/stable"
```

### Avec GitLab Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      REGISTRY: registry.gitlab.com
      REPOSITORY: my-group/my-project
      REGISTRY_USERNAME: ${{ secrets.GITLAB_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.GITLAB_TOKEN }}
```

### Avec Docker Hub

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      REGISTRY: registry-1.docker.io
      REPOSITORY: my-org/charts
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Avec Azure Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      REGISTRY: myregistry.azurecr.io
      REPOSITORY: helm-charts
      REGISTRY_USERNAME: ${{ secrets.AZURE_CLIENT_ID }}
      REGISTRY_PASSWORD: ${{ secrets.AZURE_CLIENT_SECRET }}
```

### Avec un répertoire de charts personnalisé

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      CHARTS_DIR: ./helm-charts
```
