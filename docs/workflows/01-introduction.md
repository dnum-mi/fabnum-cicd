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

Ce workflow s'exécute sur chaque pull request et effectue :
- Filtrage des fichiers modifiés
- Lint des commits conventionnels
- Analyse de qualité du code (SonarQube)
- Analyse de sécurité de la configuration (Trivy)
- Build des images Docker
- Scan de sécurité des images (Trivy)

```yaml
name: CI

on:
  pull_request:
    types:
    - opened
    - reopened
    - synchronize
    - ready_for_review
    branches:
    - "**"
  workflow_dispatch:

env:
  BUILD_AMD64: true
  BUILD_ARM64: false
  LATEST_TAG: false
  USE_QEMU: true
  IMAGE_TAG: ${{ (github.event.pull_request.number && format('pr-{0}', github.event.pull_request.number)) || (github.event.number && format('pr-{0}', github.event.number)) || '' }}

jobs:
  path-filter:
    runs-on: ubuntu-latest
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      contents: read
      pull-requests: read
    outputs:
      apps: ${{ steps.filter.outputs.apps }}
      packages: ${{ steps.filter.outputs.packages }}
      ci: ${{ steps.filter.outputs.ci }}
    steps:
    - name: Checks-out repository
      uses: actions/checkout@v5

    - name: Check updated files paths
      uses: dorny/paths-filter@v3
      id: filter
      with:
        filters: |
          apps:
            - 'apps/**'
          packages:
            - 'packages/**'
          ci:
            - '.github/workflows/**'

  expose-vars:
    runs-on: ubuntu-latest
    if: ${{ !github.event.pull_request.draft }}
    outputs:
      BUILD_AMD64: ${{ env.BUILD_AMD64 }}
      BUILD_ARM64: ${{ env.BUILD_ARM64 }}
      LATEST_TAG: ${{ env.LATEST_TAG }}
      USE_QEMU: ${{ env.USE_QEMU }}
      IMAGE_TAG: ${{ env.IMAGE_TAG }}
    steps:
    - name: Exposing env vars
      run: echo "Exposing env vars"

  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      pull-requests: read
      contents: read

  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    needs:
    - expose-vars
    permissions:
      issues: write
      pull-requests: write
      contents: read
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: apps
      SONAR_EXTRA_ARGS: -Dsonar.coverage.exclusions=**/*.spec.js,**/*.spec.ts -Dsonar.exclusions=**/*.spec.js,**/*.spec.ts
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}

  scan-trivy-conf:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    needs:
    - expose-vars
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    with:
      PATH: ./
      PR_NUMBER: ${{ github.event.pull_request.number || github.event.number || '' }}
      GITHUB_SECURITY_TAB: false

  build-docker:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    needs:
    - expose-vars
    permissions:
      packages: write
      contents: read
    strategy:
      matrix:
        services:
        - name: server
          context: ./apps/server
          dockerfile: ./apps/server/Dockerfile
        - name: client
          context: ./apps/client
          dockerfile: ./apps/client/Dockerfile
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository}}/${{ matrix.services.name }}
      IMAGE_TAG: ${{ needs.expose-vars.outputs.IMAGE_TAG }}
      IMAGE_CONTEXT: ${{ matrix.services.context }}
      IMAGE_DOCKERFILE: ${{ matrix.services.dockerfile }}
      BUILD_AMD64: ${{ needs.expose-vars.outputs.BUILD_AMD64 == 'true' }}
      BUILD_ARM64: ${{ needs.expose-vars.outputs.BUILD_ARM64 == 'true' }}
      LATEST_TAG: ${{ needs.expose-vars.outputs.LATEST_TAG == 'true' }}
      USE_QEMU: ${{ needs.expose-vars.outputs.USE_QEMU == 'true' }}
    secrets: inherit

  scan-trivy-images:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    needs:
    - expose-vars
    - build-docker
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    strategy:
      matrix:
        services:
        - name: server
          context: ./apps/server
          dockerfile: ./apps/server/Dockerfile
        - name: client
          context: ./apps/client
          dockerfile: ./apps/client/Dockerfile
    with:
      IMAGE: ghcr.io/${{ github.repository}}/${{ matrix.services.name }}:${{ needs.expose-vars.outputs.IMAGE_TAG }}
      PR_NUMBER: ${{ github.event.pull_request.number || github.event.number || '' }}
      GITHUB_SECURITY_TAB: false

  # Workaround for required status check in protection branches (see. https://github.com/orgs/community/discussions/13690)
  all-jobs-passed:
    name: Check jobs status
    runs-on: ubuntu-latest
    if: ${{ always() }}
    needs:
    - path-filter
    - expose-vars
    - build-docker
    - scan-trivy-conf
    - scan-trivy-images
    steps:
    - name: Check status of all required jobs
      run: |-
        NEEDS_CONTEXT='${{ toJson(needs) }}'
        JOB_IDS=$(echo "$NEEDS_CONTEXT" | jq -r 'keys[]')
        for JOB_ID in $JOB_IDS; do
          RESULT=$(echo "$NEEDS_CONTEXT" | jq -r ".[\"$JOB_ID\"].result")
          echo "$JOB_ID job result: $RESULT"
          if [[ $RESULT != "success" && $RESULT != "skipped" ]]; then
            echo "***"
            echo "Error: The $JOB_ID job did not pass."
            exit 1
          fi
        done
        echo "All jobs passed or were skipped."
```

