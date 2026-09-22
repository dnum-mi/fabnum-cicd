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
| IMAGE_METADATA      | boolean | Poser le jeu standard `org.opencontainers.image.*` (title, description, url, source, revision, version, created, licenses) en labels sur chaque image et en annotations `index:` sur la manifest list. Voir [Labels et annotations OCI](#labels-et-annotations-oci). Désactiver quand les `LABEL` du Dockerfile doivent l'emporter, ou quand un rebuild inchangé doit continuer à retomber sur le même digest. `IMAGE_LABELS`/`IMAGE_ANNOTATIONS` s'appliquent dans les deux cas. | Non    | `true`             |
| IMAGE_LABELS        | string  | Labels OCI personnalisés séparés par des sauts de ligne, au format `KEY=VALUE` (ex: `com.example.team=platform`). Appliqués après le jeu d'`IMAGE_METADATA` : une clé donnée ici écrase la valeur standard sans avoir à désactiver tout le jeu. Jamais de secret ici : valeurs gravées dans l'image, lisibles par quiconque peut la pull ou l'inspecter. | Non    | -                  |
| IMAGE_ANNOTATIONS   | string  | Annotations OCI personnalisées séparées par des sauts de ligne, au format `KEY=VALUE` (sans préfixe de niveau : elles sont posées au niveau `index`). Mêmes ordre et précédence qu'`IMAGE_LABELS`. Contrairement à `IMAGE_LABELS`, ne peut pas être défini depuis le Dockerfile, et n'existe que si `PUSH` est `true` - un build non poussé n'a pas de manifest list. Même mise en garde : texte en clair, jamais de secret. | Non    | -                  |
| PUSH                | boolean | Pousser l'image construite vers le registre. Si `false`, l'image est exportée sous forme d'artefact tarball (un par architecture) au lieu d'être poussée, pour qu'un job en aval puisse la charger avec `docker load` et exécuter des tests dessus. | Non    | `true`             |
| TAG_MAJOR_AND_MINOR | boolean | Créer des tags pour les versions majeure et mineure (ex: `1.2.3` → `1.2` et `1`)                                                                                                                                                                    | Non    | `false`            |
| TAG_SHORT_SHA       | boolean | Taguer avec le SHA court du commit                                                                                                                                                                                                                  | Non    | `false`            |
| BUILD_AMD64         | boolean | Build pour l'architecture amd64                                                                                                                                                                                                                     | Non    | `true`             |
| BUILD_ARM64         | boolean | Build pour l'architecture arm64                                                                                                                                                                                                                     | Non    | `true`             |
| USE_QEMU            | boolean | Utiliser l'émulateur QEMU pour arm64                                                                                                                                                                                                                | Non    | `false`            |
| BUILD_ARGS          | string  | Liste de build args Docker séparés par des sauts de ligne (ex: `MY_ARG=value`)                                                                                                                                                                      | Non    | -                  |
| BUILD_SECRET_GITHUB_TOKEN | string | Credential à exposer comme secret de build `github_token=<token>` (lisible dans le Dockerfile à `/run/secrets/github_token`), pour relever la limite d'API GitHub des outils qui résolvent des releases pendant le build (mise, aqua, ubi). `none` (défaut) n'injecte rien. `app` mint un token App réduit à `contents:read` + `metadata:read` sur ce dépôt, échoue si absent. `pat` utilise le token App si disponible sinon `GH_PAT`, échoue si aucun des deux. `job-token` retombe en plus sur le `GITHUB_TOKEN` du job, qui ne peut pas être réduit et porte tout le bloc `permissions:` de l'appelant. Voir [`authentication.md`](./05-authentication.md#ce-que-build-docker-injecte-réellement). | Non    | `none`             |
| CACHE               | boolean | Activer le cache de build Docker (utilise le backend de cache GitHub Actions)                                                                                                                                                                       | Non    | `false`            |
| CACHE_MODE          | string  | Mode d'export du cache Buildx : `max` (toutes les couches intermédiaires) ou `min` (uniquement l'image finale)                                                                                                                                      | Non    | `max`              |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                              | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                                                                                                                | Requis |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour le registre                                                                                         | Non    |
| REGISTRY_PASSWORD | Mot de passe pour le registre                                                                                              | Non    |
| BUILD_SECRETS     | Liste de secrets de build au format `KEY=VALUE` (un par ligne), exposés au Dockerfile via `RUN --mount=type=secret,id=KEY` | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App, utilisé uniquement pour minter le token injecté par `BUILD_SECRET_GITHUB_TOKEN`. Toujours réduit à `contents:read` + `metadata:read` sur ce dépôt. Voir [`authentication.md`](./05-authentication.md). | Non    |
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
- Deux workflows de ce dépôt consomment directement l'artefact tarball, permettant de valider entièrement une image non poussée : [`scan-trivy.yml`](./41-scan-trivy.md) via son input `IMAGE_ARTIFACT` (mode tarball de Trivy) et `test-kube-deployment.yml` (non repris dans ce dépôt) via `kind load image-archive`. L'attestation est la seule chose qui ne peut vraiment pas fonctionner sans push, puisque les attestations sont liées à un digest de registre.
- **Multi-arch** : avec `USE_QEMU: false` (runners natifs), construire les deux architectures produit deux tarballs mono-architecture indépendants - un par runner - ce qui est généralement souhaitable, puisqu'un job de test ne peut de toute façon exécuter qu'une seule architecture à la fois.
- **Combinaison non supportée** : `PUSH: false` + `USE_QEMU: true` + `BUILD_AMD64` et `BUILD_ARM64` tous les deux à `true`. L'exporteur `docker` ne peut pas écrire une manifest list multi-plateforme dans un tarball, le workflow échoue donc rapidement dans le job `infos` avec une erreur explicite. Utiliser des runners natifs (`USE_QEMU: false`) ou construire une seule architecture à la fois.
- **Connexion au registre** : ignorée quand `PUSH` est `false`, sauf si l'image cible `ghcr.io` (les credentials résolvent toujours depuis le token du job) ou si `REGISTRY_USERNAME` est fourni. Une image non-GHCR peut donc être construite sans aucun credential, tandis qu'une image de base privée peut toujours être pull en fournissant les secrets malgré tout.

