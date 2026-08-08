# `build-docker.yml`

Build d'images Docker multi-architecture (amd64/arm64) avec Docker Buildx, et push optionnel vers un registre de conteneurs.

## Inputs

| Input               | Type    | Description                                                                                                                                                                                                                                         | Requis | Défaut             |
| ------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE_NAME          | string  | Nom de l'image à construire (ex: `ghcr.io/my-org/my-image`)                                                                                                                                                                                         | Oui    | -                  |
| IMAGE_TAG           | string  | Tag utilisé pour construire l'image                                                                                                                                                                                                                 | Oui    | -                  |
| LATEST_TAG          | boolean | Taguer également l'image avec `latest`                                                                                                                                                                                                              | Non    | `false`            |
| IMAGE_DOCKERFILE    | string  | Chemin vers le Dockerfile                                                                                                                                                                                                                           | Oui    | -                  |
| IMAGE_CONTEXT       | string  | Chemin du contexte de build                                                                                                                                                                                                                         | Oui    | -                  |
| IMAGE_TARGET        | string  | Étape cible à construire dans le Dockerfile (optionnel, construit la dernière étape si non défini)                                                                                                                                                  | Non    | -                  |
| PUSH                | boolean | Pousser l'image construite vers le registre. Si `false`, l'image est exportée sous forme d'artefact tarball (un par architecture) au lieu d'être poussée, pour qu'un job en aval puisse la charger avec `docker load` et exécuter des tests dessus. | Non    | `true`             |
| TAG_MAJOR_AND_MINOR | boolean | Créer des tags pour les versions majeure et mineure (ex: `1.2.3` → `1.2` et `1`)                                                                                                                                                                    | Non    | `false`            |
| BUILD_AMD64         | boolean | Build pour l'architecture amd64                                                                                                                                                                                                                     | Non    | `true`             |
| BUILD_ARM64         | boolean | Build pour l'architecture arm64                                                                                                                                                                                                                     | Non    | `true`             |
| USE_QEMU            | boolean | Utiliser l'émulateur QEMU pour arm64                                                                                                                                                                                                                | Non    | `false`            |
| BUILD_ARGS          | string  | Liste de build args Docker séparés par des sauts de ligne (ex: `MY_ARG=value`)                                                                                                                                                                      | Non    | -                  |
| BUILD_SECRET_GITHUB_TOKEN | string | Credential à exposer comme secret de build `github_token=<token>` (lisible dans le Dockerfile à `/run/secrets/github_token`), pour relever la limite d'API GitHub des outils qui résolvent des releases pendant le build (mise, aqua, ubi). `none` (défaut) n'injecte rien. `app` mint un token App réduit à `contents:read` + `metadata:read` sur ce dépôt, échoue si absent. `pat` utilise le token App si disponible sinon `GH_PAT`, échoue si aucun des deux. `job-token` retombe en plus sur le `GITHUB_TOKEN` du job, qui ne peut pas être réduit et porte tout le bloc `permissions:` de l'appelant. Voir [`authentication.md`](./authentication.md#ce-que-build-docker-injecte-réellement). | Non    | `none`             |
| CACHE               | boolean | Activer le cache de build Docker (utilise le backend de cache GitHub Actions)                                                                                                                                                                       | Non    | `false`            |
| CACHE_MODE          | string  | Mode d'export du cache Buildx : `max` (toutes les couches intermédiaires) ou `min` (uniquement l'image finale)                                                                                                                                      | Non    | `max`              |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                              | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                                                                                                                | Requis |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour le registre                                                                                         | Non    |
| REGISTRY_PASSWORD | Mot de passe pour le registre                                                                                              | Non    |
| BUILD_SECRETS     | Liste de secrets de build au format `KEY=VALUE` (un par ligne), exposés au Dockerfile via `RUN --mount=type=secret,id=KEY` | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App, utilisé uniquement pour minter le token injecté par `BUILD_SECRET_GITHUB_TOKEN`. Toujours réduit à `contents:read` + `metadata:read` sur ce dépôt. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                            | Non    |
| GH_PAT            | Personal Access Token, utilisé uniquement pour `BUILD_SECRET_GITHUB_TOKEN` et résolu après les credentials App. Scoper à `Contents: read` uniquement, jamais un token classic.                                          | Non    |

## Outputs

| Output          | Description                                                                            |
| --------------- | -------------------------------------------------------------------------------------- |
| digest          | Digest de l'image construite (ex: `sha256:abc123...`), vide si `PUSH` est `false`      |
| image           | Nom normalisé de l'image (minuscules, compatible registres OCI)                        |
| artifact-prefix | Préfixe des artefacts tarball produits quand `PUSH` est `false` (ex: `image-my-image`) |

