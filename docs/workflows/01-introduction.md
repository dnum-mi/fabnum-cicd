# Introduction aux Workflows GitHub Actions

Les workflows GitHub Actions réutilisables permettent de standardiser et centraliser vos pipelines CI/CD. Ce dépôt propose un ensemble complet de workflows prêts à l'emploi.

## Liste des workflows disponibles

### Build & Déploiement

- [**02 - Build Docker**](./02-build-docker.md) - Build et push d'images Docker multi-architecture

### Maintenance

- [**03 - Clean Cache**](./03-clean-cache.md) - Nettoyage du cache GitHub Actions et des images GHCR

### Linting & Validation

- [**04 - Lint Commits**](./04-lint-commits.md) - Validation des messages de commit (Conventional Commits)
- [**05 - Lint Helm**](./05-lint-helm.md) - Lint des charts Helm avec chart-testing

### Release & Versioning

- [**06 - Release App**](./06-release-app.md) - Gestion automatisée des releases d'application avec release-please
- [**07 - Release Helm**](./07-release-helm.md) - Publication de charts Helm sur registres OCI

### Sécurité & Qualité

- [**08 - Scan SonarQube**](./08-scan-sonarqube.md) - Analyse de qualité du code avec SonarQube
- [**09 - Scan Trivy**](./09-scan-trivy.md) - Analyse de vulnérabilités avec Trivy

### Synchronisation

- [**10 - Sync CPiN**](./10-sync-cpin.md) - Synchronisation avec l'instance GitLab CPiN

### Tests

- [**11 - Test Helm**](./11-test-helm.md) - Test d'installation des charts Helm dans un cluster Kind

### Utilitaires

- [**12 - Update Helm Chart**](./12-update-helm-chart.md) - Mise à jour automatique des versions de charts Helm

## Utilisation rapide

Pour utiliser un workflow réutilisable dans votre projet :

```yaml
name: Mon Pipeline CI/CD

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  # Exemple : Lint des commits
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main

  # Exemple : Build Docker
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ github.sha }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile

  # Exemple : Scan de sécurité
  security:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/my-org/my-app:${{ github.sha }}
      FORMAT: sarif
```

## Workflows par cas d'usage

### Pipeline CI complet pour une application

```yaml
name: CI

on:
  pull_request:

jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
  
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: pr-${{ github.event.pull_request.number }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
  
  scan-security:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/my-org/my-app:pr-${{ github.event.pull_request.number }}
  
  scan-quality:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: https://sonarqube.example.com
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

### Pipeline CD avec release

```yaml
name: CD

on:
  push:
    branches:
      - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
  
  build:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      LATEST_TAG: true
      TAG_MAJOR_AND_MINOR: true
```

### Pipeline pour charts Helm

```yaml
name: Helm CI/CD

on:
  push:
    branches:
      - main
  pull_request:
    paths:
      - 'charts/**'

jobs:
  lint-helm:
    if: github.event_name == 'pull_request'
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
  
  test-helm:
    if: github.event_name == 'pull_request'
    needs: lint-helm
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
  
  release-helm:
    if: github.event_name == 'push'
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      CHARTS_DIR: ./charts
```

## Configuration

### Secrets requis

Certains workflows nécessitent des secrets GitHub. Voici un résumé :

| Secret              | Workflows concernés            | Description                        |
| ------------------- | ------------------------------ | ---------------------------------- |
| `GH_PAT`            | release-app, update-helm-chart | GitHub Personal Access Token       |
| `SONAR_TOKEN`       | scan-sonarqube                 | Token d'authentification SonarQube |
| `SONAR_PROJECT_KEY` | scan-sonarqube                 | Clé du projet SonarQube            |
| `GIT_MIRROR_TOKEN`  | sync-cpin                      | Token GitLab pour synchronisation  |

### Permissions requises

Les workflows réutilisables déclarent leurs permissions. Assurez-vous que votre dépôt autorise les workflows à accéder aux ressources nécessaires.

## Documentation détaillée

Consultez la documentation de chaque workflow pour :
- Les inputs et leurs valeurs par défaut
- Les outputs disponibles
- Les secrets requis
- Les permissions nécessaires
- Des exemples d'utilisation avancés
- Des notes et bonnes pratiques
