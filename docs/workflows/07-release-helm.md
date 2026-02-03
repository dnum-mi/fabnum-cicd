# `release-helm.yml`

Publication des charts Helm sur un registre OCI (ghcr.io) avec [chart-releaser](https://github.com/helm/chart-releaser-action).

## Inputs

| Input      | Type   | Description                                                          | Requis | Défaut     |
| ---------- | ------ | -------------------------------------------------------------------- | ------ | ---------- |
| CHARTS_DIR | string | Répertoire contenant les charts Helm                                 | Non    | `./charts` |
| HELM_REPOS | string | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules) | Non    | -          |

## Permissions

| Scope    | Accès | Description                             |
| -------- | ----- | --------------------------------------- |
| contents | write | Créer des releases GitHub               |
| packages | write | Pousser les charts vers le registre OCI |

## Notes

- Utilise chart-releaser-action pour automatiser le packaging et la publication des charts.
- Publie les charts vers GitHub Container Registry (ghcr.io) au format OCI.
- Seuls les charts modifiés sont packagés et publiés.
- Les dépôts Helm peuvent être ajoutés pour résoudre les dépendances des charts.
- Configure Git avec le bot GitHub Actions pour les commits automatiques.

## Exemples

### Exemple simple

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

### Avec un répertoire de charts personnalisé

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      CHARTS_DIR: ./helm-charts
```
