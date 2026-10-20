# `release-pypi.yml`

Construit un paquet Python avec `uv`, contrôle ses métadonnées, le publie sur PyPI (ou un autre index) puis vérifie qu'il s'installe depuis l'index.

Deux jobs : `build` construit et contrôle le paquet sans aucun accès au jeton OIDC, `publish` envoie ce que `build` a produit. Le code du projet (backend de build) et les outils tiers ne tournent donc jamais dans le job qui peut signer.

## Inputs

| Input             | Type    | Description                                                                                                                                                                                                                      | Requis | Défaut             |
| ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| WORKING_DIRECTORY | string  | Répertoire du projet Python (celui de son `pyproject.toml`)                                                                                                                                                                      | Non    | `.`                |
| VERSION           | string  | Version que l'appelant s'attend à publier (ex. celle que release-please vient de tagger). Le job échoue si le paquet construit en porte une autre. Comparée comme version PEP 440 : `0.1.0-rc.1`, `v0.1.0rc1` et `0.1.0rc1` sont identiques. Vide = publie ce que le projet déclare | Non    | `""`               |
| PYTHON_VERSION    | string  | Version de Python utilisée pour construire le paquet et le réinstaller depuis l'index. Doit satisfaire le `requires-python` du projet : sinon le job échoue avant tout envoi                                                      | Non    | `3.13`             |
| REPOSITORY_URL    | string  | Point de dépôt de l'index (ex. `https://test.pypi.org/legacy/` pour TestPyPI). Vide = PyPI                                                                                                                                       | Non    | `""`               |
| ATTESTATIONS      | boolean | Génère et envoie les attestations PEP 740. Effectif seulement avec la publication de confiance : désactivé automatiquement quand un `PYPI_TOKEN` est fourni                                                                       | Non    | `true`             |
| VERIFY_INSTALL    | boolean | Une fois publié, installe la version exacte depuis PyPI dans un environnement propre, en réessayant le temps que l'index se mette à jour. Ignoré avec `REPOSITORY_URL`                                                           | Non    | `true`             |
| ENVIRONMENT       | string  | Environnement GitHub dans lequel tourne le job de publication. PyPI recommande d'y limiter un trusted publisher ; seul ce workflow peut le positionner, un job appelant ne le peut pas. Vide = aucun environnement             | Non    | `""`               |
| DRY_RUN           | boolean | Construit et contrôle le paquet sans l'envoyer (le job `publish` est ignoré)                                                                                                                                                     | Non    | `false`            |
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                          | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret     | Description                                                                                                                                      | Requis |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| PYPI_TOKEN | Jeton d'API de l'index. Optionnel si le projet a un trusted publisher (OIDC) configuré pour le workflow appelant — voir ci-dessous. Requis sinon | Non    |

## Permissions

| Scope    | Accès | Job       | Description                                                                                       |
| -------- | ----- | --------- | ------------------------------------------------------------------------------------------------- |
| contents | read  | `build`   | Checkout du dépôt                                                                                 |
| id-token | write | `publish` | Jeton OIDC de la publication de confiance et de la signature des attestations                    |

GitHub valide les permissions de tous les jobs d'un workflow appelé à l'analyse, même ignorés : l'appelant doit donc accorder `id-token: write` y compris avec `DRY_RUN: true`.

## Exemple

```yaml
jobs:
  release-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-pypi.yml@v0
    needs: release
    if: ${{ fromJSON(needs.release.outputs.release-outputs)['clients/python/my-sdk--release_created'] == 'true' }}
    permissions:
      contents: read
      id-token: write
    with:
      WORKING_DIRECTORY: clients/python/my-sdk
      VERSION: ${{ fromJSON(needs.release.outputs.release-outputs)['clients/python/my-sdk--version'] }}
```

## Notes

### Publication de confiance (OIDC)

Sans `PYPI_TOKEN`, la publication passe par un [trusted publisher](https://docs.pypi.org/trusted-publishers/). Sur PyPI, déclarez-le avec le dépôt et **le fichier de workflow d'entrée réellement déclenché par GitHub** (ex. `cd.yml`) — pas ce `release-pypi.yml` réutilisable : PyPI valide le workflow appelant qui a démarré le run. Le job appelant doit accorder `id-token: write`. Si le trusted publisher est limité à un environnement GitHub, passez son nom dans `ENVIRONMENT`.

### Garde-fous

- Nom et version sont lus dans la **wheel construite** (`*.dist-info/METADATA`), pas dans `pyproject.toml` : c'est ce qui est envoyé, la version y est normalisée (`0.1.0-rc.1` devient `0.1.0rc1`), et les projets à version dynamique (`hatch-vcs`, `setuptools_scm`) fonctionnent.
- `VERSION` protège d'un décalage entre le tag et le paquet : publier un artefact étiqueté avec une mauvaise version est irréversible, PyPI n'accepte jamais deux fois le même nom et la même version, même après suppression.
- Le `Requires-Python` de la wheel est confronté à `PYTHON_VERSION` avant tout envoi : une vérification d'installation qui ne pourrait jamais réussir ferait échouer le job *après* une publication irréversible.
- `uv build --no-sources` construit contre ce que l'index sert : une entrée `[tool.uv.sources]` ne peut pas masquer une dépendance non publiée.
- `twine check` contrôle les métadonnées avant l'envoi : une description qui ne s'affichera pas sur PyPI échoue ici, pas après la publication.
- `DRY_RUN` s'arrête après ce contrôle : utile pour valider un nouveau paquet avant son premier envoi. Pour un premier vrai test, publiez d'abord sur TestPyPI (`REPOSITORY_URL: https://test.pypi.org/legacy/`).
- La vérification d'installation s'exécute dans un job sans checkout (aucun `uv.toml` du dépôt ne peut changer ce que l'index est interrogé) et relit l'index : 6 tentatives espacées de 20 s.
- Plusieurs paquets dans un même run sont possibles : l'artefact intermédiaire est nommé d'après `WORKING_DIRECTORY`.
- Les caches `uv` sont désactivés : aucun cache n'est restauré dans un job dont le résultat est publié.
