# `lint-commits.yml`

Valide que les messages de commit respectent la spécification [Conventional Commits](https://www.conventionalcommits.org/) en utilisant commitlint. Supporte à la fois les événements de pull request et de push avec des règles configurables.

## Inputs

| Input              | Type    | Description                                                                                                                                     | Requis | Défaut                                                         |
| ------------------ | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------ | -------------------------------------------------------------- |
| COMMITS_SOURCE     | string  | Source des commits à valider (`pr` pour les commits d'une PR, `push` pour les commits poussés)                                                  | Non    | `pr`                                                           |
| CONFIG_FILE        | string  | Chemin vers un fichier de configuration commitlint personnalisé                                                                                 | Non    | -                                                              |
| FAIL_ON_ERROR      | boolean | Échouer le workflow si des erreurs de lint sont détectées                                                                                       | Non    | `true`                                                         |
| ALLOWED_TYPES      | string  | Liste des types de commit autorisés, séparés par des virgules                                                                                   | Non    | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` |
| REQUIRE_SCOPE      | boolean | Exiger un scope dans les messages de commit                                                                                                     | Non    | `false`                                                        |
| MAX_SUBJECT_LENGTH | number  | Longueur maximale de l'en-tête du commit (la première ligne complète, préfixe `type(scope): ` inclus - règle `header-max-length` de commitlint) | Non    | `100`                                                          |
| RUNS_ON            | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                          | Non    | `["ubuntu-24.04"]`                                             |

## Permissions

| Scope    | Accès | Description                   |
| -------- | ----- | ----------------------------- |
| contents | read  | Lire l'historique des commits |

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

Les exemples suivants couvrent la validation de base des commits, l'obligation de scope, les types autorisés personnalisés, les fichiers de configuration externes, le mode non bloquant et la validation des événements push à la place des pull requests.

### Exemple simple

Valide tous les commits d'une PR avec le jeu de règles Conventional Commits par défaut, sans configuration supplémentaire. Les 11 types standards sont acceptés et aucun scope n'est requis.

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
```

### Exiger un scope

`REQUIRE_SCOPE: true` rend la partie `(scope)` obligatoire - `feat: add feature` échoue, alors que `feat(auth): add feature` passe.

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
    with:
      REQUIRE_SCOPE: true
```

### Types autorisés personnalisés

Restreint les types acceptés à un jeu minimal et abaisse la limite de longueur de l'en-tête du commit à 72 caractères - une convention Git courante qui tient dans la largeur standard d'un terminal.

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
    with:
      ALLOWED_TYPES: "feat,fix,docs,chore"
      MAX_SUBJECT_LENGTH: 72
```

### Utiliser un fichier de configuration personnalisé

Charge la configuration commitlint complète depuis `.commitlintrc.js`. Tous les inputs inline (`ALLOWED_TYPES`, `REQUIRE_SCOPE`, `MAX_SUBJECT_LENGTH`) sont remplacés par le fichier de configuration.

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
    with:
      CONFIG_FILE: ".commitlintrc.js"
```

### Vérification non bloquante

Les violations apparaissent dans le tableau récapitulatif du workflow sans faire échouer le job. Utile pour introduire Conventional Commits sur un dépôt dont l'historique contient déjà des commits non conformes.

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
    with:
      FAIL_ON_ERROR: false
```

### Pour les événements push

`COMMITS_SOURCE: push` fait passer la plage de commits du contexte de la PR à la plage de SHA du push (`before` → `after`). Le workflow doit être déclenché sur des événements `push` plutôt que `pull_request`.

```yaml
on:
  push:
    branches:
    - main
    - develop

jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@v0
    permissions:
      contents: read
    with:
      COMMITS_SOURCE: push
```
