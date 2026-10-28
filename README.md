# Fabrique Numérique - CI/CD

Ce dépôt centralise les [workflows GitHub Actions réutilisables](https://docs.github.com/en/actions/sharing-automations/reusing-workflows) et les git hooks pour maintenir la cohérence et la qualité du code dans tous les dépôts de la Fabrique Numérique.

## Utilisation rapide

Référencez un workflow avec `uses` dans votre fichier de workflow :

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
```

> [!TIP]
> Consultez l'[introduction](./docs/workflows/01-introduction.md) pour un guide complet avec des exemples de pipelines CI, CD et Helm.

## Workflows

### Linting & Validation

| Workflow                                                         | Description                                                                                     | Docs                                         |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------- |
| [lint-commits.yml](./.github/workflows/lint-commits.yml)         | Validation des messages de commit ([Conventional Commits](https://www.conventionalcommits.org)) | [docs](./docs/workflows/10-lint-commits.md)     |
| [lint-helm.yml](./.github/workflows/lint-helm.yml)               | Lint des charts Helm avec `chart-testing`                                                       | [docs](./docs/workflows/11-lint-helm.md)        |
| [lint-helm-schema.yml](./.github/workflows/lint-helm-schema.yml) | Validation des values Helm contre un JSON Schema avec `check-jsonschema`                        | [docs](./docs/workflows/12-lint-helm-schema.md) |
| [lint-yaml.yml](./.github/workflows/lint-yaml.yml)               | Lint des fichiers YAML avec `yamllint`                                                          | [docs](./docs/workflows/14-lint-yaml.md)        |
| [lint-python.yml](./.github/workflows/lint-python.yml) | Lint et vérification de types d'un projet Python avec `uv` | [docs](./docs/workflows/15-lint-python.md) |

### Tests

| Workflow                                               | Description                                                          | Docs                                    |
| ------------------------------------------------------ | -------------------------------------------------------------------- | --------------------------------------- |
| [test-helm.yml](./.github/workflows/test-helm.yml)     | Tests d'installation des charts dans un cluster Kind                 | [docs](./docs/workflows/20-test-helm.md)   |
| [test-docker.yml](./.github/workflows/test-docker.yml) | Exécution d'une commande dans une image Docker (registre ou tarball) | [docs](./docs/workflows/24-test-docker.md) |
| [test-python.yml](./.github/workflows/test-python.yml) | Tests d'un projet Python avec `uv`, rapport de couverture en artefact | [docs](./docs/workflows/22-test-python.md) |

### Build

| Workflow                                                   | Description                                                                    | Docs                                         |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------- |
| [build-docker.yml](./.github/workflows/build-docker.yml)   | Build et push (optionnel) d'images Docker multi-architecture (`amd64`/`arm64`)  | [docs](./docs/workflows/30-build-docker.md)  |
| [build-python.yml](./.github/workflows/build-python.yml) | Construction d'un paquet Python, contrôle de la wheel et envoi de `dist/` comme artefact | [docs](./docs/workflows/32-build-python.md) |
| [attest-docker.yml](./.github/workflows/attest-docker.yml) | Génération d'attestations de sécurité (provenance SLSA, SBOM, signature cosign) | [docs](./docs/workflows/31-attest-docker.md) |

### Sécurité & Qualité

| Workflow                                                     | Description                                                       | Docs                                       |
| ------------------------------------------------------------ | ----------------------------------------------------------------- | ------------------------------------------ |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml) | Analyse qualité du code avec SonarQube                            | [docs](./docs/workflows/40-scan-sonarqube.md) |
| [scan-trivy.yml](./.github/workflows/scan-trivy.yml)         | Analyse de vulnérabilités (images, config, filesystem) avec Trivy | [docs](./docs/workflows/41-scan-trivy.md)     |
| [scan-gitleaks.yml](./.github/workflows/scan-gitleaks.yml)   | Analyse de l'historique git complet à la recherche de secrets divulgués | [docs](./docs/workflows/42-scan-gitleaks.md) |
| [scan-zizmor.yml](./.github/workflows/scan-zizmor.yml)       | Audit des workflows GitHub Actions avec `zizmor` (injections, permissions, identifiants persistés) | [docs](./docs/workflows/45-scan-zizmor.md)   |

### Release

| Workflow                                                           | Description                                                                                               | Docs                                          |
| ------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| [release-app.yml](./.github/workflows/release-app.yml)             | Gestion automatisée des releases avec `release-please` (tags, changelogs, pré-releases)                   | [docs](./docs/workflows/50-release-app.md)       |
| [release-helm.yml](./.github/workflows/release-helm.yml)           | Publication de charts Helm via `chart-releaser` sur registre OCI et/ou dépôt Helm classique (dépôt de charts dédié) | [docs](./docs/workflows/51-release-helm.md)      |
| [release-helm-local.yml](./.github/workflows/release-helm-local.yml) | Publication d'un chart Helm hébergé dans un monorepo applicatif, sans `chart-releaser`                  | [docs](./docs/workflows/52-release-helm-local.md) |
| [update-helm-chart.yml](./.github/workflows/update-helm-chart.yml) | Mise à jour de la version d'un chart Helm hébergé dans le dépôt appelant                                  | [docs](./docs/workflows/53-update-helm-chart.md) |
| [dispatch-helm-chart.yml](./.github/workflows/dispatch-helm-chart.yml) | Déclenchement de la mise à jour d'un chart Helm hébergé dans un dépôt séparé                          | [docs](./docs/workflows/54-dispatch-helm-chart.md) |
| [release-npm.yml](./.github/workflows/release-npm.yml)             | Publication de paquets sur un registre NPM (npmjs.org, GitHub Packages, registre privé)                   | [docs](./docs/workflows/55-release-npm.md)       |
| [attest-helm.yml](./.github/workflows/attest-helm.yml)             | Signatures cosign et provenance SLSA des charts Helm publiés sur un registre OCI                                      | [docs](./docs/workflows/56-attest-helm.md)       |
| [sync-prerelease-branch.yml](./.github/workflows/sync-prerelease-branch.yml) | Resynchronisation de la branche de pré-release sur la branche de release après une release (job à placer en dernier) | [docs](./docs/workflows/57-sync-prerelease-branch.md) |
| [release-pypi.yml](./.github/workflows/release-pypi.yml)           | Publication sur PyPI (ou un autre index) des distributions construites par `build-python.yml`, publication de confiance et vérification d'installation | [docs](./docs/workflows/58-release-pypi.md)       |

### Utilitaires

| Workflow                                               | Description                                          | Docs                                    |
| ------------------------------------------------------ | ---------------------------------------------------- | --------------------------------------- |
| [clean-cache.yml](./.github/workflows/clean-cache.yml)   | Nettoyage du cache GitHub Actions                    | [docs](./docs/workflows/70-clean-cache.md)  |
| [clean-images.yml](./.github/workflows/clean-images.yml) | Nettoyage des images de conteneurs sur GHCR          | [docs](./docs/workflows/71-clean-images.md) |
| [sync-cpin.yml](./.github/workflows/sync-cpin.yml)       | Synchronisation vers l'instance GitLab CPiN          | [docs](./docs/workflows/72-sync-cpin.md)    |
| [check-jobs.yml](./.github/workflows/check-jobs.yml)     | Agrège le résultat de tous les jobs en un seul check exigible par un ruleset | [docs](./docs/workflows/80-check-jobs.md)   |

### Secrets requis

Certains workflows nécessitent des secrets à configurer dans les **Settings > Secrets** du dépôt :

| Secret              | Workflows                      | Description                                                 |
| ------------------- | ------------------------------ | ----------------------------------------------------------- |
| `GH_PAT`            | release-app, update-helm-chart, dispatch-helm-chart | Personal Access Token GitHub (pour automerge et cross-repo) |
| `SONAR_TOKEN`       | scan-sonarqube                 | Token d'authentification SonarQube                          |
| `SONAR_PROJECT_KEY` | scan-sonarqube                 | Clé du projet SonarQube                                     |
| `GIT_MIRROR_TOKEN`  | sync-cpin                      | Token GitLab pour la synchronisation CPiN                   |

## Skills pour agents (Claude Code, OpenCode)

Des *skills* permettent à votre agent de code (Claude Code, OpenCode) d'appliquer ces workflows et ces git hooks **dans votre projet** :
il écrit le `ci.yml` / `cd.yml` avec les bons appels, les bonnes permissions et sans les pièges connus. Ils ne
lancent rien eux-mêmes et ne touchent jamais à la valeur d'un secret.

| Skill | Pour demander à l'agent de… | Docs |
| ----- | --------------------------- | ---- |
| [fabnum-cicd-pipeline](./skills/fabnum-cicd-pipeline/SKILL.md) | mettre en place ou relire la CI/CD : lint, tests, build, scans, porte `check-jobs` | [docs](./docs/workflows/01-introduction.md) |
| [fabnum-cicd-auth](./skills/fabnum-cicd-auth/SKILL.md) | choisir et configurer `GITHUB_TOKEN`, GitHub App ou PAT | [docs](./docs/workflows/05-authentication.md) |
| [fabnum-cicd-release](./skills/fabnum-cicd-release/SKILL.md) | automatiser les releases, la pré-release, la publication npm / PyPI | [docs](./docs/workflows/50-release-app.md) |
| [fabnum-cicd-helm](./skills/fabnum-cicd-helm/SKILL.md) | lint, versionner, publier et signer un chart Helm | [docs](./docs/workflows/51-release-helm.md) |
| [fabnum-cicd-git-hooks](./skills/fabnum-cicd-git-hooks/SKILL.md) | installer les git hooks locaux | [docs](./docs/git-hooks/01-introduction.md) |

### Installer les skills

Les skills suivent le standard [Agent Skills](https://agentskills.io/specification) et fonctionnent avec Claude Code
et OpenCode. Le guide pas à pas, pensé pour un premier usage, est dans
[docs/skills/02-installation.md](./docs/skills/02-installation.md). En bref :

**Claude Code** (2.1.275 ou plus récent), en mode plugin :

```bash
claude plugin marketplace add dnum-mi/fabnum-cicd
claude plugin install fabnum-cicd@fabnum-cicd
```

**OpenCode** (1.18 ou plus récent), en mode plugin, dans le `opencode.json` du projet (ou `~/.config/opencode/opencode.json`) :

```json
{ "plugin": ["fabnum-cicd@git+https://github.com/dnum-mi/fabnum-cicd.git"] }
```

`gh` authentifié est recommandé, pas obligatoire : l'agent s'en sert pour vérifier que vos secrets existent (leurs
**noms**, jamais leurs valeurs). Détails, mise à jour, partage à l'équipe et vérification : voir le
[guide d'installation](./docs/skills/02-installation.md).

## Git Hooks

Validation locale du code avant commit et push. Consultez l'[introduction](./docs/git-hooks/01-introduction.md) pour les instructions d'installation.

| Hook                                                              | Type         | Description                         | Docs                                      |
| ----------------------------------------------------------------- | ------------ | ----------------------------------- | ----------------------------------------- |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | Validation Conventional Commits     | [docs](./docs/git-hooks/02-commit-msg.md) |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | Lint JS/TS/JSON/MD/YAML avec ESLint | [docs](./docs/git-hooks/03-pre-commit.md) |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | Lint des charts Helm                | [docs](./docs/git-hooks/03-pre-commit.md) |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | Lint YAML avec `yamllint`           | [docs](./docs/git-hooks/03-pre-commit.md) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | Vérification des signatures GPG     | [docs](./docs/git-hooks/04-pre-push.md)   |
