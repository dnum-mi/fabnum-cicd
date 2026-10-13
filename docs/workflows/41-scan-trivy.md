# `scan-trivy.yml`

Analyse de vulnérabilités avec [Trivy](https://github.com/aquasecurity/trivy) pour les images Docker et les fichiers de configuration, avec upload des rapports SARIF vers GitHub Security.

## Inputs

| Input               | Type    | Description                                                                                                                                                                                                                                                                                                            | Requis | Défaut              |
| ------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| IMAGE               | string  | Image utilisée pour effectuer le scan (ex: `docker.io/debian:latest`)                                                                                                                                                                                                                                                  | Non    | -                   |
| IMAGE_ARTIFACT      | string  | Nom d'un artefact de workflow contenant un tarball d'image à scanner localement, au lieu de pull `IMAGE` depuis un registre (ex: produit par `build-docker.yml` avec `PUSH: false`). Prend le pas sur `IMAGE` si les deux sont fournis.                                                                                | Non    | -                   |
| IMAGE_ARTIFACT_FILE | string  | Nom du fichier tarball dans `IMAGE_ARTIFACT`                                                                                                                                                                                                                                                                           | Non    | `image.tar`         |
| PATH                | string  | Chemin utilisé pour effectuer le scan de configuration                                                                                                                                                                                                                                                                 | Non    | -                   |
| FORMAT              | string  | Format du rapport (`sarif`, `table`, `json`, etc.)                                                                                                                                                                                                                                                                     | Non    | `table`             |
| PR_NUMBER           | string  | Numéro de la PR sur laquelle poster le commentaire de synthèse du scan                                                                                                                                                                                                                                                 | Non    | -                   |
| GITHUB_SECURITY_TAB | boolean | Lier l'onglet GitHub Security dans le commentaire de la PR                                                                                                                                                                                                                                                             | Non    | `false`             |
| CATEGORY            | string  | Catégorie de scanning pour l'upload SARIF (à fixer par cible quand plusieurs appels uploadent depuis le même dépôt, ex: une matrice d'images)                                                                                                                                                                          | Non    | -                   |
| SEVERITY            | string  | Sévérités à rapporter, séparées par des virgules (ex: `CRITICAL,HIGH`)                                                                                                                                                                                                                                                 | Non    | Toutes              |
| FAIL_ON_ERROR       | boolean | Faire échouer le workflow si des vulnérabilités sont détectées                                                                                                                                                                                                                                                         | Non    | `false`             |
| TIMEOUT             | string  | Délai maximum du scan Trivy, au format durée Go (ex: `15m`)                                                                                                                                                                                                                                                            | Non    | `5m` (défaut Trivy) |
| TRIVYIGNORES        | string  | Chemins vers des fichiers d'ignore Trivy, séparés par des virgules, relatifs à la racine du dépôt (ex: `.trivyignore.yaml`). Trivy détecte automatiquement un `.trivyignore` simple ; la forme YAML - la seule qui supporte une portée par chemin et une raison documentée par entrée - doit être nommée explicitement | Non    | -                   |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `'["ubuntu-24.04"]'` ou `'["self-hosted", "linux"]'`)                                                                                                                                                                                                                           | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                                                                                                                                                                                           | Requis |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour se connecter au registre (inutile pour `ghcr.io`)                                                                                                                                              | Non    |
| REGISTRY_PASSWORD | Mot de passe pour se connecter au registre (inutile pour `ghcr.io`)                                                                                                                                                   | Non    |
| APP_CLIENT_ID     | **Client ID** d'une GitHub App (pas l'App ID numérique). Avec `APP_PRIVATE_KEY`, relève le budget d'API utilisé par Trivy pour télécharger sa base de vulnérabilités. Voir [Authentification](./05-authentication.md) | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`                                                                                                                                                        | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux. Un accès en lecture seule suffit                                                                             | Non    |

