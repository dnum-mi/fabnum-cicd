# `lint-commits.yml`

Valide que les messages de commit respectent la spécification [Conventional Commits](https://www.conventionalcommits.org/) en utilisant commitlint. Supporte à la fois les événements de pull request et de push avec des règles configurables.

## Inputs

| Input              | Type    | Description                                                                                    | Requis | Défaut                                                         |
| ------------------ | ------- | ---------------------------------------------------------------------------------------------- | ------ | -------------------------------------------------------------- |
| COMMITS_SOURCE     | string  | Source des commits à valider (`pr` pour les commits d'une PR, `push` pour les commits poussés) | Non    | `pr`                                                           |
| CONFIG_FILE        | string  | Chemin vers un fichier de configuration commitlint personnalisé                                | Non    | -                                                              |
| FAIL_ON_ERROR      | boolean | Échouer le workflow si des erreurs de lint sont détectées                                      | Non    | `true`                                                         |
| ALLOWED_TYPES      | string  | Liste des types de commit autorisés, séparés par des virgules                                  | Non    | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` |
| REQUIRE_SCOPE      | boolean | Exiger un scope dans les messages de commit                                                    | Non    | `false`                                                        |
| MAX_SUBJECT_LENGTH | number  | Longueur maximale de la ligne de sujet du commit                                               | Non    | `100`                                                          |

## Permissions

| Scope         | Accès | Description                                          |
| ------------- | ----- | ---------------------------------------------------- |
| contents      | read  | Lire l'historique des commits                        |
| pull-requests | read  | Lire les informations de PR pour la plage de commits |

## Notes

- **Format Conventional Commits** : `<type>(<scope>): <subject>`
- **Types par défaut** : feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Utilise le runtime Bun pour une installation et exécution rapides des packages.
- Utilise `@commitlint/cli` avec `@commitlint/config-conventional` comme configuration de base.
- Génère automatiquement une configuration commitlint si aucun fichier de configuration personnalisé n'est fourni.
- Produit un tableau récapitulatif dans le résumé du workflow GitHub Actions montrant le statut de chaque commit.
- Pour les PRs, valide tous les commits entre les branches base et head.
- Pour les événements push, valide les commits entre le SHA précédent et actuel.
- Les fichiers de configuration personnalisés (ex: `commitlint.config.js`) ont la priorité sur la configuration auto-générée.

## Exemples

### Exemple simple

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
```

### Exiger un scope

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      REQUIRE_SCOPE: true
```

### Types autorisés personnalisés

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      ALLOWED_TYPES: "feat,fix,docs,chore"
      MAX_SUBJECT_LENGTH: 72
```

### Utiliser un fichier de configuration personnalisé

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      CONFIG_FILE: ".commitlintrc.js"
```

### Vérification non bloquante

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      FAIL_ON_ERROR: false
```

### Pour les événements push

```yaml
on:
  push:
    branches:
    - main
    - develop

jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@main
    with:
      COMMITS_SOURCE: push
```
