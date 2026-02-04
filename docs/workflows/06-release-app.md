# `release-app.yml`

Gestion automatisée des releases d'application avec [release-please](https://github.com/googleapis/release-please). Supporte les versions stables et les pré-releases.

## Inputs

| Input                    | Type    | Description                                                                            | Requis | Défaut                             |
| ------------------------ | ------- | -------------------------------------------------------------------------------------- | ------ | ---------------------------------- |
| ENABLE_PRERELEASE        | boolean | Activer la fonctionnalité de pré-release                                               | Non    | `false`                            |
| TAG_MAJOR_AND_MINOR      | boolean | Taguer les versions majeure et mineure                                                 | Non    | `false`                            |
| AUTOMERGE_PRERELEASE     | boolean | Fusionner automatiquement la PR de pré-release                                         | Non    | `false`                            |
| AUTOMERGE_RELEASE        | boolean | Fusionner automatiquement la PR de release                                             | Non    | `false`                            |
| PRERELEASE_BRANCH        | string  | Branche sur laquelle créer les pré-releases                                            | Non    | `develop`                          |
| RELEASE_BRANCH           | string  | Branche sur laquelle créer les releases                                                | Non    | `main`                             |
| REBASE_PRERELEASE_BRANCH | boolean | Rebaser la branche de pré-release après une release                                    | Non    | `false`                            |
| RELEASE_CONFIG_FILE      | string  | Fichier de configuration release-please pour les releases                              | Non    | `release-please-config.json`       |
| RELEASE_MANIFEST_FILE    | string  | Fichier manifest release-please pour les releases                                      | Non    | `.release-please-manifest.json`    |
| PRERELEASE_CONFIG_FILE   | string  | Fichier de configuration release-please pour les pré-releases                          | Non    | `release-please-config-rc.json`    |
| PRERELEASE_MANIFEST_FILE | string  | Fichier manifest release-please pour les pré-releases                                  | Non    | `.release-please-manifest-rc.json` |
| RUNS_ON                  | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`                 |

## Secrets

| Secret | Description                                                | Requis |
| ------ | ---------------------------------------------------------- | ------ |
| GH_PAT | Personal Access Token GitHub (nécessaire pour l'automerge) | Non    |

## Outputs

| Output          | Description                        |
| --------------- | ---------------------------------- |
| release-created | Indique si une release a été créée |
| version         | Version semver complète            |
| major-tag       | Tag de version majeure             |
| minor-tag       | Tag de version mineure             |
| patch-tag       | Tag de version patch               |

## Permissions

| Scope         | Accès | Description                                                          |
| ------------- | ----- | -------------------------------------------------------------------- |
| contents      | write | Créer des tags/commits et mettre à jour les fichiers manifest        |
| issues        | write | Créer ou mettre à jour les issues ouvertes par l'outil de release    |
| pull-requests | write | Créer, mettre à jour et fusionner optionnellement les PRs de release |

## Notes

- Définir `ENABLE_PRERELEASE: false` pour désactiver toute fonctionnalité de pré-release et travailler uniquement avec les branches de release.
- Les fichiers de configuration et manifest sont configurables via les inputs, avec des valeurs par défaut sensées pour les workflows de release et pré-release.
- Sur `RELEASE_BRANCH` (par défaut `main`), utilise les fichiers spécifiés par `RELEASE_CONFIG_FILE` et `RELEASE_MANIFEST_FILE`.
- Sur `PRERELEASE_BRANCH` (par défaut `develop`), utilise les fichiers spécifiés par `PRERELEASE_CONFIG_FILE` et `PRERELEASE_MANIFEST_FILE` (seulement quand `ENABLE_PRERELEASE: true`).
- Si `TAG_MAJOR_AND_MINOR: true`, crée les tags `v<major>` et `v<major>.<minor>` après la création d'une release.
- Si `AUTOMERGE_*` est activé et qu'un PAT est fourni, tente de fusionner automatiquement la PR de release.
- Optionnellement, rebase `PRERELEASE_BRANCH` sur `RELEASE_BRANCH` après une release quand `REBASE_PRERELEASE_BRANCH: true` (seulement quand `ENABLE_PRERELEASE: true`).

## Exemples

### Exemple simple

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: true
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_PRERELEASE: true
      AUTOMERGE_RELEASE: true
      REBASE_PRERELEASE_BRANCH: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Workflow release uniquement (sans pré-release)

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: false
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Avec fichiers de configuration personnalisés

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: true
      RELEASE_CONFIG_FILE: custom-release-config.json
      PRERELEASE_CONFIG_FILE: custom-prerelease-config.json
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```
