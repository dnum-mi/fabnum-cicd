# Introduction aux Workflows GitHub Actions

Les workflows GitHub Actions réutilisables permettent de standardiser et centraliser vos pipelines CI/CD. Ce dépôt propose un ensemble complet de workflows prêts à l'emploi.

## Liste des workflows disponibles

### Authentification

- [**Authentification**](./authentication.md) - Choisir et configurer un credential GitHub (`GITHUB_TOKEN`, GitHub App ou PAT) pour les workflows qui en ont besoin

### Linting & Validation

- [**Lint Commits**](./lint-commits.md) - Validation des messages de commit (Conventional Commits)
- [**Lint Helm**](./lint-helm.md) - Lint des charts Helm avec chart-testing
- [**Lint Helm Schema**](./lint-helm-schema.md) - Validation des values Helm contre un JSON Schema
- [**Lint YAML**](./lint-yaml.md) - Lint des fichiers YAML avec yamllint

### Build & Release

- [**Build Docker**](./build-docker.md) - Build et push (optionnel) d'images Docker multi-architecture
- [**Attest Docker**](./attest-docker.md) - Génération d'attestations de sécurité (provenance SLSA, SBOM, signature cosign) pour une image construite
- [**Release App**](./release-app.md) - Gestion automatisée des releases d'application avec release-please
- [**Release NPM**](./release-npm.md) - Publication de paquets sur un registre NPM (npmjs.org, GitHub Packages, registre privé)
- [**Release Helm**](./release-helm.md) - Publication de charts Helm sur registres OCI via chart-releaser (dépôt de charts dédié)
- [**Release Helm (local)**](./release-helm-local.md) - Publication d'un chart Helm hébergé dans un monorepo applicatif
- [**Update Helm Chart**](./update-helm-chart.md) - Mise à jour automatique des versions de charts Helm
- [**Dispatch Helm Chart**](./dispatch-helm-chart.md) - Déclenchement de la mise à jour d'un chart hébergé dans un dépôt séparé
- [**Sync Prerelease Branch**](./sync-prerelease-branch.md) - Resynchronisation de la branche de pré-release après une release (à placer en dernier)

### Sécurité & Qualité

- [**Scan SonarQube**](./scan-sonarqube.md) - Analyse de qualité du code avec SonarQube
- [**Scan Trivy**](./scan-trivy.md) - Analyse de vulnérabilités avec Trivy
- [**Scan Gitleaks**](./scan-gitleaks.md) - Analyse de l'historique git complet à la recherche de secrets divulgués

### Tests

- [**Test Helm**](./test-helm.md) - Test d'installation des charts Helm dans un cluster Kind
- [**Test Docker**](./test-docker.md) - Exécution d'une commande dans une image Docker construite (registre ou tarball)

### Utilitaires

