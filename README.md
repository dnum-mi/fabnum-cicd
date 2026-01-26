# Fabrique Numérique - CI/CD

Ce dépôt sert d'emplacement centralisé pour les workflows GitHub réutilisables. En définissant des workflows partagés ici, nous rationalisons le processus de maintien de la cohérence et de la qualité dans tous les dépôts.

## Table des matières

- [Fabrique Numérique - CI/CD](#fabrique-numérique---cicd)
  - [Table des matières](#table-des-matières)
  - [Workflows GitHub réutilisables](#workflows-github-réutilisables)
    - [Build](#build)
      - [Build Docker](#build-docker)
        - [Inputs](#inputs)
        - [Exemple](#exemple)
    - [Lint](#lint)
      - [Lint des commits (Conventional Commits)](#lint-des-commits-conventional-commits)
        - [Inputs](#inputs-1)
        - [Exemple](#exemple-1)
        - [Exemple avec configuration personnalisée](#exemple-avec-configuration-personnalisée)
      - [Lint des charts Helm](#lint-des-charts-helm)
        - [Inputs](#inputs-2)
        - [Exemple](#exemple-2)
    - [Release](#release)
      - [Release application](#release-application)
        - [Inputs](#inputs-3)
        - [Secrets](#secrets)
        - [Outputs](#outputs)
        - [Exemple](#exemple-3)
      - [Release Helm charts](#release-helm-charts)
        - [Inputs](#inputs-4)
        - [Exemple](#exemple-4)
    - [Scan](#scan)
      - [Analyse de code Sonarqube](#analyse-de-code-sonarqube)
        - [Inputs](#inputs-5)
        - [Secrets](#secrets-1)
        - [Exemple](#exemple-5)
      - [Analyse de vulnérabilités Trivy](#analyse-de-vulnérabilités-trivy)
        - [Inputs](#inputs-6)
        - [Exemple](#exemple-6)
    - [Test](#test)
      - [Test des charts Helm](#test-des-charts-helm)
        - [Inputs](#inputs-7)
        - [Exemple](#exemple-7)
    - [Utilitaires](#utilitaires)
      - [Nettoyage du cache](#nettoyage-du-cache)
        - [Inputs](#inputs-8)
        - [Exemple](#exemple-8)
      - [Synchronisation CPiN](#synchronisation-cpin)
        - [Inputs](#inputs-9)
        - [Secrets](#secrets-2)
        - [Exemple](#exemple-9)
      - [Mise à jour de chart Helm](#mise-à-jour-de-chart-helm)
        - [Inputs](#inputs-10)
        - [Secrets](#secrets-3)
        - [Exemple (mode caller)](#exemple-mode-caller)
        - [Exemple (mode called)](#exemple-mode-called)
  - [Git hooks](#git-hooks)
    - [Installation](#installation)
  - [Contribution](#contribution)
  - [Licence](#licence)

## Workflows GitHub réutilisables

Le dossier `.github/workflows` est utilisé pour stocker et gérer les workflows. Les workflows suivants sont disponibles :

| Workflow                                                           | Description                                                                   |
| ------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| [build-docker.yml](./.github/workflows/build-docker.yml)           | Build et push d'images Docker multi-architecture.                             |
| [clean-cache.yml](./.github/workflows/clean-cache.yml)             | Nettoyage du cache GitHub Actions et des images GHCR.                         |
| [lint-commits.yml](./.github/workflows/lint-commits.yml)           | Vérifie que les messages de commit respectent le format Conventional Commits. |
| [lint-helm.yml](./.github/workflows/lint-helm.yml)                 | Lint des charts Helm avec chart-testing et helm-docs.                         |
| [release-app.yml](./.github/workflows/release-app.yml)             | Gestion des releases d'application avec release-please.                       |
| [release-helm.yml](./.github/workflows/release-helm.yml)           | Publication des charts Helm sur un registre OCI.                              |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml)       | Analyse de la qualité du code avec SonarQube.                                 |
| [scan-trivy.yml](./.github/workflows/scan-trivy.yml)               | Analyse de vulnérabilités avec Trivy.                                         |
| [sync-cpin.yml](./.github/workflows/sync-cpin.yml)                 | Synchronisation avec l'instance GitLab CPiN.                                  |
| [test-helm.yml](./.github/workflows/test-helm.yml)                 | Test d'installation des charts Helm dans un cluster Kind.                     |
| [update-helm-chart.yml](./.github/workflows/update-helm-chart.yml) | Mise à jour automatique de la version d'un chart Helm.                        |

---

### Build

#### Build Docker

Build et push d'images Docker multi-architecture (amd64/arm64) vers un registre de conteneurs.

##### Inputs

| Input                 | Description                                                                       | Requis | Défaut  |
| --------------------- | --------------------------------------------------------------------------------- | ------ | ------- |
| `IMAGE_NAME`          | Nom complet de l'image à construire (ex: `ghcr.io/my-org/my-image`).              | Oui    | -       |
| `IMAGE_TAG`           | Tag utilisé pour l'image.                                                         | Oui    | -       |
| `IMAGE_DOCKERFILE`    | Chemin vers le Dockerfile.                                                        | Oui    | -       |
| `IMAGE_CONTEXT`       | Chemin du contexte de build.                                                      | Oui    | -       |
| `LATEST_TAG`          | Taguer également l'image avec `latest`.                                           | Non    | `false` |
| `TAG_MAJOR_AND_MINOR` | Créer des tags pour les versions majeure et mineure (ex: `1.2.3` → `1.2` et `1`). | Non    | `false` |
| `BUILD_AMD64`         | Build pour l'architecture amd64.                                                  | Non    | `true`  |
| `BUILD_ARM64`         | Build pour l'architecture arm64.                                                  | Non    | `true`  |
| `USE_QEMU`            | Utiliser l'émulateur QEMU pour arm64.                                             | Non    | `false` |
| `REGISTRY_USERNAME`   | Nom d'utilisateur pour le registre (auto pour ghcr.io).                           | Non    | -       |
| `REGISTRY_PASSWORD`   | Mot de passe pour le registre (auto pour ghcr.io).                                | Non    | -       |

##### Exemple

```yaml
name: Build

on:
  push:
    tags:
      - "v*"

jobs:
  build:
    name: Build Docker image
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@main
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository }}/app
      IMAGE_TAG: ${{ github.ref_name }}
      IMAGE_DOCKERFILE: ./Dockerfile
      IMAGE_CONTEXT: ./
      LATEST_TAG: true
      BUILD_AMD64: true
      BUILD_ARM64: true
```

---

### Lint

#### Lint des commits (Conventional Commits)

Ce workflow vérifie que les messages de commit respectent le format [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

##### Inputs

| Input                | Description                                                                                     | Requis | Défaut                                                         |
| -------------------- | ----------------------------------------------------------------------------------------------- | ------ | -------------------------------------------------------------- |
| `COMMITS_SOURCE`     | Source des commits à valider (`pr` pour les commits d'une PR, `push` pour les commits poussés). | Non    | `pr`                                                           |
| `CONFIG_FILE`        | Chemin vers un fichier de configuration commitlint personnalisé.                                | Non    | -                                                              |
| `FAIL_ON_ERROR`      | Échouer le workflow si des erreurs de lint sont détectées.                                      | Non    | `true`                                                         |
| `ALLOWED_TYPES`      | Liste des types de commit autorisés, séparés par des virgules.                                  | Non    | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` |
| `REQUIRE_SCOPE`      | Exiger un scope dans les messages de commit.                                                    | Non    | `false`                                                        |
| `MAX_SUBJECT_LENGTH` | Longueur maximale de la ligne de sujet du commit.                                               | Non    | `100`                                                          |

##### Exemple

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

jobs:
  lint-commits:
    name: Lint commits
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
```

##### Exemple avec configuration personnalisée

```yaml
jobs:
  lint-commits:
    name: Lint commits
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      COMMITS_SOURCE: pr
      ALLOWED_TYPES: "feat,fix,docs,chore"
      REQUIRE_SCOPE: true
      MAX_SUBJECT_LENGTH: 72
```

#### Lint des charts Helm

Lint des charts Helm avec [chart-testing](https://github.com/helm/chart-testing) et validation de la documentation avec [helm-docs](https://github.com/norwoodj/helm-docs).

##### Inputs

| Input               | Description                                            | Requis | Défaut   |
| ------------------- | ------------------------------------------------------ | ------ | -------- |
| `CT_CONF_PATH`      | Chemin vers le fichier de configuration chart-testing. | Oui    | -        |
| `HELM_DOCS_VERSION` | Version de helm-docs à utiliser.                       | Non    | `1.14.2` |
| `LINT_CHARTS`       | Exécuter le lint des charts.                           | Non    | `true`   |
| `LINT_DOCS`         | Exécuter la validation de la documentation.            | Non    | `true`   |

##### Exemple

```yaml
name: CI

on:
  pull_request:
    branches:
      - "**"

jobs:
  lint-helm:
    name: Lint Helm charts
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: ./ci/configs/ct.yaml
```

---

### Release

#### Release application

Gestion automatisée des releases d'application avec [release-please](https://github.com/googleapis/release-please). Supporte les versions stables et les pré-releases.

##### Inputs

| Input                      | Description                                                    | Requis | Défaut                             |
| -------------------------- | -------------------------------------------------------------- | ------ | ---------------------------------- |
| `ENABLE_PRERELEASE`        | Activer la fonctionnalité de pré-release.                      | Non    | `false`                            |
| `TAG_MAJOR_AND_MINOR`      | Taguer les versions majeure et mineure.                        | Non    | `false`                            |
| `AUTOMERGE_PRERELEASE`     | Fusionner automatiquement la PR de pré-release.                | Non    | `false`                            |
| `AUTOMERGE_RELEASE`        | Fusionner automatiquement la PR de release.                    | Non    | `false`                            |
| `PRERELEASE_BRANCH`        | Branche sur laquelle créer les pré-releases.                   | Non    | `develop`                          |
| `RELEASE_BRANCH`           | Branche sur laquelle créer les releases.                       | Non    | `main`                             |
| `REBASE_PRERELEASE_BRANCH` | Rebaser la branche de pré-release après une release.           | Non    | `false`                            |
| `RELEASE_CONFIG_FILE`      | Fichier de configuration release-please pour les releases.     | Non    | `release-please-config.json`       |
| `RELEASE_MANIFEST_FILE`    | Fichier manifest release-please pour les releases.             | Non    | `.release-please-manifest.json`    |
| `PRERELEASE_CONFIG_FILE`   | Fichier de configuration release-please pour les pré-releases. | Non    | `release-please-config-rc.json`    |
| `PRERELEASE_MANIFEST_FILE` | Fichier manifest release-please pour les pré-releases.         | Non    | `.release-please-manifest-rc.json` |

##### Secrets

| Secret   | Description                                                 | Requis |
| -------- | ----------------------------------------------------------- | ------ |
| `GH_PAT` | Personal Access Token GitHub (nécessaire pour l'automerge). | Non    |

##### Outputs

| Output            | Description                         |
| ----------------- | ----------------------------------- |
| `release-created` | Indique si une release a été créée. |
| `version`         | Version semver complète.            |
| `major-tag`       | Tag de version majeure.             |
| `minor-tag`       | Tag de version mineure.             |
| `patch-tag`       | Tag de version patch.               |

##### Exemple

```yaml
name: Release

on:
  push:
    branches:
      - main
      - develop

jobs:
  release:
    name: Release
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: true
      PRERELEASE_BRANCH: develop
      RELEASE_BRANCH: main
      TAG_MAJOR_AND_MINOR: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

#### Release Helm charts

Publication des charts Helm sur un registre OCI (ghcr.io) avec [chart-releaser](https://github.com/helm/chart-releaser-action).

##### Inputs

| Input        | Description                                                           | Requis | Défaut     |
| ------------ | --------------------------------------------------------------------- | ------ | ---------- |
| `CHARTS_DIR` | Répertoire contenant les charts Helm.                                 | Non    | `./charts` |
| `HELM_REPOS` | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules). | Non    | -          |

##### Exemple

```yaml
name: Release Charts

on:
  push:
    branches:
      - main
    paths:
      - "charts/**"

jobs:
  release:
    name: Release Helm charts
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@main
    with:
      CHARTS_DIR: ./charts
      HELM_REPOS: "bitnami=https://charts.bitnami.com/bitnami"
```

---

### Scan

#### Analyse de code Sonarqube

Analyse de la qualité du code avec [SonarQube](https://www.sonarqube.org/), incluant le support des rapports de couverture de tests.

##### Inputs

| Input                    | Description                                                   | Requis | Défaut                |
| ------------------------ | ------------------------------------------------------------- | ------ | --------------------- |
| `SONAR_URL`              | URL du serveur SonarQube.                                     | Oui    | -                     |
| `SOURCES_PATH`           | Chemins vers le code source à analyser (ex: `apps,packages`). | Non    | -                     |
| `SONAR_EXTRA_ARGS`       | Arguments supplémentaires pour SonarQube.                     | Non    | -                     |
| `COVERAGE_IMPORT`        | Activer l'import d'artefact de couverture.                    | Non    | `false`               |
| `COVERAGE_ARTIFACT_NAME` | Nom de l'artefact de couverture à importer.                   | Non    | `unit-tests-coverage` |
| `COVERAGE_ARTIFACT_PATH` | Chemin de téléchargement de l'artefact de couverture.         | Non    | `./coverage`          |

##### Secrets

| Secret              | Description                               | Requis |
| ------------------- | ----------------------------------------- | ------ |
| `SONAR_TOKEN`       | Token d'authentification SonarQube.       | Oui    |
| `SONAR_PROJECT_KEY` | Clé d'identification du projet SonarQube. | Oui    |

##### Exemple

```yaml
name: CI

on:
  pull_request:
    branches:
      - "**"

jobs:
  scan-sonarqube:
    name: Scan code (SonarQube)
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: ${{ vars.SONAR_URL }}
      SOURCES_PATH: apps,packages
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

#### Analyse de vulnérabilités Trivy

Analyse de vulnérabilités avec [Trivy](https://github.com/aquasecurity/trivy) pour les images Docker et les fichiers de configuration.

##### Inputs

| Input                 | Description                                                 | Requis | Défaut  |
| --------------------- | ----------------------------------------------------------- | ------ | ------- |
| `IMAGE`               | Image Docker à analyser (ex: `ghcr.io/org/repo/image:tag`). | Non    | -       |
| `PATH`                | Chemin du dépôt à analyser (scan de configuration).         | Non    | -       |
| `FORMAT`              | Format du rapport (`table`, `sarif`, `json`).               | Non    | `table` |
| `PR_NUMBER`           | Numéro de la PR (pour les commentaires).                    | Non    | -       |
| `GITHUB_SECURITY_TAB` | Lier les résultats à l'onglet Security de GitHub.           | Non    | `false` |
| `REGISTRY_USERNAME`   | Nom d'utilisateur pour le registre (auto pour ghcr.io).     | Non    | -       |
| `REGISTRY_PASSWORD`   | Mot de passe pour le registre (auto pour ghcr.io).          | Non    | -       |

##### Exemple

```yaml
name: CI

on:
  pull_request:
    branches:
      - "**"

jobs:
  scan-trivy-image:
    name: Scan image (Trivy)
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/${{ github.repository }}/app:latest
      FORMAT: sarif
      GITHUB_SECURITY_TAB: true

  scan-trivy-config:
    name: Scan config (Trivy)
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      PATH: ./
      FORMAT: table
```

---

### Test

#### Test des charts Helm

Test d'installation des charts Helm dans un cluster [Kind](https://kind.sigs.k8s.io/) avec chart-testing.

##### Inputs

| Input          | Description                                            | Requis | Défaut |
| -------------- | ------------------------------------------------------ | ------ | ------ |
| `CT_CONF_PATH` | Chemin vers le fichier de configuration chart-testing. | Oui    | -      |

##### Exemple

```yaml
name: CI

on:
  pull_request:
    branches:
      - "**"

jobs:
  test-helm:
    name: Test Helm charts
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@main
    with:
      CT_CONF_PATH: ./ci/configs/ct.yaml
```

---

### Utilitaires

#### Nettoyage du cache

Nettoyage du cache GitHub Actions et suppression des images orphelines dans ghcr.io.

##### Inputs

| Input                       | Description                                                                      | Requis | Défaut  |
| --------------------------- | -------------------------------------------------------------------------------- | ------ | ------- |
| `PR_NUMBER`                 | Numéro de la PR associée au cache.                                               | Non    | -       |
| `BRANCH_NAME`               | Nom de la branche associée au cache.                                             | Non    | -       |
| `IMAGE`                     | Nom de l'image à supprimer de ghcr.io (ex: `ghcr.io/owner/repo/service:pr-123`). | Non    | -       |
| `CLEAN_GH_CACHE`            | Nettoyer le cache GitHub Actions.                                                | Non    | `true`  |
| `CLEAN_GHCR_IMAGE`          | Supprimer l'image spécifiée de ghcr.io.                                          | Non    | `false` |
| `CLEAN_ORPHANED_GHCR_IMAGE` | Supprimer les images orphelines (SHA uniquement) de ghcr.io.                     | Non    | `false` |

##### Exemple

```yaml
name: Cleanup

on:
  pull_request:
    types:
      - closed

jobs:
  cleanup:
    name: Cleanup cache
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@main
    with:
      PR_NUMBER: ${{ github.event.pull_request.number }}
      CLEAN_GH_CACHE: true
      CLEAN_GHCR_IMAGE: true
      IMAGE: ghcr.io/${{ github.repository }}/app:pr-${{ github.event.pull_request.number }}
```

#### Synchronisation CPiN

Déclenche la synchronisation d'un dépôt vers l'instance GitLab CPiN.

##### Inputs

| Input                   | Description                                                         | Requis | Défaut |
| ----------------------- | ------------------------------------------------------------------- | ------ | ------ |
| `GITLAB_URL`            | URL de l'instance GitLab CPiN.                                      | Non    | -      |
| `GIT_MIRROR_PROJECT_ID` | ID du projet GitLab du miroir.                                      | Non    | -      |
| `BRANCH_TO_SYNC`        | Branche Git à synchroniser.                                         | Non    | -      |
| `REPOSITORY_NAME`       | Nom du dépôt GitLab à synchroniser.                                 | Non    | -      |
| `ADDITIONAL_VARIABLES`  | Variables supplémentaires au format JSON (ex: `{"VAR1":"value1"}`). | Non    | -      |

##### Secrets

| Secret             | Description                           | Requis |
| ------------------ | ------------------------------------- | ------ |
| `GIT_MIRROR_TOKEN` | Token GitLab pour la synchronisation. | Non    |

##### Exemple

```yaml
name: Sync to CPiN

on:
  push:
    branches:
      - main

jobs:
  sync:
    name: Sync to CPiN
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-cpin.yml@main
    with:
      GITLAB_URL: ${{ vars.CPIN_GITLAB_URL }}
      GIT_MIRROR_PROJECT_ID: ${{ vars.CPIN_PROJECT_ID }}
      BRANCH_TO_SYNC: main
      REPOSITORY_NAME: my-repo
    secrets:
      GIT_MIRROR_TOKEN: ${{ secrets.CPIN_TOKEN }}
```

#### Mise à jour de chart Helm

Mise à jour automatique de la version d'un chart Helm lors d'une nouvelle release d'application. Fonctionne en mode `caller` (déclenche le workflow dans un autre dépôt) ou `called` (met à jour le chart dans le dépôt courant).

##### Inputs

| Input                   | Description                                                      | Requis | Défaut                   |
| ----------------------- | ---------------------------------------------------------------- | ------ | ------------------------ |
| `RUN_MODE`              | Mode d'exécution (`caller` ou `called`).                         | Oui    | -                        |
| `CHART_NAME`            | Nom du dossier du chart (dans `/charts`).                        | Oui    | -                        |
| `APP_VERSION`           | Version de l'application à injecter dans Chart.yaml.             | Oui    | -                        |
| `WORKFLOW_NAME`         | Nom du workflow à déclencher (mode `caller`).                    | Non    | `update-app-version.yml` |
| `CHART_REPO`            | Nom du dépôt du chart (ex: `org/helm-charts`, mode `caller`).    | Non    | -                        |
| `UPGRADE_TYPE`          | Type de mise à jour (`major`, `minor`, `patch` ou `prerelease`). | Non    | `patch`                  |
| `PRERELEASE_IDENTIFIER` | Identifiant de pré-release (si `UPGRADE_TYPE` est `prerelease`). | Non    | `rc`                     |

##### Secrets

| Secret   | Description                   | Requis |
| -------- | ----------------------------- | ------ |
| `GH_PAT` | Personal Access Token GitHub. | Non    |

##### Exemple (mode caller)

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

jobs:
  update-chart:
    name: Update Helm chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    with:
      RUN_MODE: caller
      CHART_REPO: my-org/helm-charts
      CHART_NAME: my-app
      APP_VERSION: ${{ github.ref_name }}
      UPGRADE_TYPE: patch
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

##### Exemple (mode called)

```yaml
name: Update Chart

on:
  workflow_dispatch:
    inputs:
      RUN_MODE:
        required: true
        type: string
      CHART_NAME:
        required: true
        type: string
      APP_VERSION:
        required: true
        type: string

jobs:
  update-chart:
    name: Update Helm chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@main
    with:
      RUN_MODE: ${{ inputs.RUN_MODE }}
      CHART_NAME: ${{ inputs.CHART_NAME }}
      APP_VERSION: ${{ inputs.APP_VERSION }}
```

---

## Git hooks

Scripts de hooks Git réutilisables pour assurer la qualité du code localement.

| Nom                                                               | Type         | Description                                                                                                          | Configuration                                                |
| ----------------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | Vérifie le pattern [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) dans le message de commit. | -                                                            |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | Lint des fichiers JS, TS, JSON, MD et YAML avec [ESLint](https://github.com/eslint/eslint).                          | [eslint.config.js](./git-hooks/configs/eslint.config.js)     |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | Lint des charts Helm avec [chart-testing](https://github.com/helm/chart-testing).                                    | [chart-testing.yaml](./git-hooks/configs/chart-testing.yaml) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | Vérifie si les commits sont signés.                                                                                  | -                                                            |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | Lint des fichiers YAML avec [yamllint](https://github.com/adrienverge/yamllint).                                     | [yamllint.yaml](./git-hooks/configs/yamllint.yaml)           |

### Installation

Exécutez la commande suivante pour télécharger et installer un hook dans le dépôt Git courant :

```sh
# Définir le fichier cible et l'URL de téléchargement
TARGET_FILE=".git/hooks/<git_hook>"
URL="https://raw.githubusercontent.com/dnum-mi/fabnum-cicd/main/git-hooks/<git_hook>"

# Vérifier si le fichier existe déjà
if [ -f "$TARGET_FILE" ]; then
  # Le fichier existe, télécharger le contenu et supprimer le shebang de la première ligne
  curl -fsSL "$URL" | sed '1 s/^#!.*//' >> "$TARGET_FILE"
else
  # Le fichier n'existe pas, créer le fichier avec le contenu téléchargé
  curl -fsSL "$URL" -o "$TARGET_FILE"
fi

# S'assurer que le fichier est exécutable
chmod +x "$TARGET_FILE"
```

> **Note :** Vérifiez que les fichiers de configuration associés aux différents hooks sont présents localement dans le dépôt et que les hooks Git pointent correctement vers ces configurations.

---

## Contribution

Les contributions sont les bienvenues ! Pour proposer des modifications :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feat/nouvelle-fonctionnalite`)
3. Committez vos changements en respectant les [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
4. Poussez vers la branche (`git push origin feat/nouvelle-fonctionnalite`)
5. Ouvrez une Pull Request

## Licence

Ce projet est sous licence [MIT](./LICENSE).
