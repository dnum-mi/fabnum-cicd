# Fabrique Numérique - CI/CD

Ce dépôt centralise les [workflows GitHub Actions réutilisables](https://docs.github.com/en/actions/sharing-automations/reusing-workflows) et les git hooks pour maintenir la cohérence et la qualité du code dans tous les dépôts de la Fabrique Numérique.

## Utilisation rapide

Référencez un workflow avec `uses` dans votre fichier de workflow :

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
```

> [!TIP]
> Consultez l'[introduction](./docs/workflows/introduction.md) pour un guide complet avec des exemples de pipelines CI, CD et Helm.

## Workflows

### Linting & Validation

| Workflow                                                         | Description                                                                                     | Docs                                         |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------- |
| [lint-commits.yml](./.github/workflows/lint-commits.yml)         | Validation des messages de commit ([Conventional Commits](https://www.conventionalcommits.org)) | [docs](./docs/workflows/lint-commits.md)     |
| [lint-helm.yml](./.github/workflows/lint-helm.yml)               | Lint des charts Helm avec `chart-testing`                                                       | [docs](./docs/workflows/lint-helm.md)        |
| [lint-helm-schema.yml](./.github/workflows/lint-helm-schema.yml) | Validation des values Helm contre un JSON Schema avec `check-jsonschema`                        | [docs](./docs/workflows/lint-helm-schema.md) |
| [lint-yaml.yml](./.github/workflows/lint-yaml.yml)               | Lint des fichiers YAML avec `yamllint`                                                          | [docs](./docs/workflows/lint-yaml.md)        |

### Build & Release

| Workflow                                                           | Description                                                                                   | Docs                                          |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- | --------------------------------------------- |
| [build-docker.yml](./.github/workflows/build-docker.yml)           | Build et push d'images Docker multi-architecture (`amd64`/`arm64`) avec support d'attestation | [docs](./docs/workflows/build-docker.md)      |
| [release-app.yml](./.github/workflows/release-app.yml)             | Gestion automatisée des releases avec `release-please` (tags, changelogs, pré-releases)       | [docs](./docs/workflows/release-app.md)       |
| [release-helm.yml](./.github/workflows/release-helm.yml)           | Publication de charts Helm sur registres OCI                                                  | [docs](./docs/workflows/release-helm.md)      |
| [update-helm-chart.yml](./.github/workflows/update-helm-chart.yml) | Mise à jour automatique des versions de charts Helm                                           | [docs](./docs/workflows/update-helm-chart.md) |

### Sécurité & Qualité

| Workflow                                                     | Description                                                       | Docs                                       |
| ------------------------------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------ |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml) | Analyse qualité du code avec SonarQube                            | [docs](./docs/workflows/scan-sonarqube.md) |
| [scan-trivy.yml](./.github/workflows/scan-trivy.yml)         | Analyse de vulnérabilités (images, config, filesystem) avec Trivy | [docs](./docs/workflows/scan-trivy.md)     |

### Tests

| Workflow                                           | Description                                          | Docs                                  |
| -------------------------------------------------- | ---------------------------------------------------- | ------------------------------------- |
| [test-helm.yml](./.github/workflows/test-helm.yml) | Tests d'installation des charts dans un cluster Kind | [docs](./docs/workflows/test-helm.md) |

### Utilitaires

| Workflow                                               | Description                                          | Docs                                    |
| ------------------------------------------------------ | ---------------------------------------------------- | --------------------------------------- |
| [clean-cache.yml](./.github/workflows/clean-cache.yml) | Nettoyage du cache GitHub Actions et des images GHCR | [docs](./docs/workflows/clean-cache.md) |
| [sync-cpin.yml](./.github/workflows/sync-cpin.yml)     | Synchronisation vers l'instance GitLab CPiN          | [docs](./docs/workflows/sync-cpin.md)   |

### Secrets requis

Certains workflows nécessitent des secrets à configurer dans les **Settings > Secrets** du dépôt :

| Secret              | Workflows                      | Description                                                 |
| ------------------- | ------------------------------ | ----------------------------------------------------------- |
| `GH_PAT`            | release-app, update-helm-chart | Personal Access Token GitHub (pour automerge et cross-repo) |
| `SONAR_TOKEN`       | scan-sonarqube                 | Token d'authentification SonarQube                          |
| `SONAR_PROJECT_KEY` | scan-sonarqube                 | Clé du projet SonarQube                                     |
| `GIT_MIRROR_TOKEN`  | sync-cpin                      | Token GitLab pour la synchronisation CPiN                   |

## Git Hooks

Validation locale du code avant commit et push. Consultez l'[introduction](./docs/git-hooks/01-introduction.md) pour les instructions d'installation.

| Hook                                                              | Type         | Description                         | Docs                                      |
| ----------------------------------------------------------------- | ------------ | ----------------------------------- | ----------------------------------------- |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | Validation Conventional Commits     | [docs](./docs/git-hooks/02-commit-msg.md) |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | Lint JS/TS/JSON/MD/YAML avec ESLint | [docs](./docs/git-hooks/03-pre-commit.md) |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | Lint des charts Helm                | [docs](./docs/git-hooks/03-pre-commit.md) |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | Lint YAML avec `yamllint`           | [docs](./docs/git-hooks/03-pre-commit.md) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | Vérification des signatures GPG     | [docs](./docs/git-hooks/04-pre-push.md)   |