### Credential GitHub dans le build (`BUILD_SECRET_GITHUB_TOKEN`)

- Le credential est résolu depuis une source explicitement nommée : `none` (défaut) n'injecte rien, `app` mint un token App en lecture seule dédié, `pat` accepte aussi `GH_PAT`, `job-token` accepte en plus le `GITHUB_TOKEN` du job (non réduit, porte tout le bloc `permissions:` de l'appelant - un job appelant ce workflow accorde généralement `packages: write`).
- Injecté via un montage BuildKit (`/run/secrets/github_token`), jamais écrit dans un fichier sur le runner ni dans les layers de l'image.
- `app`/`pat` échouent explicitement si le credential demandé est absent, plutôt que de retomber silencieusement sur un mode plus large. `job-token` émet un `::warning::` s'il retombe effectivement sur le `GITHUB_TOKEN` du job.
- Voir [`authentication.md`](./05-authentication.md#ce-que-build-docker-injecte-réellement) pour le détail des quatre modes et un exemple câblé.

## Labels et annotations OCI

Par défaut (`IMAGE_METADATA: true`), ce workflow pose le jeu standard `org.opencontainers.image.*` (`title`, `description`, `url`, `source`, `revision`, `version`, `created`, `licenses`, calculés par [`docker/metadata-action`](https://github.com/docker/metadata-action)). C'est lui qui permet à ce qui ne voit que l'image - une interface de registre, un scanner, un inventaire côté cluster - de relier une étiquette en service au dépôt et au commit dont elle provient.

- **Labels** (config de l'image) : gravés au moment du build, dans le job `build`, car ils font partie de la configuration de chaque image par architecture. Calculés une seule fois dans le job `infos` (plutôt que dupliqués dans chaque leg de la matrice) pour que `org.opencontainers.image.created` reste identique entre les builds amd64 et arm64 d'une même image logique.
- **Annotations** (manifest list) : ce sont les mêmes valeurs, au niveau `index`, issues du **même** appel à `docker/metadata-action` que les labels, dans le job `infos`. Un second appel prendrait sa propre heure pour `org.opencontainers.image.created`, et l'index contredirait alors sur leur date de build les images qu'il référence. Elles ne peuvent en revanche être *posées* qu'au moment où le job `merge` assemble la manifest list multi-arch, avec `docker buildx imagetools create --annotation`. `imagetools create` n'accepte que les niveaux `index`/`descriptor`, jamais `manifest` - `index` est aussi la cible sémantiquement correcte ici, puisque c'est la seule manifest list qu'un appelant pull réellement par tag.
- `IMAGE_LABELS` / `IMAGE_ANNOTATIONS` ajoutent des clés personnalisées. Elles sont appliquées **après** le jeu standard, et le dernier `--label`/`--annotation` posé pour une clé est celui qui subsiste : une clé standard peut donc être écrasée individuellement, sans désactiver le reste du jeu. Elles s'appliquent aussi quand `IMAGE_METADATA` est `false`.
- Avec `PUSH: false`, seuls les labels sont posés : il n'y a pas de manifest list à annoter (le job `merge` est ignoré).
- `org.opencontainers.image.revision` vaut le `github.sha` du run. Sur un événement `pull_request`, c'est le commit de fusion éphémère de la PR, pas la tête de la branche - ce commit disparaît une fois la PR fermée.

### Compromis : `org.opencontainers.image.created` et reproductibilité du digest

Le label/annotation `created` embarque l'horodatage réel du build. Deux builds strictement identiques (même Dockerfile, même contexte) ne produisent donc plus le même digest d'une exécution à l'autre - le dédoublonnage incident que permettait le content-addressing de BuildKit sur des rebuilds inchangés est perdu. C'est le compromis assumé par défaut : la traçabilité (savoir précisément quand une image a été construite) prime sur la réutilisation de digest. Un appelant pour qui ce dédoublonnage compte passe `IMAGE_METADATA: false`.

### Labels du Dockerfile

Une instruction `LABEL` dans le Dockerfile reste la façon normale d'ajouter des labels propres à l'image, y compris des valeurs dynamiques par run via le `BUILD_ARGS` déjà existant (`ARG X` + `LABEL foo=$X`) - `IMAGE_LABELS` n'est utile que pour des labels décidés côté appelant du workflow plutôt que dans le Dockerfile.

En cas de collision de clé, **c'est le workflow qui l'emporte** : un `--label` de build écrase le `LABEL` du Dockerfile portant la même clé (vérifié : un `LABEL org.opencontainers.image.version` du Dockerfile ressort avec la valeur du `--label`). Les clés qui n'entrent pas en collision, des deux côtés, sont conservées. Pour garder la valeur du Dockerfile sur une clé standard, la redonner via `IMAGE_LABELS` (appliqué en dernier) ou désactiver le jeu avec `IMAGE_METADATA: false`.

Les annotations, elles, ne peuvent jamais venir du Dockerfile - ce n'est pas un concept qu'une instruction `LABEL` peut exprimer.

### Sécurité et traçabilité

- `org.opencontainers.image.source` correctement positionné est ce que GitHub utilise pour rattacher un package GHCR à son dépôt d'origine (lien "View repository", héritage de la visibilité du dépôt) - un bénéfice qui dépasse la simple documentation de l'image.
- Ces labels/annotations sont du texte en clair, non signé et non vérifiable cryptographiquement - n'importe qui disposant d'un accès en écriture au registre peut les réécrire. Ils servent la découvrabilité et le diagnostic, pas la preuve. Pour une traçabilité qui doit résister à falsification (provenance SLSA, SBOM, signature), utiliser [`attest-docker.yml`](./31-attest-docker.md) (`PROVENANCE`/`SIGN`) - voir [Attestation et signature](#attestation-et-signature-attest-dockeryml) ci-dessous.

### Vérifier labels et annotations sur une image construite

```bash
# Annotations (niveau index) de la manifest list poussée
docker buildx imagetools inspect ghcr.io/my-org/my-image:1.2.3

# Labels de la configuration image (n'importe quelle plateforme, ils sont identiques)
docker buildx imagetools inspect ghcr.io/my-org/my-image:1.2.3 --format '{{json .Image.Config.Labels}}'
```

## Attestation et signature (`attest-docker.yml`)

Ce workflow n'a aucun chemin d'attestation intégré - il ne déclare jamais d'appel imbriqué demandant `id-token`/`attestations`, donc un appelant qui ne fait que build et push n'a jamais besoin de les accorder. La provenance SLSA, le SBOM et la signature cosign relèvent entièrement de [`attest-docker.yml`](./31-attest-docker.md), composé comme un second job explicite alimenté par les outputs `digest`/`image` de ce workflow :

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
- `TAG_SHORT_SHA` (défaut `false`) ajoute un tag portant le SHA court du commit. Désactivé par défaut : un appelant dont les branches sont rebasées ou poussées en force peut reconstruire le même contenu d'image sur un commit sans rapport, ce qui réutilise le digest précédent - le nouveau SHA s'ajoute alors comme un tag de plus sur cette version toujours vivante au lieu de marquer quoi que ce soit de nouveau, et ces tags s'accumulent tant que la branche existe, puisque seule une version entière peut être supprimée, jamais un tag isolé. À activer pour la traçabilité par commit quand ce risque ne s'applique pas.
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

### Labels et annotations personnalisés

Le jeu standard `org.opencontainers.image.*` est déjà appliqué par défaut (voir [Labels et annotations OCI](#labels-et-annotations-oci)) ; `IMAGE_LABELS`/`IMAGE_ANNOTATIONS` ne sont nécessaires que pour des clés supplémentaires ou pour écraser une valeur générée.

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
      IMAGE_LABELS: |
        com.example.team=platform
        com.example.cost-center=1234
      IMAGE_ANNOTATIONS: |
        org.opencontainers.image.description=Service de paiement interne
```

Pour laisser les `LABEL` du Dockerfile seuls maîtres, ou garder un digest stable entre deux rebuilds inchangés, désactiver le jeu standard - les clés personnalisées, elles, continuent de s'appliquer :

```yaml
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: 1.0.0
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      IMAGE_METADATA: false
      IMAGE_LABELS: |
        com.example.team=platform
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
