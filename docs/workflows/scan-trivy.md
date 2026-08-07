# `scan-trivy.yml`

Analyse de vulnérabilités avec [Trivy](https://github.com/aquasecurity/trivy) pour les images Docker et les fichiers système.

## Inputs

| Input               | Type    | Description                                                                                                                                                                                                                             | Requis | Défaut              |
| ------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| IMAGE               | string  | Image utilisée pour effectuer le scan (ex: `docker.io/debian:latest`)                                                                                                                                                                   | Non    | -                   |
| IMAGE_ARTIFACT      | string  | Nom d'un artefact de workflow contenant un tarball d'image à scanner localement, au lieu de pull `IMAGE` depuis un registre (ex: produit par `build-docker.yml` avec `PUSH: false`). Prend le pas sur `IMAGE` si les deux sont fournis. | Non    | -                   |
| IMAGE_ARTIFACT_FILE | string  | Nom du fichier tarball dans `IMAGE_ARTIFACT`                                                                                                                                                                                            | Non    | `image.tar`         |
| PATH                | string  | Chemin utilisé pour effectuer le scan                                                                                                                                                                                                   | Non    | -                   |
| FORMAT              | string  | Format du rapport (`sarif`, `table`, `json`, etc.)                                                                                                                                                                                      | Non    | `table`             |
| PR_NUMBER           | string  | Numéro de la PR si le workflow est déclenché par une pull request                                                                                                                                                                       | Non    | -                   |
| GITHUB_SECURITY_TAB | boolean | Lier l'onglet GitHub Security dans le commentaire de la PR                                                                                                                                                                              | Non    | `false`             |
| TRIVYIGNORES        | string  | Chemins vers des fichiers d'ignore Trivy, séparés par des virgules, relatifs à la racine du dépôt (ex: `.trivyignore.yaml`)                                                                                                             | Non    | -                   |
| CATEGORY            | string  | Catégorie de scanning pour l'upload SARIF (à fixer par cible quand plusieurs appels uploadent depuis le même dépôt, ex: une matrice d'images)                                                                                           | Non    | -                   |
| SEVERITY            | string  | Sévérités à rapporter, séparées par des virgules (ex: `CRITICAL,HIGH`)                                                                                                                                                                  | Non    | Toutes              |
| FAIL_ON_ERROR       | boolean | Faire échouer le workflow si des vulnérabilités sont détectées                                                                                                                                                                          | Non    | `false`             |
| TIMEOUT             | string  | Délai maximum du scan Trivy, au format durée Go (ex: `15m`)                                                                                                                                                                             | Non    | `5m` (défaut Trivy) |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                  | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                     | Requis |
| ----------------- | ----------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour se connecter au registre | Non    |
| REGISTRY_PASSWORD | Mot de passe pour se connecter au registre      | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App, utilisé uniquement pour relever le budget d'API que Trivy utilise pour télécharger sa base de vulnérabilités (de 1000 à 5000 requêtes/heure). Le token minté est en lecture seule. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                                                                                                                                    | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux.                                                                                                                                                          | Non    |

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
- **CATEGORY** compte dès qu'un dépôt uploade plus d'un rapport SARIF : les uploads partageant une catégorie se **remplacent mutuellement**, une matrice scannant plusieurs images sans ce champ ne laisse visible dans l'onglet Security que la dernière terminée.
- **FAIL_ON_ERROR** est à `false` par défaut, contrairement au même input ailleurs dans ce dépôt : ce workflow a toujours été informatif uniquement, passer le défaut à `true` ferait échouer tous les appelants existants sur des vulnérabilités antérieures à l'ajout de l'input. À activer explicitement pour gater.
- **SEVERITY** s'associe naturellement à `FAIL_ON_ERROR` : gater sur un périmètre restreint (`CRITICAL`) et rapporter sur un périmètre plus large depuis un run planifié.
- Avec `FAIL_ON_ERROR: true`, le rapport est toujours écrit dans le résumé du workflow avant que le job échoue - un exit code non nul signifie précisément qu'il y a quelque chose à lire.
- Avec `FORMAT: table`, le rapport va dans le résumé du workflow, plafonné par GitHub à **1 Mio** et supprimé *entièrement* plutôt que tronqué en cas de dépassement - un scan large d'une grosse image perdrait sinon tout son résumé. Le rapport est tronqué pour tenir dans la limite, avec une note, et le fichier complet est joint au run en tant qu'artefact `trivy-report-<cible>` (rétention 7 jours). Rien n'est uploadé quand le rapport tient dans la limite.
- **APP_CLIENT_ID/APP_PRIVATE_KEY ou GH_PAT** relèvent le budget d'API GitHub utilisé pour télécharger la base de vulnérabilités Trivy, utile sur des matrices de scan importantes qui épuisent la limite de 1000 requêtes/heure de `GITHUB_TOKEN`. Le token minté depuis l'App est toujours en lecture seule. Voir [`authentication.md`](./authentication.md).
- **TIMEOUT** vaut la peine d'être défini pour les grosses images : le défaut Trivy de 5 min est par scan (pas par fichier), et un seul gros binaire statiquement lié peut l'épuiser - le scan échoue alors avec un timeout de contexte et n'écrit **aucun rapport**, la cible semble alors non scannée silencieusement.
- Le scan couvre `os,library`, et `library` inclut des binaires que l'image n'a pas construits elle-même. Sur une image pleine de binaires tiers précompilés, `ignore-unfixed` filtre moins qu'il n'y paraît : une CVE de la stdlib Go compte comme corrigée dès que Go publie le correctif, même si le binaire vulnérable est un artefact tiers que seule une nouvelle release amont peut changer. Gater en conséquence, sous peine d'échouer sur des constats qu'aucun changement de votre dépôt ne peut résoudre.
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

### Gater une pull request sur les vulnérabilités critiques

`FAIL_ON_ERROR` transforme le scan en check bloquant. À combiner avec un `SEVERITY` restreint pour garder le gate actionnable - un seuil large sur une image volumineuse tend à faire échouer chaque PR sur des constats sans lien avec le changement.

```yaml
jobs:
  vuln-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    with:
      IMAGE: ghcr.io/my-org/my-image:pr-${{ github.event.pull_request.number }}
      FORMAT: table
      SEVERITY: CRITICAL
      FAIL_ON_ERROR: true
```

### Scanner plusieurs images sans écraser l'onglet Security

Chaque combinaison de matrice a besoin de sa propre `CATEGORY`, sinon chaque upload remplace le précédent.

```yaml
jobs:
  vuln-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    strategy:
      fail-fast: false
      matrix:
        image: [api, front]
    with:
      IMAGE: ghcr.io/my-org/${{ matrix.image }}:latest
      FORMAT: sarif
      SEVERITY: CRITICAL,HIGH
      GITHUB_SECURITY_TAB: true
      CATEGORY: trivy-${{ matrix.image }}
```
