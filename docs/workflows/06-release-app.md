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

## Configuration

Le workflow nécessite des fichiers de configuration release-please pour fonctionner correctement. Deux ensembles de fichiers sont requis si vous utilisez les pré-releases, un seul si vous ne faites que des releases stables.

### Fichiers requis

#### Pour les releases stables (sur `main`)

**`release-please-config.json`** - Configuration principale
```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "node",
      "initial-version": "0.1.0",
      "include-component-in-tag": false,
      "versioning": "prerelease",
      "prerelease": false,
      "prerelease-type": "",
      "extra-files": [],
      "changelog-sections": [
        {
          "type": "feat",
          "section": "Features",
          "hidden": false
        },
        {
          "type": "fix",
          "section": "Bug Fixes",
          "hidden": false
        }
      ]
    }
  }
}
```

**`.release-please-manifest.json`** - Manifest des versions
```json
{
  ".": "0.1.0"
}
```

#### Pour les pré-releases (sur `develop` ou autre)

**`release-please-config-rc.json`** - Configuration pré-release
```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "node",
      "initial-version": "0.1.0",
      "include-component-in-tag": false,
      "versioning": "prerelease",
      "prerelease": true,
      "prerelease-type": "rc",
      "extra-files": [],
      "changelog-sections": [
        {
          "type": "feat",
          "section": "Features",
          "hidden": false
        },
        {
          "type": "fix",
          "section": "Bug Fixes",
          "hidden": false
        }
      ]
    }
  }
}
```

**`.release-please-manifest-rc.json`** - Manifest des versions pré-release
```json
{
  ".": "0.1.0"
}
```

### Champs de configuration importants

| Champ                      | Description                                                       | Valeurs                                                           |
| -------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| `release-type`             | Type de projet (détermine comment parser les fichiers de version) | `node`, `python`, `go`, `rust`, `simple`, etc.                    |
| `initial-version`          | Version initiale si aucune version n'existe                       | Semver (ex: `0.1.0`)                                              |
| `include-component-in-tag` | Inclure le nom du composant dans le tag (pour monorepos)          | `true` ou `false`                                                 |
| `versioning`               | Stratégie de versioning                                           | `default`, `always-bump-patch`, `always-bump-minor`, `prerelease` |
| `prerelease`               | Activer le mode pré-release                                       | `true` ou `false`                                                 |
| `prerelease-type`          | Identifiant de pré-release                                        | `rc`, `alpha`, `beta`, ou vide pour releases stables              |
| `extra-files`              | Fichiers supplémentaires à mettre à jour avec la version          | Tableau de patterns (ex: `["docker/version.txt"]`)                |
| `changelog-sections`       | Sections du changelog selon les types de commits conventionnels   | Tableau d'objets `{type, section, hidden}`                        |

### Gestion de multiples identifiants de pré-release

Si vous souhaitez utiliser plusieurs identifiants (ex: `alpha`, `beta`, `rc`) pour différentes branches :

1. **Créez des configurations distinctes** pour chaque identifiant :
   - `release-please-config-alpha.json` avec `"prerelease-type": "alpha"`
   - `release-please-config-beta.json` avec `"prerelease-type": "beta"`
   - `release-please-config-rc.json` avec `"prerelease-type": "rc"`

2. **Créez des manifests distincts** pour chaque identifiant :
   - `.release-please-manifest-alpha.json`
   - `.release-please-manifest-beta.json`
   - `.release-please-manifest-rc.json`

3. **Configurez vos workflows** pour utiliser les bons fichiers selon la branche :

```yaml
# .github/workflows/release-dev.yml (branche dev)
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: true
      PRERELEASE_BRANCH: dev
      PRERELEASE_CONFIG_FILE: release-please-config-alpha.json
      PRERELEASE_MANIFEST_FILE: .release-please-manifest-alpha.json

# .github/workflows/release-staging.yml (branche staging)
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@main
    with:
      ENABLE_PRERELEASE: true
      PRERELEASE_BRANCH: staging
      PRERELEASE_CONFIG_FILE: release-please-config-beta.json
      PRERELEASE_MANIFEST_FILE: .release-please-manifest-beta.json
```

### Workflow de progression des versions

Le workflow typique de progression des versions est :

1. **Développement** (`dev`) : `1.0.0` → `1.0.1-alpha` → `1.0.1-alpha.1` → `1.0.1-alpha.2`
2. **Staging** (`staging`) : `1.0.1-alpha.2` → `1.0.1-beta` → `1.0.1-beta.1`
3. **Pré-production** (`preprod`) : `1.0.1-beta.1` → `1.0.1-rc` → `1.0.1-rc.1`
4. **Production** (`main`) : `1.0.1-rc.1` → `1.0.1` (release officielle)

**Important :** Les manifests doivent être synchronisés manuellement ou via scripts lors du passage d'une branche à l'autre pour maintenir la cohérence des versions.

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
