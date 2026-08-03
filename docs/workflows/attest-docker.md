# `attest-docker.yml`

Génère et attache des attestations de sécurité (provenance SLSA et/ou SBOM), une signature cosign et/ou un prédicat in-toto personnalisé à une image Docker déjà construite et poussée dans un registre. À utiliser après [`build-docker.yml`](./build-docker.md).

## Inputs

| Input          | Type    | Description                                                                                                                                        | Requis | Défaut             |
| -------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE_NAME     | string  | Nom de l'image à attester (ex: `ghcr.io/my-org/my-image`). Normalisé automatiquement.                                                              | Oui    | -                  |
| DIGEST         | string  | Digest de l'image à attester (ex: `sha256:abc123...`). Utiliser l'output `digest` de `build-docker.yml`.                                           | Oui    | -                  |
| PROVENANCE     | boolean | Générer une attestation de provenance [SLSA](https://slsa.dev/) pour l'image                                                                       | Non    | `false`            |
| SBOM           | boolean | Générer une attestation SBOM (Software Bill of Materials) pour l'image                                                                             | Non    | `false`            |
| SIGN           | boolean | Signer le digest de l'image avec [cosign](https://github.com/sigstore/cosign) en mode keyless                                                      | Non    | `false`            |
| PREDICATE_TYPE | string  | URI identifiant le type d'un prédicat in-toto personnalisé à attacher en complément des attestations standards (doit être défini avec `PREDICATE`) | Non    | -                  |
| PREDICATE      | string  | Contenu JSON du prédicat in-toto personnalisé (doit être défini avec `PREDICATE_TYPE`)                                                             | Non    | -                  |
| RUNS_ON        | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                             | Non    | `["ubuntu-24.04"]` |

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
- Au moins un des inputs `PROVENANCE`, `SBOM`, `SIGN` ou le couple `PREDICATE`/`PREDICATE_TYPE` doit être renseigné pour que le job effectue une action utile.
- **Provenance SLSA** : génère une attestation conforme à [SLSA niveau 3](https://slsa.dev/spec/v1.0/levels) attachée à l'image dans le registre.
- **SBOM** : génère un fichier SBOM au format SPDX via Trivy, puis l'atteste et l'attache à l'image dans le registre.
- **Signature cosign** : si `SIGN: true`, signe le digest de l'image en mode keyless (sans gestion de clé) via [Sigstore](https://www.sigstore.dev/).
- **Prédicat personnalisé** : `PREDICATE` et `PREDICATE_TYPE` doivent être fournis ensemble ; permet d'attacher une attestation in-toto arbitraire (ex: pour tracer la source/version amont d'une image miroir). Utiliser une URI que vous contrôlez, pas le type SLSA réservé `https://slsa.dev/provenance/v1`.
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

> [!TIP]
> `build-docker.yml` peut aussi appeler `attest-docker.yml` directement en lui passant `PROVENANCE: true` et/ou `SBOM: true` : voir [`build-docker.md`](./build-docker.md).

### Provenance uniquement

```yaml
jobs:
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
```

### Avec signature cosign

```yaml
jobs:
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
      SIGN: true
```

### Avec registre personnalisé

```yaml
jobs:
  attest:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml@v0
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
