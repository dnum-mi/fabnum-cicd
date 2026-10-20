# `build-python.yml`

Construit un paquet Python avec `uv` (sdist + wheel), contrôle ses métadonnées, vérifie que la wheel s'installe et s'importe dans un environnement propre, puis envoie `dist/` comme artefact. C'est ce que [`release-pypi.yml`](./58-release-pypi.md) publie ensuite.

Le job ne détient aucun jeton OIDC : il exécute le backend de build du projet et des outils tiers, ce qui ne doit jamais se faire dans le job qui peut signer.

## Inputs

| Input             | Type   | Description                                                                                                                                                                                                                                              | Requis | Défaut             |
| ----------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| WORKING_DIRECTORY | string | Répertoire du projet Python (celui de son `pyproject.toml`)                                                                                                                                                                                              | Non    | `.`                |
| PYTHON_VERSION    | string | Version de Python utilisée pour construire et pour installer la wheel. Doit satisfaire le `requires-python` du projet, sinon le job échoue                                                                                                                | Non    | `3.13`             |
| VERSION           | string | Version que l'appelant s'attend à construire (ex. celle que release-please vient de tagger). Le job échoue si le paquet en porte une autre. Comparée comme version PEP 440 : `0.1.0-rc.1`, `v0.1.0rc1` et `0.1.0rc1` sont identiques. Vide = accepte celle du projet | Non    | `""`               |
| IMPORT_NAME       | string | Module importé depuis l'environnement propre où la wheel est installée (ex. `my_package`). Vide = installation sans import                                                                                                                              | Non    | `""`               |
| RUNS_ON           | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                  | Non    | `["ubuntu-24.04"]` |

## Outputs

| Output   | Description                                                                              |
| -------- | ---------------------------------------------------------------------------------------- |
| name     | Nom de la distribution, lu dans la wheel                                                 |
| version  | Version lue dans la wheel, normalisée (PEP 440)                                          |
| artifact | Nom de l'artefact contenant `dist/` (l'input `ARTIFACT` de `release-pypi.yml`)           |

## Permissions

| Scope    | Accès | Description       |
| -------- | ----- | ----------------- |
| contents | read  | Checkout du dépôt |

## Exemple

```yaml
jobs:
  build-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-python.yml@v0
    permissions:
      contents: read
    with:
      WORKING_DIRECTORY: sdk/my-sdk
      IMPORT_NAME: my_sdk
```

## Notes

- Nom et version sont lus dans la **wheel construite** (`*.dist-info/METADATA`), pas dans `pyproject.toml` : c'est ce qui sera envoyé, la version y est normalisée (`0.1.0-rc.1` devient `0.1.0rc1`) et les projets à version dynamique (`hatch-vcs`, `setuptools_scm`) fonctionnent.
- `VERSION` protège d'un décalage entre le tag et le paquet : publier un artefact étiqueté avec une mauvaise version est irréversible, PyPI n'accepte jamais deux fois le même nom et la même version, même après suppression.
- Le `Requires-Python` de la wheel est confronté à `PYTHON_VERSION` : une vérification d'installation qui ne pourrait jamais réussir ferait échouer le job *après* une publication irréversible.
- `uv build --no-sources` construit contre ce que l'index sert : une entrée `[tool.uv.sources]` ne peut pas masquer une dépendance non publiée. `--out-dir dist` garde le résultat à côté du projet même quand il est membre d'un workspace uv.
- `twine check` contrôle les métadonnées : une description qui ne s'affichera pas sur PyPI échoue ici, pas après la publication.
- La wheel est installée **hors de l'arbre source** : une donnée manquante ou un paquet oublié dans la wheel ne passe pas inaperçu parce que le code source est à côté.
- `IMPORT_NAME` doit être un nom de module pointé (`a.b.c`) ; toute autre valeur est refusée plutôt qu'échappée, car il est inséré dans un `python -c`.
- Plusieurs paquets dans un même run sont possibles : l'artefact est nommé d'après `WORKING_DIRECTORY`.
- Les caches `uv` sont désactivés : aucun cache n'est restauré dans un job dont le résultat finit sur un index.