> **Pourquoi fournir un credential ici.** Trivy télécharge sa base de vulnérabilités via l'API GitHub, limitée à 1 000 requêtes/heure par dépôt avec `GITHUB_TOKEN`. Un token d'App ou un `GH_PAT` relève cette limite à 5 000 - utile si les scans échouent par intermittence au téléchargement de la base. Dans tous les cas, un accès en lecture seule suffit ; rien dans le scan ne nécessite d'écriture, et le token d'App est minté avec `contents: read` + `metadata: read`.
>
> `APP_CLIENT_ID` et `APP_PRIVATE_KEY` doivent être fournis **ensemble**. En fournir un seul fait échouer le job au lieu de se rabattre sur `GH_PAT` ou `GITHUB_TOKEN`.

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
- `FORMAT` contrôle le format de sortie : `table` (défaut) affiche les résultats dans le résumé du workflow, `sarif` active l'intégration avec l'onglet GitHub Security.
- Avec `GITHUB_SECURITY_TAB: true` et `FORMAT: sarif`, les résultats sont uploadés vers l'onglet Security.
- Les commentaires de PR pointent vers l'onglet GitHub Security (si `GITHUB_SECURITY_TAB: true`) ou vers la page de résumé du workflow.
- Le lien vers l'onglet Security dans le commentaire de PR est filtré sur la ref contre laquelle le SARIF a réellement été uploadé : `pr:<numéro>` pour un run `pull_request`, `branch:<nom>` pour un push, et aucun filtre de ref pour tout le reste (un tag). Code scanning n'indexe les alertes que sous cette ref : un appelant qui scanne sur `push` et passe `PR_NUMBER` à la main obtient donc quand même un lien qui aboutit, alors qu'un filtre `pr:` figé tomberait sur un onglet vide.
- Authentification au registre : utilise le token GitHub pour `ghcr.io`, sinon les credentials fournis.
- Ignore les vulnérabilités non corrigées par défaut (`ignore-unfixed: true`).
- Ignore les répertoires courants via `skip-dirs: **/node_modules` dans le scan de configuration.
- **CATEGORY** compte dès qu'un dépôt uploade plus d'un rapport SARIF : les uploads partageant une catégorie se **remplacent mutuellement**, une matrice scannant plusieurs images sans ce champ ne laisse visible dans l'onglet Security que la dernière terminée.
- **FAIL_ON_ERROR** est à `false` par défaut, contrairement au même input ailleurs dans ce dépôt : ce workflow a toujours été informatif uniquement, passer le défaut à `true` ferait échouer tous les appelants existants sur des vulnérabilités antérieures à l'ajout de l'input. À activer explicitement pour gater.
- **SEVERITY** s'associe naturellement à `FAIL_ON_ERROR` : gater sur un périmètre restreint (`CRITICAL`) et rapporter sur un périmètre plus large depuis un run planifié.
- Avec `FAIL_ON_ERROR: true`, le rapport est toujours écrit dans le résumé du workflow avant que le job échoue - un exit code non nul signifie précisément qu'il y a quelque chose à lire.
- Avec `FORMAT: table`, le rapport va dans le résumé du workflow, plafonné par GitHub à **1 Mio** et supprimé *entièrement* plutôt que tronqué en cas de dépassement - un scan large d'une grosse image perdrait sinon tout son résumé. Le rapport est tronqué pour tenir dans la limite, avec une note, et le fichier complet est joint au run en tant qu'artefact `trivy-report-<cible>` (rétention 7 jours). Rien n'est uploadé quand le rapport tient dans la limite.
- **TIMEOUT** vaut la peine d'être défini pour les grosses images : le défaut Trivy de 5 min est par scan (pas par fichier), et un seul gros binaire statiquement lié peut l'épuiser - le scan s'interrompt alors avec `semaphore acquire: context deadline exceeded` et n'écrit **aucun rapport**, la cible reste donc silencieusement non scannée alors que les images plus rapides de la même matrice semblent saines.
- Le scan couvre `os,library`, et `library` inclut des binaires que l'image n'a pas construits elle-même. Sur une image pleine de binaires tiers précompilés, `ignore-unfixed` filtre moins qu'il n'y paraît : une CVE de la stdlib Go compte comme corrigée dès que Go publie le correctif, même si le binaire vulnérable est un artefact tiers que seule une nouvelle release amont peut changer. Gater en conséquence, sous peine d'échouer sur des constats qu'aucun changement de votre dépôt ne peut résoudre.

## Exemples

Les exemples illustrent les deux principaux modes de sortie : un scan rapide au format table pour un retour direct, et l'intégration GitHub Security Advisory pour alimenter l'onglet Security du dépôt.

### Scan simple avec sortie table

Lance en parallèle un scan d'image et un scan de configuration d'un chemin. Les résultats sont affichés sous forme de table dans le résumé du workflow. Quand `PR_NUMBER` est défini, un commentaire de PR est posté avec un lien vers la page de résumé.

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
      IMAGE: ghcr.io/my-org/my-image:1.2.3
      PATH: ./apps/api
      FORMAT: table
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Scan avec intégration à l'onglet GitHub Security

`FORMAT: sarif` produit un rapport SARIF uploadé vers l'onglet Security → Code scanning du dépôt quand `GITHUB_SECURITY_TAB: true`. Les constats sont dédupliqués et suivis d'un run à l'autre ; le commentaire de PR pointe vers l'onglet Security au lieu du résumé du workflow.

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
      IMAGE: ghcr.io/my-org/my-image:1.2.3
      PATH: ./apps/api
      FORMAT: sarif
      GITHUB_SECURITY_TAB: true
      PR_NUMBER: ${{ github.event.pull_request.number }}
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
      IMAGE_TAG: pr-${{ github.event.pull_request.number }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      PUSH: false
      BUILD_ARM64: false

  vuln-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    needs:
    - build
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    with:
      IMAGE_ARTIFACT: ${{ needs.build.outputs.artifact-prefix }}-amd64
      PATH: ./
      FORMAT: table
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Registre personnalisé (hors GHCR)

Pour les images hébergées en dehors de `ghcr.io`, fournir des credentials explicites via les secrets :

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
      IMAGE: registry.example.com/my-org/my-image:1.2.3
      FORMAT: table
      PR_NUMBER: ${{ github.event.pull_request.number }}
    secrets:
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
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
        image: [api, web, worker]
    with:
      IMAGE: ghcr.io/my-org/${{ matrix.image }}:latest
      FORMAT: sarif
      SEVERITY: CRITICAL,HIGH
      GITHUB_SECURITY_TAB: true
      CATEGORY: trivy-${{ matrix.image }}
```