## Permissions

| Scope    | Accès | Description                                                            |
| -------- | ----- | ---------------------------------------------------------------------- |
| packages | write | Push des images vers GHCR lorsque applicable                           |
| contents | read  | Lecture du dépôt pour construire le contexte (jobs `infos` et `build`) |

## Notes

### Matrice des runners et plateformes

Le job `build` sélectionne automatiquement le ou les runners et la plateforme cible selon la combinaison des inputs `BUILD_AMD64`, `BUILD_ARM64` et `USE_QEMU` :

| `BUILD_AMD64` | `BUILD_ARM64` | `USE_QEMU` | Runners utilisés                                                     | Plateforme(s) buildées                                      |
| :-----------: | :-----------: | :--------: | -------------------------------------------------------------------- | ----------------------------------------------------------- |
|       ✓       |       ✓       |     ✗      | `ubuntu-24.04` **+** `ubuntu-24.04-arm` (builds natifs en parallèle) | AMD64 runner → `linux/amd64` / ARM64 runner → `linux/arm64` |
|       ✓       |       ✓       |     ✓      | `ubuntu-24.04` (QEMU émule arm64)                                    | `linux/amd64,linux/arm64`                                   |
|       ✗       |       ✓       |     ✓      | `ubuntu-24.04` (QEMU émule arm64)                                    | `linux/arm64`                                               |
|       ✗       |       ✓       |     ✗      | `ubuntu-24.04-arm` (natif)                                           | `linux/arm64`                                               |
|       ✓       |       ✗       |     *      | `ubuntu-24.04`                                                       | `linux/amd64`                                               |

> **Recommandation** : Préférer les builds natifs (`USE_QEMU: false`) quand des runners ARM sont disponibles. QEMU est significativement plus lent pour les builds complexes.

### Comportement du push

Par défaut, l'image est poussée vers le registre (par digest, puis assemblée en manifest list multi-arch).

### Build sans push (`PUSH: false`)

- Mettre `PUSH: false` remplace l'exporteur registre par l'exporteur `docker` : l'image est écrite dans un tarball et uploadée en tant qu'artefact de workflow au lieu d'être poussée. C'est la manière prévue de construire une image et d'exécuter des tests dessus avant de la publier.
- Les jobs d'un workflow réutilisable s'exécutent sur leurs propres runners : une image chargée dans le daemon Docker du job de build n'est **pas** visible du job de test de l'appelant. L'artefact tarball est ce qui relie les deux.
- **Nommage de l'artefact** : un artefact par architecture, nommé `<artifact-prefix>-amd64` / `<artifact-prefix>-arm64`, contenant chacun un unique `image.tar`. Utiliser l'output `artifact-prefix` plutôt que de coder le nom en dur - il est dérivé du nom d'image normalisé (ex: `ghcr.io/my-org/my_image` → `image-my-image`).
- Le tarball embarque l'image sous la référence `<IMAGE_NAME>:<IMAGE_TAG>`, donc après un `docker load -i image.tar`, l'image est directement exécutable sous cette référence.
- Le job `merge` (création de la manifest list) est **ignoré** quand `PUSH` est `false` - il n'y a rien à fusionner dans un registre. L'output `digest` est donc vide, et les étapes en aval qui le consomment (notamment un job `attest-docker.yml` composé après ce workflow) ne doivent pas être branchées sur un build non poussé.
- Deux workflows de ce dépôt consomment directement l'artefact tarball, permettant de valider entièrement une image non poussée : [`scan-trivy.yml`](./scan-trivy.md) via son input `IMAGE_ARTIFACT` (mode tarball de Trivy) et `test-kube-deployment.yml` (non repris dans ce dépôt) via `kind load image-archive`. L'attestation est la seule chose qui ne peut vraiment pas fonctionner sans push, puisque les attestations sont liées à un digest de registre.
- **Multi-arch** : avec `USE_QEMU: false` (runners natifs), construire les deux architectures produit deux tarballs mono-architecture indépendants - un par runner - ce qui est généralement souhaitable, puisqu'un job de test ne peut de toute façon exécuter qu'une seule architecture à la fois.
- **Combinaison non supportée** : `PUSH: false` + `USE_QEMU: true` + `BUILD_AMD64` et `BUILD_ARM64` tous les deux à `true`. L'exporteur `docker` ne peut pas écrire une manifest list multi-plateforme dans un tarball, le workflow échoue donc rapidement dans le job `infos` avec une erreur explicite. Utiliser des runners natifs (`USE_QEMU: false`) ou construire une seule architecture à la fois.
- **Connexion au registre** : ignorée quand `PUSH` est `false`, sauf si l'image cible `ghcr.io` (les credentials résolvent toujours depuis le token du job) ou si `REGISTRY_USERNAME` est fourni. Une image non-GHCR peut donc être construite sans aucun credential, tandis qu'une image de base privée peut toujours être pull en fournissant les secrets malgré tout.

