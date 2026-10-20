# `test-python.yml`

Installe un projet Python avec `uv`, le lint, lance ses tests sur une ou plusieurs versions de Python, et peut vérifier que son paquet se construit et s'installe dans un environnement propre.

## Inputs

| Input             | Type    | Description                                                                                                                              | Requis | Défaut                |
| ----------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------ | --------------------- |
| WORKING_DIRECTORY | string  | Répertoire du projet Python (celui de son `pyproject.toml`)                                                                              | Non    | `.`                   |
| PYTHON_VERSIONS   | string  | Versions de Python à tester, en tableau JSON (ex. `["3.11", "3.13"]`). Une branche de matrice par version                               | Non    | `["3.13"]`            |
| INSTALL_COMMAND   | string  | Commande d'installation du projet et de ses dépendances (exécutée dans `WORKING_DIRECTORY`). Le défaut refuse un `uv.lock` périmé au lieu de le réécrire | Non    | `uv sync --locked`    |
| LINT_COMMAND      | string  | Commande de lint (exécutée dans `WORKING_DIRECTORY`). Vide = pas de lint                                                                 | Non    | `uv run ruff check .` |
| TEST_COMMAND      | string  | Commande de test (exécutée dans `WORKING_DIRECTORY`). Vide = pas de tests                                                                | Non    | `uv run pytest -q`    |
| BUILD             | boolean | Construit le paquet (sdist + wheel) et installe la wheel dans un environnement propre                                                    | Non    | `false`               |
| IMPORT_NAME       | string  | Module importé depuis cet environnement propre pour prouver que la wheel est utilisable (ex. `my_package`). Lu seulement si `BUILD: true` | Non    | `""`                  |
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                  | Non    | `["ubuntu-24.04"]`    |

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
      WORKING_DIRECTORY: clients/python/my-sdk
      PYTHON_VERSIONS: '["3.11", "3.13"]'
      BUILD: true
      IMPORT_NAME: my_sdk
```

## Notes

- Les commandes sont passées par variables d'environnement et exécutées avec `bash -eo pipefail -c`, jamais interpolées dans le script : une entrée ne peut pas injecter de commande dans l'étape qui la porte. `-e` et `pipefail` sont explicites parce qu'un `bash -c` n'hérite pas des options du shell de l'étape : sans eux, une commande multi-lignes ou un `pytest | tee` resterait vert malgré un échec.
- `UV_PYTHON` est positionné sur la version de la branche de matrice : `uv sync` et `uv run` utilisent ainsi la bonne version sans option supplémentaire dans les commandes. Seuls `uv` et `uv pip` la respectent : une commande personnalisée appelant `pytest` ou `pip` directement tournerait sur le Python par défaut du runner, quelle que soit la branche de matrice.
- Le défaut de `INSTALL_COMMAND` (`uv sync --locked`) suppose que les outils des défauts de `LINT_COMMAND` et `TEST_COMMAND` (`ruff`, `pytest`) sont dans le groupe de dépendances de développement du projet.
- `uv build` écrit dans `dist/` du projet (`--out-dir`), même quand il est membre d'un workspace uv, où il écrirait sinon à la racine du workspace.
- La wheel est installée **hors de l'arbre source** : une donnée manquante ou un paquet oublié dans la wheel ne passe pas inaperçu parce que le code source est à côté.
- `IMPORT_NAME` doit être un nom de module pointé (`a.b.c`) ; toute autre valeur est refusée plutôt qu'échappée, car il est inséré dans un `python -c`. La validation n'a lieu que si `BUILD: true`.
- Un projet qui a besoin de services (base de données, broker) pour ses tests n'entre pas dans ce workflow : gardez un workflow local qui les démarre.
