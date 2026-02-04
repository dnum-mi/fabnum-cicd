# Fabrique Numérique - CI/CD

Ce dépôt centralise les workflows GitHub Actions réutilisables et les git hooks pour maintenir la cohérence et la qualité du code dans tous les dépôts de la Fabrique Numérique.

## Documentation

### Workflows GitHub Actions

Workflows réutilisables pour l'intégration et le déploiement continu :

- [01 - Introduction](./docs/workflows/01-introduction.md) - Vue d'ensemble et utilisation
- [02 - Build Docker](./docs/workflows/02-build-docker.md) - Build d'images multi-architecture
- [03 - Clean Cache](./docs/workflows/03-clean-cache.md) - Nettoyage du cache GitHub Actions et GHCR
- [04 - Lint Commits](./docs/workflows/04-lint-commits.md) - Validation Conventional Commits
- [05 - Lint Helm](./docs/workflows/05-lint-helm.md) - Lint des charts Helm
- [06 - Release App](./docs/workflows/06-release-app.md) - Gestion automatisée des releases
- [07 - Release Helm](./docs/workflows/07-release-helm.md) - Publication de charts Helm
- [08 - Scan SonarQube](./docs/workflows/08-scan-sonarqube.md) - Analyse qualité du code
- [09 - Scan Trivy](./docs/workflows/09-scan-trivy.md) - Analyse de vulnérabilités
- [10 - Sync CPiN](./docs/workflows/10-sync-cpin.md) - Synchronisation GitLab CPiN
- [11 - Test Helm](./docs/workflows/11-test-helm.md) - Tests d'installation des charts
- [12 - Update Helm Chart](./docs/workflows/12-update-helm-chart.md) - Mise à jour des versions de charts

### Git Hooks

Validation locale du code avant commit et push :

- [01 - Introduction](./docs/git-hooks/01-introduction.md) - Installation et configuration
- [02 - Hooks commit-msg](./docs/git-hooks/02-commit-msg.md) - Validation des messages de commit
- [03 - Hooks pre-commit](./docs/git-hooks/03-pre-commit.md) - Lint avant commit
- [04 - Hooks pre-push](./docs/git-hooks/04-pre-push.md) - Vérification des signatures GPG

## Workflows disponibles

| Workflow                                                           | Description                                          |
| ------------------------------------------------------------------ | ---------------------------------------------------- |
| [build-docker.yml](./.github/workflows/build-docker.yml)           | Build et push d'images Docker multi-architecture     |
| [clean-cache.yml](./.github/workflows/clean-cache.yml)             | Nettoyage du cache GitHub Actions et des images GHCR |
| [lint-commits.yml](./.github/workflows/lint-commits.yml)           | Validation Conventional Commits                      |
| [lint-helm.yml](./.github/workflows/lint-helm.yml)                 | Lint des charts Helm avec chart-testing              |
| [release-app.yml](./.github/workflows/release-app.yml)             | Gestion des releases avec release-please             |
| [release-helm.yml](./.github/workflows/release-helm.yml)           | Publication de charts Helm sur registres OCI         |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml)       | Analyse qualité du code avec SonarQube               |
| [scan-trivy.yml](./.github/workflows/scan-trivy.yml)               | Analyse de vulnérabilités avec Trivy                 |
| [sync-cpin.yml](./.github/workflows/sync-cpin.yml)                 | Synchronisation vers GitLab CPiN                     |
| [test-helm.yml](./.github/workflows/test-helm.yml)                 | Tests d'installation des charts dans Kind            |
| [update-helm-chart.yml](./.github/workflows/update-helm-chart.yml) | Mise à jour automatique des versions de charts       |

## Git Hooks disponibles

| Hook                                                              | Type         | Description                         |
| ----------------------------------------------------------------- | ------------ | ----------------------------------- |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | Validation Conventional Commits     |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | Lint JS/TS/JSON/MD/YAML avec ESLint |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | Lint des charts Helm                |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | Vérification des signatures GPG     |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | Lint YAML avec yamllint             |

Consultez la [documentation des git hooks](./docs/git-hooks/01-introduction.md) pour les instructions d'installation.

## Contribution

Les contributions sont les bienvenues ! Pour proposer des modifications :

1. Forkez le dépôt
2. Créez une branche pour votre fonctionnalité (`git checkout -b feat/nouvelle-fonctionnalite`)
3. Committez vos changements en respectant les [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
4. Poussez vers la branche (`git push origin feat/nouvelle-fonctionnalite`)
5. Ouvrez une Pull Request

## Licence

Ce projet est sous licence [MIT](./LICENSE).