### Credential GitHub dans le build (`BUILD_SECRET_GITHUB_TOKEN`)

- Le credential est résolu depuis une source explicitement nommée : `none` (défaut) n'injecte rien, `app` mint un token App en lecture seule dédié, `pat` accepte aussi `GH_PAT`, `job-token` accepte en plus le `GITHUB_TOKEN` du job (non réduit, porte tout le bloc `permissions:` de l'appelant - un job appelant ce workflow accorde généralement `packages: write`).
- Injecté via un montage BuildKit (`/run/secrets/github_token`), jamais écrit dans un fichier sur le runner ni dans les layers de l'image.
- `app`/`pat` échouent explicitement si le credential demandé est absent, plutôt que de retomber silencieusement sur un mode plus large. `job-token` émet un `::warning::` s'il retombe effectivement sur le `GITHUB_TOKEN` du job.
- Voir [`authentication.md`](./authentication.md#ce-que-build-docker-injecte-réellement) pour le détail des quatre modes et un exemple câblé.

## Attestation et signature (`attest-docker.yml`)

Ce workflow n'a aucun chemin d'attestation intégré - il ne déclare jamais d'appel imbriqué demandant `id-token`/`attestations`, donc un appelant qui ne fait que build et push n'a jamais besoin de les accorder. La provenance SLSA, le SBOM et la signature cosign relèvent entièrement de [`attest-docker.yml`](./attest-docker.md), composé comme un second job explicite alimenté par les outputs `digest`/`image` de ce workflow :

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: 1.2.3
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile

  attest:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml@v0
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

Seul le job `attest` a besoin de `id-token`/`attestations` - `build` n'en a jamais besoin, quel que soit le nombre d'images construites par un pipeline ou le fait que l'une d'elles soit attestée.

### Builds en matrice

Un job `build` en matrice ne peut pas alimenter un job `attest` matricé de la même façon : `needs.<job>.outputs.<name>` s'effondre en une seule valeur à travers toutes les combinaisons de la matrice (comportement documenté de GitHub - la dernière combinaison terminée l'emporte), donc un job `attest` matricé de la même manière attesterait silencieusement la mauvaise image, ou la même deux fois, pour toutes les combinaisons sauf la dernière. Il n'existe aucune corrélation d'id/index entre une matrice en amont et en aval.

Le bon pattern est une **paire** explicite et non matricée de jobs `build`/`attest` **par image** - plus verbeux qu'une matrice, mais chaque paire est indépendamment correcte et n'accorde les permissions supplémentaires que là où elles sont réellement utilisées :

```yaml
jobs:
  build-frontend:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/frontend
      IMAGE_TAG: 1.2.3
      IMAGE_CONTEXT: ./apps/frontend
      IMAGE_DOCKERFILE: ./apps/frontend/Dockerfile

  attest-frontend:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml@v0
    needs:
    - build-frontend
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ${{ needs.build-frontend.outputs.image }}
      DIGEST: ${{ needs.build-frontend.outputs.digest }}
      PROVENANCE: true
      SBOM: true

  build-backend:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/backend
      IMAGE_TAG: 1.2.3
      IMAGE_CONTEXT: ./apps/backend
      IMAGE_DOCKERFILE: ./apps/backend/Dockerfile

  attest-backend:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml@v0
    needs:
    - build-backend
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ${{ needs.build-backend.outputs.image }}
      DIGEST: ${{ needs.build-backend.outputs.digest }}
      PROVENANCE: true
      SBOM: true
```

Si seules *certaines* images nécessitent une attestation, ce pattern signifie aussi que seuls les jobs de ces images portent les permissions supplémentaires - les autres restent à `packages: write` + `contents: read`, contrairement à une matrice partagée où chaque combinaison devrait accorder le même sur-ensemble, indépendamment des images qui l'utilisent réellement.

### Autres comportements

