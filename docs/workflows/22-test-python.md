# `test-python.yml`

Installe un projet Python avec `uv` et lance ses tests, avec en option l'envoi d'un rapport (couverture, JUnit) comme artefact.

Une seule version de Python. Le lint est dans [`lint-python.yml`](./15-lint-python.md) et la construction du paquet dans [`build-python.yml`](./32-build-python.md) : trois vérifications distinctes dans la protection de branche.

## Inputs

| Input             | Type   | Description                                                                                                                                                 | Requis | Défaut             |
| ----------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| WORKING_DIRECTORY | string | Répertoire du projet Python (celui de son `pyproject.toml`)                                                                                                 | Non    | `.`                |
| PYTHON_VERSION    | string | Version de Python avec laquelle le projet est installé et testé                                                                                             | Non    | `3.13`             |
| INSTALL_COMMAND   | string | Commande d'installation du projet et de ses dépendances (dans `WORKING_DIRECTORY`). Le défaut refuse un `uv.lock` périmé au lieu de le réécrire              | Non    | `uv sync --locked` |
| TEST_COMMAND      | string | Commande de test **complète** (dans `WORKING_DIRECTORY`). Les options de couverture, y compris un plancher (`--cov-fail-under`), en font partie            | Non    | `uv run pytest -q` |
| ARTIFACT_NAME     | string | Nom de l'artefact envoyé depuis `ARTIFACT_PATH`                                                                                                             | Non    | `test-report`      |
| ARTIFACT_PATH     | string | Chemin, relatif à `WORKING_DIRECTORY`, envoyé comme artefact même si les tests échouent (ex. `htmlcov/`, `junit.xml`). Vide = rien n'est envoyé             | Non    | `""`               |
| RUNS_ON           | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                     | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description       |
| -------- | ----- | ----------------- |
| contents | read  | Checkout du dépôt |

## Exemple

```yaml
jobs:
  test-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-python.yml@v0
    permissions:
      contents: read
    with:
      WORKING_DIRECTORY: sdk/my-sdk
      TEST_COMMAND: uv run pytest -q --cov=my_sdk --cov-branch --cov-report=term-missing --cov-report=html --cov-fail-under=95
      ARTIFACT_PATH: htmlcov
```

## Notes

- La commande est passée par variable d'environnement et exécutée avec `bash -eo pipefail -c`, jamais interpolée dans le script (voir [`lint-python.yml`](./15-lint-python.md#notes) pour la raison de `-e` et `pipefail`).
- Seuls `uv` et `uv pip` respectent `PYTHON_VERSION` ; une commande appelant `pytest` directement tournerait sur le Python par défaut du runner.
- Un projet dont les tests ont besoin de services (base de données, broker) n'entre pas dans ce workflow : gardez un workflow local qui les démarre.
