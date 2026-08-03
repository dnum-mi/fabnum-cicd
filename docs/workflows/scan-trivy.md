# `scan-trivy.yml`

Analyse de vulnérabilités avec [Trivy](https://github.com/aquasecurity/trivy) pour les images Docker et les fichiers système.

## Inputs

| Input               | Type    | Description                                                                                                                                                                                                                             | Requis | Défaut             |
| ------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE               | string  | Image utilisée pour effectuer le scan (ex: `docker.io/debian:latest`)                                                                                                                                                                   | Non    | -                  |
| IMAGE_ARTIFACT      | string  | Nom d'un artefact de workflow contenant un tarball d'image à scanner localement, au lieu de pull `IMAGE` depuis un registre (ex: produit par `build-docker.yml` avec `PUSH: false`). Prend le pas sur `IMAGE` si les deux sont fournis. | Non    | -                  |
| IMAGE_ARTIFACT_FILE | string  | Nom du fichier tarball dans `IMAGE_ARTIFACT`                                                                                                                                                                                            | Non    | `image.tar`        |
| PATH                | string  | Chemin utilisé pour effectuer le scan                                                                                                                                                                                                   | Non    | -                  |
| FORMAT              | string  | Format du rapport (`sarif`, `table`, `json`, etc.)                                                                                                                                                                                      | Non    | `table`            |
| PR_NUMBER           | string  | Numéro de la PR si le workflow est déclenché par une pull request                                                                                                                                                                       | Non    | -                  |
| GITHUB_SECURITY_TAB | boolean | Lier l'onglet GitHub Security dans le commentaire de la PR                                                                                                                                                                              | Non    | `false`            |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                  | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret            | Description                                     | Requis |
| ----------------- | ----------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour se connecter au registre | Non    |
| REGISTRY_PASSWORD | Mot de passe pour se connecter au registre      | Non    |

## Permissions

| Scope           | Accès | Description                                       |
| --------------- | ----- | ------------------------------------------------- |
| contents        | read  | Lire le code source                               |
| security-events | write | Upload des résultats SARIF vers l'onglet Security |
| pull-requests   | write | Commenter les PRs avec les résultats du scan      |
| packages        | read  | Lire les images depuis GHCR                       |

## Notes

- `images-scan` s'exécute si `IMAGE` ou `IMAGE_ARTIFACT` est fourni ; `config-scan` s'exécute uniquement si `PATH` est fourni.
- `IMAGE_ARTIFACT` permet de scanner une image qui n'a jamais été poussée vers un registre. L'artefact est téléchargé depuis le run de workflow courant et transmis à Trivy en mode tarball (`--input`), donc le scan ne nécessite aucun accès registre. S'associe à `build-docker.yml` utilisé avec `PUSH: false`, pour conditionner la publication au résultat du scan plutôt que de scanner après coup.
- `IMAGE_ARTIFACT` prend le pas sur `IMAGE` si les deux sont fournis - seul le tarball local est scanné, rien n'est pull.
- L'artefact doit avoir été produit par le **même run de workflow** ; le téléchargement depuis un autre run n'est pas supporté.
- Peut scanner à la fois des images Docker et des systèmes de fichiers.
- Supporte plusieurs formats de sortie (table, SARIF, JSON, etc.).
- Les résultats SARIF peuvent être uploadés vers l'onglet GitHub Security.
- Ignore les vulnérabilités non corrigées par défaut (`ignore-unfixed: true`).
- Pour les images GHCR (ghcr.io), utilise automatiquement les credentials GitHub.
- Affiche les résultats dans le résumé du workflow GitHub Actions.
- Continue même en cas d'erreur pour permettre la revue des résultats.

## Exemples

### Scan d'une image Docker

```yaml
name: Security Scan

on:
  pull_request:

jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    with:
      IMAGE: ghcr.io/my-org/my-app:latest
      FORMAT: table
```

### Scan avec upload vers GitHub Security

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    with:
      IMAGE: ghcr.io/my-org/my-app:${{ github.sha }}
      FORMAT: sarif
      GITHUB_SECURITY_TAB: true
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Scan d'un système de fichiers

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    with:
      PATH: ./
      FORMAT: table
```

### Scan avec registre personnalisé

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    with:
      IMAGE: docker.io/my-org/my-app:latest
      FORMAT: json
    secrets:
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Scan d'une image construite mais non poussée

À associer à `build-docker.yml` utilisé avec `PUSH: false` pour scanner l'image **avant** qu'elle soit publiée. Le build exporte l'image en artefact tarball, et Trivy la scanne localement en mode tarball - aucun registre impliqué, donc une image vulnérable n'atteint jamais le registre.

```yaml
jobs:
  build:
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ghcr.io/my-org/my-image
      IMAGE_TAG: ${{ github.sha }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      PUSH: false

  scan:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    permissions:
      contents: read
      security-events: write
      packages: read
    with:
      IMAGE_ARTIFACT: ${{ needs.build.outputs.artifact-prefix }}-amd64
      FORMAT: table
```
