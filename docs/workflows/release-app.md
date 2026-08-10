# `release-app.yml`

Gestion automatisée des releases d'application avec [release-please](https://github.com/googleapis/release-please). Supporte les versions stables et les pré-releases.

## Inputs

| Input                    | Type    | Description                                                                                                                                                               | Requis | Défaut                             |
| ------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------- |
| ENABLE_PRERELEASE        | boolean | Activer la fonctionnalité de pré-release                                                                                                                                  | Non    | `false`                            |
| TAG_MAJOR_AND_MINOR      | boolean | Taguer les versions majeure et mineure                                                                                                                                    | Non    | `false`                            |
| RELEASE_ASSET_PATHS      | string  | Liste de chemins locaux séparés par des virgules à uploader comme assets de release (ex: `dist/app-linux-amd64,dist/app-darwin-amd64`)                                    | Non    |                                    |
| RELEASE_ARTIFACT_NAMES   | string  | Nom ou pattern glob d'artefacts (uploadés par des jobs précédents via `actions/upload-artifact`) à télécharger et attacher à la release (ex: `my-binaries` ou `my-app-*`) | Non    |                                    |
| PUBLISH_DRAFT_RELEASE    | boolean | Publier la release GitHub une fois les assets attachés. À activer avec `"draft": true` et `"force-tag-creation": true` dans la config release-please pour rester compatible avec les *immutable releases* (voir [Compatibilité avec les releases immuables](#compatibilité-avec-les-releases-immuables))                                    | Non    | `false`                            |
| AUTOMERGE_PRERELEASE     | boolean | Fusionner automatiquement la PR de pré-release                                                                                                                            | Non    | `false`                            |
| AUTOMERGE_RELEASE        | boolean | Fusionner automatiquement la PR de release                                                                                                                                | Non    | `false`                            |
| AUTOMERGE_METHOD         | string  | Méthode de fusion de la PR de release quand l'automerge est activé : `auto` (met en file d'attente, GitHub fusionne une fois les checks requis passés, nécessite *Allow auto-merge*) ou `admin` (fusionne immédiatement en contournant la protection de branche) | Non    | `auto`                              |
| RELEASE_PR_AUTHOR        | string  | Limiter l'action à la PR de release ouverte par ce login (tel que `gh` le rapporte, ex: `app/github-actions` pour un bot). Laisser vide pour dériver automatiquement l'auteur du credential utilisé. `*` désactive explicitement la vérification.        | Non    | `""`                                |
| PRERELEASE_BRANCH        | string  | Branche sur laquelle créer les pré-releases                                                                                                                               | Non    | `develop`                          |
| RELEASE_BRANCH           | string  | Branche sur laquelle créer les releases                                                                                                                                   | Non    | `main`                             |
| RELEASE_CONFIG_FILE      | string  | Fichier de configuration release-please pour les releases                                                                                                                 | Non    | `release-please-config.json`       |
| RELEASE_MANIFEST_FILE    | string  | Fichier manifest release-please pour les releases                                                                                                                         | Non    | `.release-please-manifest.json`    |
| PRERELEASE_CONFIG_FILE   | string  | Fichier de configuration release-please pour les pré-releases                                                                                                             | Non    | `release-please-config-rc.json`    |
| PRERELEASE_MANIFEST_FILE | string  | Fichier manifest release-please pour les pré-releases                                                                                                                     | Non    | `.release-please-manifest-rc.json` |
| RUNS_ON                  | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                    | Non    | `["ubuntu-24.04"]`                 |

## Secrets

| Secret            | Description                                                                                                                                    | Requis |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| APP_CLIENT_ID      | Client ID d'une GitHub App (ex: `Iv23li...`, PAS l'App ID numérique). À fournir avec `APP_PRIVATE_KEY` pour authentifier comme une App — prend le pas sur `GH_PAT`. Contrairement à `GITHUB_TOKEN`, un token App permet à la PR de release de déclencher les workflows `pull_request`. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY    | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                    | Non    |
| GH_PAT             | Personal Access Token GitHub. Alternative historique à `APP_CLIENT_ID`/`APP_PRIVATE_KEY`, toujours supportée mais l'authentification App est préférée. | Non    |

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
- Si `RELEASE_ARTIFACT_NAMES` est défini, les artefacts correspondant au pattern (uploadés par des jobs précédents via `actions/upload-artifact`) sont automatiquement téléchargés et attachés à la release GitHub.
- Si `RELEASE_ASSET_PATHS` est défini, les fichiers des chemins listés (séparés par des virgules) sont uploadés sur la release GitHub via `gh release upload` après sa création.
- Si `PUBLISH_DRAFT_RELEASE: true`, la release est publiée après l'upload des assets. Sans effet si la release n'est pas un brouillon, ce qui rend l'étape rejouable. Voir [Compatibilité avec les releases immuables](#compatibilité-avec-les-releases-immuables).
- Si `AUTOMERGE_*` est activé, un credential (App ou `GH_PAT`) est requis - sans credential, le job échoue plutôt que de silencieusement ne rien fusionner. `AUTOMERGE_METHOD` choisit `auto` (file d'attente, nécessite *Allow auto-merge*) ou `admin` (fusion immédiate en contournant la protection de branche). Voir [`authentication.md`](./authentication.md#automerge).
- La PR de release est recherchée via l'API (`gh pr list`) plutôt que par nom de branche, ce qui fonctionne aussi pour les monorepos où release-please ouvre une PR par composant. `RELEASE_PR_AUTHOR` permet de restreindre cette recherche à un auteur précis ; laissé vide, l'auteur est dérivé automatiquement du credential utilisé (App, `github-actions[bot]`, ou désactivé sous PAT).
- Fournir `APP_CLIENT_ID`/`APP_PRIVATE_KEY` (ou `GH_PAT`) permet à la PR de release de déclencher les workflows `pull_request`, ce que `GITHUB_TOKEN` ne peut jamais faire. Voir [`authentication.md`](./authentication.md).
- **Assère** que `PRERELEASE_BRANCH` contient tout ce qui est publié sur `RELEASE_BRANCH`, avant tout calcul de version — voir [Assertion de synchronisation](#assertion-de-synchronisation). Le rebase lui-même appartient à [`sync-prerelease-branch.yml`](./sync-prerelease-branch.md).

## Assertion de synchronisation

Sur un run de `PRERELEASE_BRANCH` (et seulement avec `ENABLE_PRERELEASE: true`), le workflow vérifie **avant tout calcul de version** que la branche de pré-release contient bien tout ce que la branche de release a publié. Rien à configurer : les deux noms de branches sont déjà des inputs.

C'est l'invariant dont dépend chaque version calculée ici : *la branche de pré-release, c'est la branche de release plus le seul travail non publié*. Quand il tient, release-please et un éventuel bump de chart partent de l'état publié. Quand il ne tient pas, ils partent de l'état où la branche a été figée, et émettent des versions **sous** celles déjà publiées — silencieusement.

Ce qui maintient l'invariant est un job que **l'appelant** ordonnance ([`sync-prerelease-branch.yml`](./sync-prerelease-branch.md)), et aucun workflow ne peut vérifier qu'il a bien été câblé. L'assertion attrape donc toutes les façons dont cela peut casser : job absent, `needs:` incomplet, synchronisation en échec, force-push, ou une forme de pipeline que personne n'avait anticipée.

En échec, le run s'arrête avec le nombre de commits manquants et la marche à suivre. Deux causes possibles :

- **Le job de synchronisation manque ou son `needs:` ne couvre pas tout le pipeline.** C'est le cas à corriger.
- **Un pipeline de release tourne encore sur la branche de release.** Le `concurrency` par défaut étant indexé sur la branche, un run de pré-release peut démarrer pendant une release : rejouer le run une fois celle-ci terminée suffit.

> L'assertion repose sur un appel `compare` de l'API GitHub plutôt que sur `git merge-base --is-ancestor` : l'ascendance exige un historique réel, et `actions/checkout` laisse le clone superficiel — la forme git imposerait un `--unshallow` du dépôt à chaque run de pré-release.

> Un dépôt qui n'a pas encore créé `RELEASE_BRANCH` n'a rien à comparer : l'assertion ne fait rien plutôt que de bloquer les premières pré-releases.

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

### Compatibilité avec les releases immuables

Les [*immutable releases*](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) gèlent une release GitHub dès sa publication : plus aucun asset ne peut être ajouté, modifié ou supprimé, et le tag associé ne peut plus être déplacé ni supprimé. Le seul ordonnancement supporté est donc **créer en brouillon → attacher les assets → publier**.

Ce n'est un sujet que si vous attachez des assets, via `RELEASE_ASSET_PATHS` ou `RELEASE_ARTIFACT_NAMES`. Sans assets, le workflow est déjà compatible et il n'y a rien à faire.

Trois changements sont nécessaires, dont deux dans votre propre configuration release-please :

```jsonc
{
  "packages": {
    ".": {
      // La release est créée en brouillon : les assets peuvent y être attachés.
      "draft": true,
      // GitHub ne crée pas le tag git tant que le brouillon n'est pas publié.
      // Sans ceci, release-please ne retrouve pas la version précédente.
      "force-tag-creation": true
    }
  }
}
```

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      RELEASE_ARTIFACT_NAMES: my-binaries
      PUBLISH_DRAFT_RELEASE: true
```

À noter :

- **`PUBLISH_DRAFT_RELEASE` est un opt-in explicite.** L'option `draft` de release-please sert aussi à publier manuellement une release après relecture ; le workflow ne publie donc jamais un brouillon sans qu'on le lui demande.
- **L'étape est idempotente.** Une release déjà publiée est laissée telle quelle, l'étape est rejouable sans risque.
- **Les évènements `release:` arrivent plus tard.** Un brouillon ne déclenche rien ; `release: published`/`released` part de l'étape de publication, une fois les assets attachés. Vérifiez les triggers de vos workflows consommateurs.
- **Un échec en cours de route laisse un brouillon**, qu'il suffit de publier (`gh release edit <tag> --draft=false`) ou de relancer. C'est précisément ce que cette configuration évite : sans elle, sur un dépôt en releases immuables, un upload d'asset échoué laisse une release publiée incomplète et **irrécupérable**, le nom du tag étant brûlé définitivement même après suppression de la release.
- **Les tags flottants `v<major>`/`v<major>.<minor>` de `TAG_MAJOR_AND_MINOR` ne sont pas concernés** : l'immutabilité ne verrouille que les tags portant une release publiée, et release-please n'en crée que sur `v<major>.<minor>.<patch>`.

> [!WARNING]
> [`release-helm.yml`](./release-helm.md) avec `CREATE_GITHUB_RELEASE: true` n'est **pas** compatible avec les releases immuables : `chart-releaser` crée la release puis attache le `.tgz` en deux appels séparés, sans option de brouillon ([helm/chart-releaser#591](https://github.com/helm/chart-releaser/issues/591)). Publier les charts sur un registre OCI à la place (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`) ne crée aucune release GitHub et n'est pas concerné.

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
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: true
      PRERELEASE_BRANCH: dev
      PRERELEASE_CONFIG_FILE: release-please-config-alpha.json
      PRERELEASE_MANIFEST_FILE: .release-please-manifest-alpha.json
```

```yaml
# .github/workflows/release-staging.yml (branche staging)
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: true
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_PRERELEASE: true
      AUTOMERGE_RELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Avec authentification GitHub App (PR de release avec CI)

Nécessaire pour que la PR de release déclenche ses propres workflows `pull_request`. Voir [`authentication.md`](./authentication.md).

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
      AUTOMERGE_METHOD: auto
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Workflow release uniquement (sans pré-release)

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: false
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Avec upload d'artefacts supplémentaires

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - run: make build
      - uses: actions/upload-artifact@v4
        with:
          name: my-binaries
          path: dist/

  release:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      RELEASE_ARTIFACT_NAMES: my-binaries
      RELEASE_ASSET_PATHS: dist/app-linux-amd64,dist/app-darwin-amd64
```

### Avec fichiers de configuration personnalisés

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: true
      RELEASE_CONFIG_FILE: custom-release-config.json
      PRERELEASE_CONFIG_FILE: custom-prerelease-config.json
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```
