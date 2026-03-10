# `attest-image.yml`

Génère et attache des attestations de sécurité (provenance SLSA et/ou SBOM) à une image Docker déjà construite et poussée dans un registre. À utiliser après [`build-docker.yml`](./build-docker.md).

## Inputs

| Input      | Type    | Description                                                                                              | Requis | Défaut             |
| ---------- | ------- | -------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE_NAME | string  | Nom de l'image à attester (ex: `ghcr.io/my-org/my-image`). Normalisé automatiquement.                    | Oui    | -                  |
| DIGEST     | string  | Digest de l'image à attester (ex: `sha256:abc123...`). Utiliser l'output `digest` de `build-docker.yml`. | Oui    | -                  |
| PROVENANCE | boolean | Générer une attestation de provenance [SLSA](https://slsa.dev/) pour l'image                             | Non    | `false`            |
| SBOM       | boolean | Générer une attestation SBOM (Software Bill of Materials) pour l'image                                   | Non    | `false`            |
| RUNS_ON    | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                   | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                                                    | Requis |
| ----------------- | -------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour le registre (non requis pour `ghcr.io`) | Non    |
| REGISTRY_PASSWORD | Mot de passe pour le registre (non requis pour `ghcr.io`)      | Non    |

## Permissions

| Scope        | Accès | Description                                  |
| ------------ | ----- | -------------------------------------------- |
| packages     | write | Push des attestations vers le registre       |
| id-token     | write | Requis pour signer les attestations via OIDC |
| attestations | write | Requis pour créer les attestations GitHub    |

## Notes

- Ce workflow est conçu pour être appelé **après** `build-docker.yml`, en utilisant ses outputs `digest` et `image`.
- Au moins un des inputs `PROVENANCE` ou `SBOM` doit être `true` pour que le job effectue une action utile.
- **Provenance SLSA** : génère une attestation conforme à [SLSA niveau 3](https://slsa.dev/spec/v1.0/levels) attachée à l'image dans le registre.
- **SBOM** : génère un fichier SBOM au format SPDX via Trivy, puis l'atteste et l'attache à l'image dans le registre.
- Le nom d'image est normalisé automatiquement (minuscules, `_` remplacés par `-`) pour être compatible avec les registres OCI.
- Pour `ghcr.io`, l'authentification utilise automatiquement `github.token` ; pour les autres registres, fournir `REGISTRY_USERNAME` et `REGISTRY_PASSWORD` en tant que secrets.

## Exemples

### Après un build avec provenance et SBOM

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      LATEST_TAG: true

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

### Provenance uniquement

```yaml
jobs:
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
```

### Avec registre personnalisé

```yaml
jobs:
  attest:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-image.yml@v0
    needs:
    - build
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: docker.io/my-org/my-image
      DIGEST: ${{ needs.build.outputs.digest }}
      PROVENANCE: true
      SBOM: true
    secrets:
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```
