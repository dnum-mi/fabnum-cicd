# `lint-python.yml`

Installe un projet Python avec `uv` puis lance son lint et, séparément, sa vérification de types.

Une seule version de Python : un lint ne gagne rien à tourner sur une matrice. Les tests sont dans [`test-python.yml`](./22-test-python.md), pour apparaître comme des vérifications distinctes dans la protection de branche.

## Inputs

| Input              | Type   | Description                                                                                                                                | Requis | Défaut                                                 |
| ------------------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------------------------------------------------------ |
| WORKING_DIRECTORY  | string | Répertoire du projet Python (celui de son `pyproject.toml`)                                                                                | Non    | `.`                                                    |
| PYTHON_VERSION     | string | Version de Python avec laquelle le projet est installé et contrôlé                                                                         | Non    | `3.13`                                                 |
| INSTALL_COMMAND    | string | Commande d'installation du projet et de ses dépendances (dans `WORKING_DIRECTORY`). Le défaut refuse un `uv.lock` périmé au lieu de le réécrire | Non    | `uv sync --locked`                                     |
| LINT_COMMAND       | string | Lint et contrôle du formatage (dans `WORKING_DIRECTORY`). Vide = ignoré                                                                    | Non    | `uv run ruff check . && uv run ruff format --check .`  |
| TYPE_CHECK_COMMAND | string | Vérification de types (ex. `uv run ty check src`), dans une étape à part pour distinguer une erreur de type d'une erreur de lint. Vide = ignoré | Non    | `""`                                                   |
| RUNS_ON            | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                    | Non    | `["ubuntu-24.04"]`                                     |

## Permissions

| Scope    | Accès | Description       |
| -------- | ----- | ----------------- |
| contents | read  | Checkout du dépôt |

## Exemple

```yaml
jobs:
  lint-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-python.yml@v0
    permissions:
      contents: read
    with:
      WORKING_DIRECTORY: sdk/my-sdk
      TYPE_CHECK_COMMAND: uv run ty check src
```

## Notes

- Les commandes sont passées par variables d'environnement et évaluées avec `eval`, jamais interpolées dans le script : le texte du script reste fixe quoi que passe l'appelant. `eval` s'exécute dans le shell de l'étape, démarré avec `-e` et `pipefail` (`defaults.run.shell: bash`) : une ligne qui échoue dans une commande multi-lignes, ou le premier maillon d'un pipe, fait échouer l'étape.
- `UV_PYTHON` est exporté par `setup-uv` : seuls `uv` et `uv pip` respectent `PYTHON_VERSION`. Une commande appelant `ruff` directement tournerait sur le Python par défaut du runner.
- Le défaut de `INSTALL_COMMAND` (`uv sync --locked`) suppose que `ruff` (et l'outil de types) sont dans le groupe de dépendances de développement du projet.
