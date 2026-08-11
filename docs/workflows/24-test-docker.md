# `test-docker.yml`

Exécute une commande dans une image Docker construite, depuis une référence de registre ou un artefact tarball.

## Inputs

| Input               | Type   | Description                                                                                  | Requis  | Défaut             |
| ------------------- | ------ | -------------------------------------------------------------------------------------------- | ------- | ------------------ |
| IMAGE               | string | Image contre laquelle exécuter le test (ex: `ghcr.io/my-org/my-image:1.2.3`)                 | Non     | -                  |
| IMAGE_ARTIFACT      | string | Artefact contenant un tarball d'image à charger et tester localement au lieu de pull `IMAGE` | Non     | -                  |
| IMAGE_ARTIFACT_FILE | string | Nom du fichier tarball dans `IMAGE_ARTIFACT`                                                 | Non     | `image.tar`        |
| COMMAND             | string | Commande à exécuter dans le conteneur, telle qu'écrite après la référence de l'image         | **Oui** | -                  |
| ENTRYPOINT          | string | Remplace l'entrypoint de l'image (ex: `bash`)                                                | Non     | -                  |
| WORKSPACE_PATH      | string | Chemin du dépôt monté en lecture seule dans le conteneur                                     | Non     | -                  |
| WORKSPACE_MOUNT     | string | Chemin de montage de `WORKSPACE_PATH` dans le conteneur                                      | Non     | `/workspace`       |
| RUN_ARGS            | string | Arguments supplémentaires passés à `docker run` (ex: `--network host -e FOO=bar`)            | Non     | -                  |
| RUNS_ON             | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)       | Non     | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                                                    | Requis |
| ----------------- | -------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour le registre (non requis pour `ghcr.io`) | Non    |
| REGISTRY_PASSWORD | Mot de passe pour le registre (non requis pour `ghcr.io`)      | Non    |

## Permissions

| Scope    | Accès | Description                 |
| -------- | ----- | --------------------------- |
| contents | read  | Lire le contenu du dépôt    |
| packages | read  | Pull des images depuis GHCR |

## Notes

- Un des inputs `IMAGE` ou `IMAGE_ARTIFACT` doit être fourni ; le workflow échoue immédiatement avec un message clair si aucun des deux ne l'est.
- `IMAGE_ARTIFACT` prend le pas sur `IMAGE` si les deux sont fournis. Le tarball est chargé avec `docker load` et la référence est lue depuis sa sortie, puisque le nom de l'artefact ne dit rien sur la façon dont l'image à l'intérieur est taguée.
- S'associe à `build-docker.yml` utilisé avec `PUSH: false`, pour tester une image **avant** qu'elle soit publiée plutôt qu'après.
- `ENTRYPOINT` est nécessaire dès que l'image déclare un entrypoint qui absorberait sinon `COMMAND` - un shell, ou un script de démarrage de service. Sans lui, `COMMAND` est passé en arguments à l'entrypoint existant.
- `WORKSPACE_PATH` monte un répertoire du dépôt appelant en lecture seule, pour que les scripts de test vivent à côté du code qu'ils vérifient plutôt que d'être écrits en dur dans le workflow.
- `COMMAND` et `RUN_ARGS` sont découpés en argv (word-splitting), donc ils se comportent comme sur une ligne de commande shell.
- Le dépôt n'est checkout que si `WORKSPACE_PATH` est fourni.
- Permet de détecter une classe d'erreur qu'un `docker build` réussi ne peut pas révéler : un outil installé mais qui ne s'exécute pas, un binaire jamais ajouté au `PATH`, une librairie partagée manquante.

## Exemples

### Smoke-test d'une image publiée

```yaml
jobs:
  test:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-docker.yml@v0
    permissions:
      contents: read
      packages: read
    with:
      IMAGE: ghcr.io/my-org/my-image:1.2.3
      COMMAND: my-binary --version
```

### Exécuter des scripts de test présents dans le dépôt

Monte un répertoire de scripts de test et en exécute un contre l'image. `ENTRYPOINT: bash` remplace un entrypoint qui consommerait sinon la commande.

```yaml
jobs:
  test:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-docker.yml@v0
    permissions:
      contents: read
      packages: read
    with:
      IMAGE: ghcr.io/my-org/my-image:pr-${{ github.event.pull_request.number }}
      ENTRYPOINT: bash
      WORKSPACE_PATH: ci/tests
      WORKSPACE_MOUNT: /tests
      COMMAND: /tests/smoke.sh
```

### Tester une image construite mais non poussée

Conditionne la publication au résultat du test plutôt que de tester après coup.

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: pr-${{ github.event.pull_request.number }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      PUSH: false
      BUILD_ARM64: false

  test:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-docker.yml@v0
    needs:
    - build
    permissions:
      contents: read
      packages: read
    with:
      IMAGE_ARTIFACT: ${{ needs.build.outputs.artifact-prefix }}-amd64
      ENTRYPOINT: bash
      WORKSPACE_PATH: ci/tests
      WORKSPACE_MOUNT: /tests
      COMMAND: /tests/smoke.sh
```

### Tester une matrice d'images

```yaml
jobs:
  test:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-docker.yml@v0
    permissions:
      contents: read
      packages: read
    strategy:
      fail-fast: false
      matrix:
        image: [api, front, worker]
    with:
      IMAGE: ghcr.io/my-org/${{ matrix.image }}:latest
      ENTRYPOINT: bash
      WORKSPACE_PATH: ci/tests
      WORKSPACE_MOUNT: /tests
      COMMAND: /tests/${{ matrix.image }}.sh
```