- [**Clean Cache**](./clean-cache.md) - Nettoyage du cache GitHub Actions
- [**Clean Images**](./clean-images.md) - Nettoyage des images de conteneurs sur GHCR
- [**Sync CPiN**](./sync-cpin.md) - Synchronisation avec l'instance GitLab CPiN

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
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read

  # Exemple : Build Docker
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      contents: read
      packages: write
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ github.sha }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile

  # Exemple : Scan de sécurité
  security:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    permissions:
      contents: read
      packages: read
      pull-requests: write
      security-events: write
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    if: ${{ !github.event.pull_request.draft }}
    permissions:
      pull-requests: read
      contents: read

  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@v0
    needs:
    - path-filter
    - expose-vars
    if: ${{ needs.path-filter.outputs.apps == 'true' }}
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    needs:
    - path-filter
    - expose-vars
    # Les changements de workflows rebuildent aussi : ils peuvent changer la
    # façon dont l'image est produite.
    if: ${{ needs.path-filter.outputs.apps == 'true' || needs.path-filter.outputs.ci == 'true' }}
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
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
  # `needs:` doit lister TOUS les jobs du pipeline : un job absent peut échouer
  # sans bloquer la pull request, ce qui vide le gate de son sens.
  all-jobs-passed:
    name: Check jobs status
    runs-on: ubuntu-latest
    if: ${{ always() }}
    needs:
    - path-filter
    - expose-vars
    - lint-commits
    - scan-sonarqube
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
      RELEASE_CONFIG_FILE: ${{ env.RELEASE_CONFIG_FILE }}
      RELEASE_MANIFEST_FILE: ${{ env.RELEASE_MANIFEST_FILE }}
      PRERELEASE_CONFIG_FILE: ${{ env.PRERELEASE_CONFIG_FILE }}
      PRERELEASE_MANIFEST_FILE: ${{ env.PRERELEASE_MANIFEST_FILE }}
      ENABLE_PRERELEASE: ${{ env.ENABLE_PRERELEASE }}
    steps:
    - name: Exposing env vars
      run: echo "Exposing env vars"

  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
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
      RELEASE_CONFIG_FILE: ${{ needs.expose-vars.outputs.RELEASE_CONFIG_FILE }}
      RELEASE_MANIFEST_FILE: ${{ needs.expose-vars.outputs.RELEASE_MANIFEST_FILE }}
      PRERELEASE_CONFIG_FILE: ${{ needs.expose-vars.outputs.PRERELEASE_CONFIG_FILE }}
      PRERELEASE_MANIFEST_FILE: ${{ needs.expose-vars.outputs.PRERELEASE_MANIFEST_FILE }}
      ENABLE_PRERELEASE: ${{ needs.expose-vars.outputs.ENABLE_PRERELEASE == 'true' }}
    # secrets:
    #   GH_PAT: ${{ secrets.GH_PAT }} # Required for automerge PRs

  build-docker:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    needs:
    - expose-vars
    - release
    - build-docker
    if: ${{ needs.release.outputs.release-created == 'true' }}
    # Le dispatch s'authentifie auprès du dépôt chart avec le credential fourni
    # et n'écrit rien ici.
    permissions: {}
    with:
      WORKFLOW_NAME: update-app-version.yml
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      # UPGRADE_TYPE par défaut ('auto') : le dépôt chart dérive le niveau
      # du delta d'appVersion.
      APP_VERSION: ${{ needs.release.outputs.version }}
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  # En dernier : transmet à `develop` le commit de release que `main` vient de
  # gagner, pour que sa prochaine rc parte de l'état publié et non d'un état
  # figé. `needs:` doit lister tous les jobs qui COMMITENT sur `main` - ici
  # `release` seul, le bump du chart atterrissant dans l'autre dépôt. Voir
  # [`sync-prerelease-branch.yml`](./sync-prerelease-branch.md) pour les cas où
  # il en faut plus, et ceux où le job est inutile.
  sync-prerelease-branch:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-prerelease-branch.yml@v0
    needs:
    - expose-vars
    - release
    if: ${{ github.ref_name == 'main' && needs.release.outputs.release-created == 'true' }}
    permissions:
      contents: write
    with:
      RELEASE_BRANCH: main
      PRERELEASE_BRANCH: develop

  sync-cpin:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@v0
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
    - "charts/**"

jobs:
  lint-helm:
    if: github.event_name == 'pull_request'
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: ci/configs/ct.yaml

  test-helm:
    if: github.event_name == 'pull_request'
    needs: lint-helm
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: ci/configs/ct.yaml

  release-helm:
    if: github.event_name == 'push'
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      # Canaux laissés par défaut : GitHub Release + index.yaml sur gh-pages.
      # Ajouter PUBLISH_OCI: true pour publier aussi sur un registre OCI.
      CHARTS_DIR: ./charts
```

## Configuration

### Secrets requis

Certains workflows nécessitent des secrets GitHub. Voici un résumé :

| Secret              | Workflows concernés                                                    | Description                                                                  |
| ------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `APP_CLIENT_ID`     | release-app, release-helm, update-helm-chart, dispatch-helm-chart, build-docker, scan-trivy    | Client ID d'une GitHub App - voir [`authentication.md`](./authentication.md)    |
| `APP_PRIVATE_KEY`   | release-app, release-helm, update-helm-chart, dispatch-helm-chart, build-docker, scan-trivy    | Clé privée (PEM) de la GitHub App                                               |
| `GH_PAT`            | release-app, release-helm, update-helm-chart, dispatch-helm-chart, build-docker, scan-trivy    | GitHub Personal Access Token (alternative à la GitHub App)                     |
| `SONAR_TOKEN`       | scan-sonarqube                                                              | Token d'authentification SonarQube                                              |
| `SONAR_PROJECT_KEY` | scan-sonarqube                                                              | Clé du projet SonarQube                                                          |
| `GIT_MIRROR_TOKEN`  | sync-cpin                                                                   | Token GitLab pour synchronisation                                               |

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