- **Validation des inputs** : effectuée en amont dans le job `infos` - désactiver `BUILD_AMD64` et `BUILD_ARM64` simultanément échoue immédiatement plutôt que de construire silencieusement en AMD64 uniquement.
- **Normalisation du nom d'image** : Le nom de l'image est automatiquement normalisé pour être compatible avec les registres OCI (notamment GHCR) :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `ghcr.io/My-Org/My_App` → `ghcr.io/my-org/my-app`
- L'input `LATEST_TAG` permet de taguer les images avec `latest`.
- `TAG_MAJOR_AND_MINOR` crée des tags supplémentaires pour les releases stables (ex: `1.2.3` crée aussi `1.2` et `1`). S'applique uniquement aux versions non-prerelease.
- `IMAGE_TARGET` permet de cibler une étape spécifique dans un Dockerfile multi-stage. Si non défini, la dernière étape est construite.
- `BUILD_ARGS` permet de passer des arguments de build Docker, un par ligne (ex: `MY_ARG=value`).
- **Cache de build** : Si `CACHE: true`, le cache Docker est activé via le backend GitHub Actions (`type=gha`), accélérant les builds subséquents. `CACHE_MODE` contrôle ce qui est exporté : `max` (défaut) exporte toutes les couches intermédiaires, `min` uniquement celles de l'image finale. Un dépôt dispose de 10 Go de cache Actions ; `max` sur plusieurs images multi-stage volumineuses peut dépasser ce budget, GitHub évince alors les entrées les moins récemment utilisées et les builds importent un cache manifest sans plus rien y trouver. Passer à `min` quand le budget est dépassé - un cache plus petit qui survit vaut mieux qu'un cache complet toujours évincé.
- Logique de connexion au registre : utilise le token GitHub pour `ghcr.io`, sinon utilise les credentials fournis (`REGISTRY_USERNAME` / `REGISTRY_PASSWORD`).
- `BUILD_SECRETS` permet de transmettre des secrets de build (un par ligne, `KEY=VALUE`) via les montages BuildKit (`RUN --mount=type=secret,id=KEY`), sans jamais les écrire dans les layers ou l'historique de l'image (contrairement à `BUILD_ARGS`).
- Les versions prerelease (contenant `-alpha`, `-beta`, `-rc`, etc.) sont détectées et traitées en conséquence.
- Un tag SHA court est automatiquement ajouté pour la traçabilité.
- Les tags basés sur les branches excluent les branches `main` et `develop`.

## Exemples

### Exemple simple

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      contents: read
      packages: write
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
    permissions:
      contents: read
      packages: write
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

Les exemples d'attestation et de signature (provenance, SBOM, signature cosign, builds en matrice) se trouvent désormais dans [Attestation et signature](#attestation-et-signature-attest-dockeryml) ci-dessus, puisqu'ils se composent via un job `attest-docker.yml` séparé plutôt que par des inputs sur ce workflow.

### Build multi-stage avec build args

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      contents: read
      packages: write
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
    permissions:
      contents: read
      packages: write
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

### Build ARM64 via QEMU sur runner AMD64

À utiliser lorsque des runners ARM64 natifs ne sont pas disponibles. Le build est plus lent mais ne nécessite qu'un seul runner.

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      contents: read
      packages: write
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: 1.0.0
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      BUILD_AMD64: true
      BUILD_ARM64: true
      USE_QEMU: true
```

### Build sans push, puis test de l'image

Mettre `PUSH: false` construit l'image et l'exporte en artefact tarball au lieu de la publier. Un job en aval télécharge l'artefact, le charge dans son daemon Docker local et exécute des tests contre l'image réelle - aucun registre impliqué, et rien n'est publié si les tests échouent.

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: pr-${{ github.event.pull_request.number }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      PUSH: false
      BUILD_AMD64: true
      BUILD_ARM64: false

  test:
    needs: build
    runs-on: ubuntu-24.04
    steps:
    - name: Download image artifact
      uses: actions/download-artifact@v6
      with:
        name: ${{ needs.build.outputs.artifact-prefix }}-amd64

    - name: Load and test image
      run: |
        docker load -i image.tar
        docker run -d --rm -p 8080:8080 --name smoke-test \
          ${{ needs.build.outputs.image }}:pr-${{ github.event.pull_request.number }}
        ./ci/scripts/smoke-test.sh http://localhost:8080
```

### Build, test, puis push si les tests passent

Un enchaînement classique : construire sans pousser pour valider l'image avant publication, puis reconstruire et pousser uniquement si les tests passent. Avec `CACHE: true`, le second build est quasiment entièrement un cache hit, donc peu coûteux.

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: ${{ github.sha }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      PUSH: false
      CACHE: true

  test:
    needs: build
    runs-on: ubuntu-24.04
    steps:
    - name: Download image artifact
      uses: actions/download-artifact@v6
      with:
        name: ${{ needs.build.outputs.artifact-prefix }}-amd64

    - name: Load and test image
      run: |
        docker load -i image.tar
        docker run --rm ${{ needs.build.outputs.image }}:${{ github.sha }} --version

  push:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    needs:
    - test
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: ${{ github.sha }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      CACHE: true
```
