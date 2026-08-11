# `attest-helm.yml`

Attestations pour les charts Helm publiés sur un registre OCI : signatures cosign keyless et provenance de build SLSA. Consomme la sortie `published-charts` de [`release-helm.yml`](./51-release-helm.md) et atteste chaque chart par son digest.

Les inputs de capacité reprennent ceux d'[`attest-docker.yml`](./31-attest-docker.md) : une image et un chart sont attestés de la même façon - les deux flux sont keyless, pilotés par le token OIDC GitHub du job, sans aucune clé au repos.

> **Références :** [sigstore/cosign](https://github.com/sigstore/cosign) · [Helm provenance and integrity](https://helm.sh/docs/topics/provenance/)

## Pourquoi un workflow séparé

Les deux capacités nécessitent `id-token: write` pour émettre un token OIDC. GitHub valide les permissions demandées par **chaque** job d'un workflow appelé au moment du parsing, indépendamment du `if:` de chacun - intégrer cette logique à `release-helm.yml` obligerait donc tous les appelants à accorder l'émission de tokens OIDC, y compris ceux qui ne signent jamais rien. La séparation garde ce scope avec le workflow qui l'utilise réellement.

C'est le même raisonnement qui sépare [`attest-docker.yml`](./31-attest-docker.md) de [`build-docker.yml`](./30-build-docker.md), et [`release-helm-local.yml`](./52-release-helm-local.md#pourquoi-un-workflow-séparé) de `release-helm.yml`. `ci/tests/permission-union.test.sh` fait respecter l'invariant associé.

## Inputs

| Input      | Type    | Description                                                                                                                                                                       | Requis | Défaut             |
| ---------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| CHARTS     | string  | Tableau JSON des charts à attester, tel que produit par la sortie `published-charts` de `release-helm.yml` : `{name, version, repository, digest}` par entrée. Un tableau vide est sans effet. | Oui    | -                  |
| SIGN       | boolean | Signer le digest du chart avec la signature keyless cosign                                                                                                                          | Non    | `false`            |
| PROVENANCE | boolean | Générer l'attestation standard de provenance de build SLSA de GitHub (enregistre le workflow appelant, le dépôt et le commit)                                                       | Non    | `false`            |
| RUNS_ON    | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                             | Non    | `["ubuntu-24.04"]` |

**Au moins un de `SIGN` et `PROVENANCE` doit être activé.** Aucun des deux déploierait une matrice de jobs qui se connectent à un registre sans rien faire - au vert, et indiscernable d'un run ayant tout attesté.

## Secrets

| Secret            | Description                                                             | Requis |
| ----------------- | ----------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre (inutile pour `ghcr.io`) | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre (inutile pour `ghcr.io`)      | Non    |

## Permissions

| Scope        | Accès | Description                                                        |
| ------------ | ----- | ------------------------------------------------------------------ |
| packages     | write | Pousser les artefacts de signature et d'attestation à côté du chart |
| id-token     | write | Émettre le token OIDC échangé contre un certificat de signature éphémère |
| attestations | write | Requis par `actions/attest-build-provenance`                        |

## Notes

- **Chaque entrée doit porter un `digest`.** Le workflow rejette toute valeur qui n'est pas de la forme `sha256:...`, y compris un tag glissé dans le champ. Attester un tag lierait l'affirmation à ce que ce tag résoudra au moment de la vérification - précisément la garantie que l'attestation existe pour supprimer. Transmettre `published-charts` tel quel satisfait toujours cette contrainte.
- **Un tableau vide est sans effet**, le job peut donc être branché inconditionnellement : il reste vert quand `PUBLISH_OCI` est `false` ou qu'aucun chart n'a changé. Cela repose sur le garde `if:` au niveau du job - une matrice construite depuis un tableau vide ne saute pas le job, elle le fait échouer.
- **Plusieurs charts se répartissent sur une matrice**, un job par chart, car `actions/attest-build-provenance` ne prend qu'un seul sujet. `fail-fast` est désactivé pour qu'un chart en échec ne masque pas l'état des autres ; le job échoue malgré tout globalement.
- **Tous les charts doivent partager le même registre.** Un seul login est effectué par job, une liste mixte échoue donc en amont plutôt qu'au moment de l'authentification.
- **Le registre est relu depuis les références** plutôt que fourni en input : elles le portent déjà, et une seconde source de vérité pourrait diverger des charts réellement attestés.
- **La provenance ne dépend pas de la réussite de la signature.** La provenance établit où un chart a été construit et à partir de quoi : un problème de signature ne doit jamais être la raison pour laquelle un chart part sans elle - le même ordonnancement que `attest-docker.yml`.
- Un chart Helm dans un registre OCI est un artefact OCI ordinaire : les deux flux sont donc ceux que `attest-docker.yml` utilise pour les images.

## Ce qu'apporte chaque capacité

| | `SIGN` | `PROVENANCE` |
| --- | --- | --- |
| Affirmation | *ce workflow a signé cet artefact* | *ce workflow a construit cet artefact, depuis ce dépôt et ce commit* |
| Produite par | cosign keyless (certificat Fulcio, journalisé dans Rekor) | `actions/attest-build-provenance` (SLSA) |
| Vérifiée avec | `cosign verify` | `gh attestation verify` ou `cosign verify-attestation` |
| Gestion de clé | keyless - aucune clé à détenir | keyless - aucune clé à détenir |

Une signature dit qui se porte garant des octets. La provenance dit d'où ils viennent. Pour un chart qui épingle des versions d'images applicatives, la provenance est souvent la plus utile des deux - d'où deux inputs indépendants plutôt qu'un seul interrupteur.

## Relation avec `SIGN_CHART`

`SIGN_CHART` dans [`release-helm.yml`](./51-release-helm.md#signature) couvre l'*autre* canal de distribution et n'est une alternative à rien de ce qui précède :

| | `release-helm.yml` `SIGN_CHART: true` | `attest-helm.yml` |
| --- | --- | --- |
| Produit | un fichier de provenance GPG `.prov` | signatures cosign et/ou provenance SLSA dans le registre |
| Couvre | le canal GitHub Release / `helm repo add` | le canal OCI |
| Vérifié avec | `helm verify` / `helm install --verify` | `cosign verify` / `gh attestation verify` |
| Gestion de clé | votre clé GPG, en secrets du dépôt | keyless - aucune clé à détenir |

`helm verify` n'implémente qu'OpenPGP : le canal classique ne peut donc pas utiliser le flux keyless, et c'est pour cela que GPG subsiste plutôt que d'être une préférence. Inversement, `helm push` n'emporte pas de fichier `.prov` vers un registre OCI, d'où l'exigence de `CREATE_GITHUB_RELEASE` pour `SIGN_CHART`.

Si vous ne publiez que sur OCI, préférez ce workflow et ne détenez aucune clé GPG. Une clé de signature à longue durée de vie ne vaut sa charge de gestion que si les consommateurs exécutent réellement `helm verify`.

## Vérifier

```bash
# Signature (SIGN)
cosign verify ghcr.io/my-org/my-repo/my-chart@sha256:... \
  --certificate-identity-regexp '^https://github.com/my-org/my-repo/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Provenance de build (PROVENANCE)
gh attestation verify oci://ghcr.io/my-org/my-repo/my-chart@sha256:... \
  --repo my-org/my-repo
```

L'identité est le workflow qui a produit l'attestation : épinglez-la aussi finement que votre configuration le permet - un `--certificate-identity` exact pointant le fichier de workflow est plus fort que l'expression régulière ci-dessus.

## Exemples

### Signer et attester les charts publiés par `release-helm.yml`

```yaml
jobs:
  release-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true

  attest-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-helm.yml@v0
    needs:
    - release-charts
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      CHARTS: ${{ needs.release-charts.outputs.published-charts }}
      SIGN: true
      PROVENANCE: true
```

Aucun `if:` n'est nécessaire sur `attest-charts` : un `published-charts` vide est sans effet.

### Provenance uniquement

Pour un chart dont l'affirmation utile est son origine plutôt que son signataire :

```yaml
  attest-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-helm.yml@v0
    needs:
    - release-charts
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      CHARTS: ${{ needs.release-charts.outputs.published-charts }}
      PROVENANCE: true
```

### Les deux canaux, tous les mécanismes

Provenance GPG pour le dépôt classique, cosign et provenance SLSA pour les artefacts OCI.

```yaml
jobs:
  release-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      CREATE_GITHUB_RELEASE: true
      SIGN_CHART: true
      SIGNING_KEY_ID: "Jane Doe <jane@example.com>"
    secrets:
      GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
      GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}

  attest-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-helm.yml@v0
    needs:
    - release-charts
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      CHARTS: ${{ needs.release-charts.outputs.published-charts }}
      SIGN: true
      PROVENANCE: true
```

### Registre personnalisé

```yaml
  attest-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/attest-helm.yml@v0
    needs:
    - release-charts
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      CHARTS: ${{ needs.release-charts.outputs.published-charts }}
      SIGN: true
    secrets:
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```
