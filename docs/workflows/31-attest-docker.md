# `attest-docker.yml`

Génère et attache des attestations de sécurité (provenance SLSA et/ou SBOM), une signature cosign keyless et/ou un prédicat in-toto personnalisé à une image Docker déjà construite et poussée dans un registre. À utiliser **après** [`build-docker.yml`](./30-build-docker.md).

## Inputs

| Input          | Type    | Description                                                                                                                                                                                                                       | Requis | Défaut             |
| -------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE_NAME     | string  | Nom complet de l'image, registre et chemin inclus (ex: `ghcr.io/my-org/my-image`). Normalisé automatiquement.                                                                                                                      | Oui    | -                  |
| DIGEST         | string  | Digest de l'image à attester (ex: `sha256:abc123...`). Utiliser l'output `digest` de `build-docker.yml`.                                                                                                                           | Oui    | -                  |
| PROVENANCE     | boolean | Générer l'attestation standard de provenance de build [SLSA](https://slsa.dev/) de GitHub (workflow appelant, dépôt et commit)                                                                                                     | Non    | `false`            |
| SBOM           | boolean | Générer une attestation SBOM (Software Bill of Materials) pour l'image                                                                                                                                                             | Non    | `false`            |
| SIGN           | boolean | Signer le digest de l'image avec [cosign](https://github.com/sigstore/cosign) en mode keyless                                                                                                                                      | Non    | `false`            |
| PREDICATE_TYPE | string  | URI identifiant le type d'un prédicat in-toto personnalisé à attacher **en complément** des attestations standards. À définir avec `PREDICATE`. Utiliser une URI que vous contrôlez (pas `https://slsa.dev/provenance/v1`).           | Non    | -                  |
| PREDICATE      | string  | Contenu JSON du prédicat in-toto personnalisé. À définir avec `PREDICATE_TYPE`.                                                                                                                                                    | Non    | -                  |
| RUNS_ON        | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                             | Non    | `["ubuntu-24.04"]` |

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
- Au moins un des inputs `PROVENANCE`, `SBOM`, `SIGN` ou le couple `PREDICATE`/`PREDICATE_TYPE` (les deux renseignés) doit être fourni pour que le job effectue une action utile.
- **Provenance SLSA** : `PROVENANCE: true` génère l'attestation standard de provenance de build SLSA de GitHub, détectée automatiquement (workflow, dépôt et commit du dépôt appelant), via [`actions/attest-build-provenance`](https://github.com/actions/attest-build-provenance), attachée à l'image dans le registre.
- **SBOM** : génère un SBOM au format SPDX via Trivy, puis l'attache à l'image dans le registre sous forme d'attestation **cosign** (keyless, Sigstore/Fulcio via OIDC). Voir « Vérification des attestations » ci-dessous - le SBOM se vérifie différemment de la provenance.
- Le SBOM est un **inventaire, pas un rapport de vulnérabilités** - Trivy journalise `"--format spdx-json" disables security scanning`, ce qui est attendu. Les constats deviennent obsolètes en quelques jours alors que la liste des paquets non : les y figer livrerait un verdict faux peu après la publication. Analysez le SBOM avec une base à jour quand vous en avez besoin, sans retirer l'image : `trivy sbom sbom.spdx.json`.
- **Signature** : si `SIGN: true`, le digest de l'image est signé en mode keyless avec cosign (Sigstore/Fulcio via OIDC), indépendamment de `PROVENANCE`/`SBOM`.
- **Prédicat personnalisé** : renseignez `PREDICATE_TYPE` et `PREDICATE` ensemble pour attacher une attestation in-toto supplémentaire **à côté** de la provenance standard - utile, par exemple, pour tracer la source/version amont et les architectures qu'un build miroir reproduit, ce que la provenance auto-générée n'a aucun champ pour porter. Fournir l'un sans l'autre provoque un échec immédiat. Utilisez une URI de type de prédicat que vous contrôlez ; ne réutilisez **pas** le type SLSA réservé `https://slsa.dev/provenance/v1` : GitHub valide son `buildType` contre une liste fixe et rejette les valeurs personnalisées.
- Le nom d'image est normalisé automatiquement (minuscules, `_` remplacés par `-`) pour être compatible avec les registres OCI.
- Pour `ghcr.io`, l'authentification utilise automatiquement `github.token` ; pour les autres registres, fournir `REGISTRY_USERNAME` et `REGISTRY_PASSWORD` en tant que secrets.
- **Builds en matrice** : un job `build-docker.yml` en matrice ne peut pas alimenter un unique job `attest` matricé de la même façon - `needs.<job>.outputs.<name>` s'effondre en une seule valeur à travers toutes les combinaisons de la matrice (comportement documenté de GitHub - la dernière écriture l'emporte), donc le digest qu'un job `attest` matricé verrait est faux pour toutes les combinaisons sauf une. Utilisez plutôt une paire explicite et non matricée de jobs `build`/`attest` par image. Voir [build-docker.yml → Builds en matrice](./30-build-docker.md#builds-en-matrice) pour le pattern complet.
- La provenance n'est pas conditionnée par les étapes SBOM : c'est l'attestation qui établit où et à partir de quoi l'image a été construite, un problème de génération ou d'attachement du SBOM ne lui coûte donc jamais sa provenance.

