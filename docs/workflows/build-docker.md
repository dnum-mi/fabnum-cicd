# `build-docker.yml`

Build et push d'images Docker multi-architecture (amd64/arm64) vers un registre de conteneurs en utilisant Docker Buildx.

## Inputs

| Input               | Type    | Description                                                                                        | Requis | Défaut             |
| ------------------- | ------- | -------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE_NAME          | string  | Nom de l'image à construire (ex: `ghcr.io/my-org/my-image`)                                        | Oui    | -                  |
| IMAGE_TAG           | string  | Tag utilisé pour construire l'image                                                                | Oui    | -                  |
| LATEST_TAG          | boolean | Taguer également l'image avec `latest`                                                             | Non    | `false`            |
| IMAGE_DOCKERFILE    | string  | Chemin vers le Dockerfile                                                                          | Oui    | -                  |
| IMAGE_CONTEXT       | string  | Chemin du contexte de build                                                                        | Oui    | -                  |
| IMAGE_TARGET        | string  | Étape cible à construire dans le Dockerfile (optionnel, construit la dernière étape si non défini) | Non    | -                  |
| TAG_MAJOR_AND_MINOR | boolean | Créer des tags pour les versions majeure et mineure (ex: `1.2.3` → `1.2` et `1`)                   | Non    | `false`            |
| BUILD_AMD64         | boolean | Build pour l'architecture amd64                                                                    | Non    | `true`             |
| BUILD_ARM64         | boolean | Build pour l'architecture arm64                                                                    | Non    | `true`             |
| USE_QEMU            | boolean | Utiliser l'émulateur QEMU pour arm64                                                               | Non    | `false`            |
| BUILD_ARGS          | string  | Liste de build args Docker séparés par des sauts de ligne (ex: `MY_ARG=value`)                     | Non    | -                  |
| CACHE               | boolean | Activer le cache de build Docker (utilise le backend de cache GitHub Actions)                      | Non    | `false`            |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)             | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                        | Requis |
| ----------------- | ---------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour le registre | Non    |
| REGISTRY_PASSWORD | Mot de passe pour le registre      | Non    |

## Outputs

| Output | Description                                                     |
| ------ | --------------------------------------------------------------- |
| digest | Digest de l'image construite (ex: `sha256:abc123...`)           |
| image  | Nom normalisé de l'image (minuscules, compatible registres OCI) |

## Permissions

| Scope    | Accès | Description                                                            |
| -------- | ----- | ---------------------------------------------------------------------- |
| packages | write | Push des images vers GHCR lorsque applicable                           |
| contents | read  | Lecture du dépôt pour construire le contexte (jobs `infos` et `build`) |

## Notes

- Supporte Ubuntu 24.04 et les runners ARM pour les builds matrix.
- **Normalisation du nom d'image** : Le nom de l'image est automatiquement normalisé pour être compatible avec les registres OCI (notamment GHCR) :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `ghcr.io/My-Org/My_App` → `ghcr.io/my-org/my-app`
- L'input `LATEST_TAG` permet de taguer les images avec `latest`.
- `TAG_MAJOR_AND_MINOR` crée des tags supplémentaires pour les releases stables (ex: `1.2.3` crée aussi `1.2` et `1`). S'applique uniquement aux versions non-prerelease.
- `IMAGE_TARGET` permet de cibler une étape spécifique dans un Dockerfile multi-stage. Si non défini, la dernière étape est construite.
- `BUILD_ARGS` permet de passer des arguments de build Docker, un par ligne (ex: `MY_ARG=value`).
- **Cache de build** : Si `CACHE: true`, le cache Docker est activé via le backend GitHub Actions (`type=gha`), accélérant les builds subséquents.
- Logique de connexion au registre : utilise le token GitHub pour `ghcr.io`, sinon utilise les credentials fournis.
- Les artefacts digest sont uploadés et fusionnés pour les images multi-arch.
- Une manifest list est créée et pushée après le build.
- Les versions prerelease (contenant `-alpha`, `-beta`, `-rc`, etc.) sont détectées et traitées en conséquence.
- Un tag SHA court est automatiquement ajouté pour la traçabilité.
- Les tags basés sur les branches excluent les branches `main` et `develop`.

## Exemples

### Exemple simple

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: 1.2.3
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      LATEST_TAG: true
      BUILD_AMD64: true
      BUILD_ARM64: true
      USE_QEMU: false
```

### Build multi-architecture avec tags majeur et mineur

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./apps/server
      IMAGE_DOCKERFILE: ./apps/server/Dockerfile
      LATEST_TAG: true
      TAG_MAJOR_AND_MINOR: true
      BUILD_AMD64: true
      BUILD_ARM64: true
```

### Build avec attestation et SBOM

Utiliser le workflow dédié [`attest-image.yml`](./attest-image.md) après le build :

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: 1.0.0
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      CACHE: true

  attest:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-image.yml@v0
    needs:
    - build
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ${{ needs.build.outputs.image }}
      DIGEST: ${{ needs.build.outputs.digest }}
      PROVENANCE: true
      SBOM: true
```

### Build multi-stage avec build args

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: 1.0.0
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      IMAGE_TARGET: production
      BUILD_ARGS: |
        NODE_ENV=production
        API_URL=https://api.example.com
```

### Build avec registre personnalisé

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    with:
      IMAGE_NAME: docker.io/my-org/my-image
      IMAGE_TAG: 1.0.0
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      BUILD_AMD64: true
      BUILD_ARM64: false
    secrets:
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```
