# `release-pypi.yml`

Publie sur PyPI (ou un autre index) les distributions construites par [`build-python.yml`](./32-build-python.md), puis vérifie que la version publiée s'installe depuis l'index.

Ce workflow ne construit rien et n'exécute aucun code du projet : c'est le seul job qui peut obtenir un jeton OIDC, il envoie un artefact.

## Inputs

| Input          | Type    | Description                                                                                                                                                      | Requis  | Défaut             |
| -------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------ |
| ARTIFACT       | string  | Nom de l'artefact contenant les distributions (output `artifact` de `build-python.yml`)                                                                          | **Oui** | -                  |
| PACKAGE        | string  | Nom de la distribution (output `name`). Sert uniquement à réinstaller la version publiée                                                                         | Non     | `""`               |
| VERSION        | string  | Version publiée (output `version`). Sert uniquement à réinstaller la version publiée                                                                             | Non     | `""`               |
| PYTHON_VERSION | string  | Version de Python utilisée pour réinstaller la version publiée                                                                                                   | Non     | `3.13`             |
| REPOSITORY_URL | string  | Point de dépôt de l'index (ex. `https://test.pypi.org/legacy/` pour TestPyPI). Vide = PyPI                                                                       | Non     | `""`               |
| ATTESTATIONS   | boolean | Génère et envoie les attestations PEP 740. Effectif seulement avec la publication de confiance : désactivé automatiquement quand un `PYPI_TOKEN` est fourni      | Non     | `true`             |
| VERIFY_INSTALL | boolean | Une fois publié, installe `PACKAGE==VERSION` depuis PyPI dans un environnement propre, en réessayant le temps que l'index se mette à jour. Ignoré sans `PACKAGE`/`VERSION` et avec `REPOSITORY_URL` | Non     | `true`             |
| ENVIRONMENT    | string  | Environnement GitHub dans lequel tourne le job. PyPI recommande d'y limiter un trusted publisher ; seul ce workflow peut le positionner, un job appelant ne le peut pas. Vide = aucun | Non     | `""`               |
| RUNS_ON        | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                          | Non     | `["ubuntu-24.04"]` |

## Secrets

| Secret     | Description                                                                                                                                      | Requis |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| PYPI_TOKEN | Jeton d'API de l'index. Optionnel si le projet a un trusted publisher (OIDC) configuré pour le workflow appelant — voir ci-dessous. Requis sinon | Non    |

## Permissions

| Scope    | Accès | Description                                                                   |
| -------- | ----- | ----------------------------------------------------------------------------- |
| id-token | write | Jeton OIDC de la publication de confiance et de la signature des attestations |

## Exemple

```yaml
jobs:
  build-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-python.yml@v0
    needs: release
    if: ${{ fromJSON(needs.release.outputs.release-outputs)['sdk/my-sdk--release_created'] == 'true' }}
    permissions:
      contents: read
    with:
      WORKING_DIRECTORY: sdk/my-sdk
      VERSION: ${{ fromJSON(needs.release.outputs.release-outputs)['sdk/my-sdk--version'] }}

  release-sdk:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-pypi.yml@v0
    needs: build-sdk
    permissions:
      id-token: write
    with:
      ARTIFACT: ${{ needs.build-sdk.outputs.artifact }}
      PACKAGE: ${{ needs.build-sdk.outputs.name }}
      VERSION: ${{ needs.build-sdk.outputs.version }}
```

## Notes

### Publication de confiance (OIDC)

Sans `PYPI_TOKEN`, la publication passe par un [trusted publisher](https://docs.pypi.org/trusted-publishers/). Sur PyPI, déclarez-le avec le dépôt et **le fichier de workflow d'entrée réellement déclenché par GitHub** (ex. `cd.yml`) — pas ce `release-pypi.yml` réutilisable : PyPI valide le workflow appelant qui a démarré le run. Le job appelant doit accorder `id-token: write`. Si le trusted publisher est limité à un environnement GitHub, passez son nom dans `ENVIRONMENT`.

### Garde-fous

- Pas de checkout dans ce job : aucun `uv.toml` ni `pyproject.toml` du dépôt (`exclude-newer`, index privé) ne peut changer ce que l'index est interrogé lors de la vérification d'installation.
- La vérification relit l'index (6 tentatives espacées de 20 s) : un envoi accepté mais jamais servi fait échouer le job.
- Pour un premier envoi, publiez d'abord sur TestPyPI (`REPOSITORY_URL: https://test.pypi.org/legacy/`). Pour valider un paquet sans rien envoyer, n'appelez que `build-python.yml`.
- Les caches `uv` sont désactivés : aucun cache n'est restauré dans un job qui détient un jeton OIDC.