## Vérification des attestations

Les deux attestations utilisent des mécanismes différents, donc des commandes de vérification différentes.

**Provenance** — une attestation GitHub, visible aussi dans l'onglet Attestations du dépôt :

```sh
gh attestation verify oci://ghcr.io/my-org/my-app:1.2.3 --owner my-org
```

**SBOM** — une attestation cosign :

```sh
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp '^https://github.com/dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/my-org/my-app@sha256:abc123...
```

> [!IMPORTANT]
> L'identité du certificat est le **workflow réutilisable qui a signé** - toujours `dnum-mi/fabnum-cicd/.github/workflows/attest-docker.yml`, quel que soit le dépôt appelant - et non le dépôt qui publie l'image. La signature keyless enregistre le workflow appelé dans le certificat ; ancrer le pattern sur le dépôt qui publie l'image (`my-org` ci-dessus) ne correspondra donc jamais. Ne pas retirer la contrainte pour la faire passer : sans elle, la vérification accepte une signature de n'importe qui.

### Pourquoi le SBOM utilise cosign

`actions/attest` refuse un SBOM de plus de 16 Mio. Cette limite est atteignable sur un contenu ordinaire - le graphe de modules transitifs de quelques dizaines de binaires Go ou Rust statiquement liés compte des milliers de paquets - et le seul moyen de passer sous le plafond serait de supprimer des entrées, ce qui retire précisément les données de chaîne d'approvisionnement que le SBOM existe pour porter.

cosign n'a pas un tel plafond, il est donc utilisé pour **tous** les SBOM plutôt que comme repli au-delà d'une certaine taille. Si le mécanisme changeait avec la taille, la commande nécessaire pour vérifier le SBOM d'une image dépendrait de la taille qu'elle se trouve avoir, et pourrait changer d'une release à l'autre à mesure qu'elle grossit. Un seul mécanisme, c'est une seule commande, pour toutes les images, durablement.

La provenance reste sur `actions/attest-build-provenance` car cette action *génère* le prédicat SLSA - plateforme de build, workflow, commit, invocation. cosign ne fait que signer un prédicat que vous avez déjà.

Le compromis : les SBOM n'apparaissent pas dans l'onglet Attestations du dépôt et ne sont pas retournés par `gh attestation verify`. La provenance, si.

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

### Provenance standard et prédicat personnalisé (ex: métadonnées d'un miroir)

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
      SBOM: true
      PROVENANCE: true
      PREDICATE_TYPE: https://my-org.github.io/my-repo/mirror/v1
      PREDICATE: '{"upstream":{"repository":"upstream-org/upstream-repo","source":"https://github.com/upstream-org/upstream-repo","version":"1.2.3","ref":"v1.2.3"},"mirror":{"architectures":["amd64","arm64"]}}'
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