### Pipeline CD avec release et déploiement

Ce workflow s'exécute sur les branches `develop` et `main` et effectue :
- Release automatisée avec release-please (supporte pré-releases sur `develop`)
- Build et push des images Docker versionnées
- Mise à jour automatique du chart Helm
- Synchronisation avec CPiN GitLab

```yaml
name: CD

on:
  push:
    branches:
    - develop
    - main
  workflow_dispatch:

env:
  BUILD_AMD64: true
  BUILD_ARM64: false
  LATEST_TAG: ${{ github.ref_name == 'main' }}
  USE_QEMU: true
  TAG_MAJOR_AND_MINOR: false
  AUTOMERGE_PRERELEASE: false
  AUTOMERGE_RELEASE: false
  PRERELEASE_BRANCH: develop
  RELEASE_BRANCH: main
  REBASE_PRERELEASE_BRANCH: true
  RELEASE_CONFIG_FILE: release-please-config.json
  RELEASE_MANIFEST_FILE: .release-please-manifest.json
  PRERELEASE_CONFIG_FILE: release-please-config-rc.json
  PRERELEASE_MANIFEST_FILE: .release-please-manifest-rc.json
  ENABLE_PRERELEASE: true

jobs:
  expose-vars:
    runs-on: ubuntu-latest
    outputs:
      BUILD_AMD64: ${{ env.BUILD_AMD64 }}
      BUILD_ARM64: ${{ env.BUILD_ARM64 }}
      LATEST_TAG: ${{ env.LATEST_TAG }}
      USE_QEMU: ${{ env.USE_QEMU }}
      TAG_MAJOR_AND_MINOR: ${{ env.TAG_MAJOR_AND_MINOR }}
      AUTOMERGE_PRERELEASE: ${{ env.AUTOMERGE_PRERELEASE }}
      AUTOMERGE_RELEASE: ${{ env.AUTOMERGE_RELEASE }}
      PRERELEASE_BRANCH: ${{ env.PRERELEASE_BRANCH }}
      RELEASE_BRANCH: ${{ env.RELEASE_BRANCH }}
      REBASE_PRERELEASE_BRANCH: ${{ env.REBASE_PRERELEASE_BRANCH }}
      RELEASE_CONFIG_FILE: ${{ env.RELEASE_CONFIG_FILE }}
      RELEASE_MANIFEST_FILE: ${{ env.RELEASE_MANIFEST_FILE }}
      PRERELEASE_CONFIG_FILE: ${{ env.PRERELEASE_CONFIG_FILE }}
      PRERELEASE_MANIFEST_FILE: ${{ env.PRERELEASE_MANIFEST_FILE }}
      ENABLE_PRERELEASE: ${{ env.ENABLE_PRERELEASE }}
    steps:
    - name: Exposing env vars
      run: echo "Exposing env vars"

  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    needs:
    - expose-vars
    permissions:
      issues: write
      pull-requests: write
      contents: write
    with:
      TAG_MAJOR_AND_MINOR: ${{ needs.expose-vars.outputs.TAG_MAJOR_AND_MINOR == 'true' }}
      AUTOMERGE_PRERELEASE: ${{ needs.expose-vars.outputs.AUTOMERGE_PRERELEASE == 'true' }}
      AUTOMERGE_RELEASE: ${{ needs.expose-vars.outputs.AUTOMERGE_RELEASE == 'true' }}
      PRERELEASE_BRANCH: ${{ needs.expose-vars.outputs.PRERELEASE_BRANCH }}
      RELEASE_BRANCH: ${{ needs.expose-vars.outputs.RELEASE_BRANCH }}
      REBASE_PRERELEASE_BRANCH: ${{ needs.expose-vars.outputs.REBASE_PRERELEASE_BRANCH == 'true' }}
      RELEASE_CONFIG_FILE: ${{ needs.expose-vars.outputs.RELEASE_CONFIG_FILE }}
      RELEASE_MANIFEST_FILE: ${{ needs.expose-vars.outputs.RELEASE_MANIFEST_FILE }}
      PRERELEASE_CONFIG_FILE: ${{ needs.expose-vars.outputs.PRERELEASE_CONFIG_FILE }}
      PRERELEASE_MANIFEST_FILE: ${{ needs.expose-vars.outputs.PRERELEASE_MANIFEST_FILE }}
      ENABLE_PRERELEASE: ${{ needs.expose-vars.outputs.ENABLE_PRERELEASE == 'true' }}
    # secrets:
    #   GH_PAT: ${{ secrets.GH_PAT }} # Required for automerge PRs

  build-docker:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    if: ${{ needs.release.outputs.release-created == 'true' }}
    needs:
    - expose-vars
    - release
    permissions:
      packages: write
      contents: read
    strategy:
      matrix:
        service:
        - name: server
          context: ./apps/server
          dockerfile: ./apps/server/Dockerfile
        - name: client
          context: ./apps/client
          dockerfile: ./apps/client/Dockerfile
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository}}/${{ matrix.service.name }}
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ${{ matrix.service.context }}
      IMAGE_DOCKERFILE: ${{ matrix.service.dockerfile }}
      BUILD_AMD64: ${{ needs.expose-vars.outputs.BUILD_AMD64 == 'true' }}
      BUILD_ARM64: ${{ needs.expose-vars.outputs.BUILD_ARM64 == 'true' }}
      LATEST_TAG: ${{ needs.expose-vars.outputs.LATEST_TAG == 'true' }}
      USE_QEMU: ${{ needs.expose-vars.outputs.USE_QEMU == 'true' }}
      TAG_MAJOR_AND_MINOR: ${{ needs.expose-vars.outputs.TAG_MAJOR_AND_MINOR == 'true' && needs.expose-vars.outputs.LATEST_TAG == 'true' }}
    secrets: inherit

  bump-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    needs:
    - expose-vars
    - release
    - build-docker
    if: ${{ needs.release.outputs.release-created == 'true' }}
    permissions:
      issues: write
      pull-requests: write
      contents: write
      actions: write
    with:
      RUN_MODE: caller
      WORKFLOW_NAME: update-chart.yml
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: ${{ github.ref_name == 'develop' && 'prerelease' || github.ref_name == 'main' && 'patch' }}
      PRERELEASE_IDENTIFIER: rc
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  sync-cpin:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    needs:
    - expose-vars
    - release
    - build-docker
    - bump-chart
    if: ${{ needs.release.outputs.release-created == 'true' }}
    with:
      GITLAB_URL: ${{ vars.GITLAB_URL }}
      GIT_MIRROR_PROJECT_ID: ${{ vars.GIT_MIRROR_PROJECT_ID }}
      BRANCH_TO_SYNC: ${{ format('v{0}', needs.release.outputs.version) }}
      SYNC_ALL: false
      REPOSITORY_NAME: ${{ vars.REPOSITORY_NAME }}
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.GIT_MIRROR_TOKEN }}
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
