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

## Skills pour agents (Claude Code)

Des *skills* permettent à votre agent de code d'appliquer ces workflows et ces git hooks **dans votre projet** :
il écrit le `ci.yml` / `cd.yml` avec les bons appels, les bonnes permissions et sans les pièges connus. Ils ne
lancent rien eux-mêmes et ne touchent jamais à la valeur d'un secret.

| Skill | Pour demander à l'agent de… | Docs |
| ----- | --------------------------- | ---- |
| [fabnum-cicd-pipeline](./skills/fabnum-cicd-pipeline/SKILL.md) | mettre en place ou relire la CI/CD : lint, tests, build, scans, porte `check-jobs` | [docs](./docs/workflows/01-introduction.md) |
| [fabnum-cicd-auth](./skills/fabnum-cicd-auth/SKILL.md) | choisir et configurer `GITHUB_TOKEN`, GitHub App ou PAT | [docs](./docs/workflows/05-authentication.md) |
| [fabnum-cicd-release](./skills/fabnum-cicd-release/SKILL.md) | automatiser les releases, la pré-release, la publication npm / PyPI | [docs](./docs/workflows/50-release-app.md) |
| [fabnum-cicd-helm](./skills/fabnum-cicd-helm/SKILL.md) | lint, versionner, publier et signer un chart Helm | [docs](./docs/workflows/51-release-helm.md) |
| [fabnum-cicd-git-hooks](./skills/fabnum-cicd-git-hooks/SKILL.md) | installer les git hooks locaux | [docs](./docs/git-hooks/01-introduction.md) |

### Installer les skills (pas à pas)

**Avant de commencer**, il faut :

- [Claude Code](https://code.claude.com/docs/en/overview) **2.1.275 ou plus récent** : `claude --version` affiche la version ;
- `git` et un accès à github.com (le dépôt est public) ;
- recommandé, mais pas obligatoire : la [CLI GitHub `gh`](https://cli.github.com/), connectée avec `gh auth login`.
  L'agent s'en sert pour vérifier que vos secrets existent (leurs **noms**, jamais leurs valeurs) et lire les logs
  d'un run en échec. Sans elle, il vous indique quoi vérifier dans l'interface GitHub.

**1. Ajouter le catalogue.** Dans un terminal :

```bash
claude plugin marketplace add dnum-mi/fabnum-cicd
```

Cela n'enregistre que la liste des plugins disponibles : aucun skill n'est encore actif.

**2. Installer le plugin.**

```bash
claude plugin install fabnum-cicd@fabnum-cicd
```

Ou, depuis une session Claude Code, en une seule étape (qui remplace aussi l'étape 1) :

```
/plugin install fabnum-cicd --marketplace dnum-mi/fabnum-cicd
```

**3. Vérifier.** Lancez `claude` dans votre projet, puis tapez `/reload-plugins` (inutile si vous venez de démarrer la
session). Dans un terminal :

```bash
claude plugin list
```

La ligne `fabnum-cicd@fabnum-cicd` doit apparaître avec le statut `enabled`. Dans Claude Code, la commande `/skills`
liste les cinq skills `fabnum-cicd-…`.

**4. Les essayer.** Dans votre projet, demandez par exemple :

- « Mets en place la CI de ce projet avec les workflows fabnum-cicd. »
- « Ma PR de release ne déclenche pas la CI, pourquoi ? »
- « Relis mon `.github/workflows/ci.yml` selon les recommandations fabnum-cicd. »
- « Installe les git hooks de fabnum-cicd. »

L'agent charge le skill adapté tout seul. Vous pouvez aussi le nommer : « utilise le skill fabnum-cicd-auth ».
Relisez toujours ce qu'il écrit avant de committer : c'est vous qui créez les secrets dans GitHub.

**Mettre à jour** (les skills suivent la branche `main`) :

```bash
claude plugin marketplace update fabnum-cicd
claude plugin update fabnum-cicd@fabnum-cicd
```

**Désinstaller** : `claude plugin uninstall fabnum-cicd@fabnum-cicd`.

**Pour toute l'équipe**, versionnez dans le `.claude/settings.json` de votre projet : Claude Code proposera
l'installation à l'ouverture du dossier.

```json
{
  "extraKnownMarketplaces": {
    "fabnum-cicd": { "source": { "source": "github", "repo": "dnum-mi/fabnum-cicd" } }
  },
  "enabledPlugins": { "fabnum-cicd@fabnum-cicd": true }
}
```

**Sans plugin** (autre agent compatible avec le standard [Agent Skills](https://agentskills.io/specification)) :
copier les skills dans le dossier de votre agent.

```bash
git clone --depth 1 https://github.com/dnum-mi/fabnum-cicd.git
cp -r fabnum-cicd/skills/* ~/.agents/skills/
```

Les liens des skills vers `docs/` ne résolvent alors plus : l'agent s'appuie sur le catalogue du skill
`fabnum-cicd-pipeline` et sur la [documentation en ligne](./docs/workflows/01-introduction.md).

Détails et maintenance : [docs/skills](./docs/skills/01-introduction.md).

## Git Hooks

Validation locale du code avant commit et push. Consultez l'[introduction](./docs/git-hooks/01-introduction.md) pour les instructions d'installation.

| Hook                                                              | Type         | Description                         | Docs                                      |
| ----------------------------------------------------------------- | ------------ | ----------------------------------- | ----------------------------------------- |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | Validation Conventional Commits     | [docs](./docs/git-hooks/02-commit-msg.md) |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | Lint JS/TS/JSON/MD/YAML avec ESLint | [docs](./docs/git-hooks/03-pre-commit.md) |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | Lint des charts Helm                | [docs](./docs/git-hooks/03-pre-commit.md) |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | Lint YAML avec `yamllint`           | [docs](./docs/git-hooks/03-pre-commit.md) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | Vérification des signatures GPG     | [docs](./docs/git-hooks/04-pre-push.md)   |
