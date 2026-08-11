# `release-helm-local.yml`

Package un chart Helm précis du **dépôt courant** à une version explicite (`helm package`) et le pousse sur un registre OCI (ex: `ghcr.io`). Aucune détection de changement basée sur les tags git, pas de GitHub Pages, pas de GitHub Release - uniquement le packaging et le push du commit pointé.

À utiliser à la place de [`release-helm.yml`](./release-helm.md) quand le chart est hébergé dans un **monorepo** aux côtés du code applicatif. Dans un monorepo, l'espace de tags git est dominé par les tags de l'**application** (ex: `v1.2.3`, et les tags mobiles `v1`/`v1.2` produits par `release-app` avec `TAG_MAJOR_AND_MINOR`). La base de comparaison "dernier tag" de `chart-releaser` pointe alors vers un commit applicatif récent, et il détecte fréquemment **aucun chart modifié, sans rien publier**. Ce workflow contourne totalement ce problème : la release est pilotée explicitement, sans aucune inspection des tags git.

## Pourquoi un workflow séparé

Cette logique faisait auparavant partie d'une branche `MODE: local` à l'intérieur de `release-helm.yml`, aux côtés du chemin de code `chart-releaser`. GitHub valide l'intégralité du graphe de jobs déclaré par un workflow réutilisable par rapport à ce que l'appelant accorde - y compris un job protégé par un `if:` sur `MODE` qui ne sera jamais vrai pour un appelant donné. Un appelant monorepo passant `MODE: local` devait quand même accorder `contents: write` (nécessaire uniquement au job `chart-releaser`, qui ne s'exécutait jamais pour lui), sous peine d'échec au démarrage :

```
Error calling workflow '.../release-helm.yml@v0'.
The nested job 'release' is requesting 'contents: write', but is only allowed 'contents: read'.
```

Séparer en deux fichiers signifie que chacun ne déclare que les permissions dont son propre job a besoin - ce workflow n'a besoin que de `contents: read`, un point c'est tout, car il ne crée jamais de tag git, de release ni de commit sur une branche pages.

## Inputs

| Input         | Type   | Description                                                                                                                                         | Requis | Défaut              |
| ------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------------------- |
| CHARTS_DIR    | string | Répertoire contenant les charts Helm                                                                                                               | Non    | `./charts`          |
| CHART_NAME    | string | Dossier du chart sous `CHARTS_DIR` à publier (ex: `my-app`). Laisser vide pour packager tous les charts trouvés directement sous `CHARTS_DIR`.     | Non    | -                   |
| CHART_VERSION | string | Version du chart à appliquer (`helm package --version`). Par défaut, utilise la version déjà présente dans `Chart.yaml`.                           | Non    | -                   |
| APP_VERSION   | string | Version applicative à appliquer (`helm package --app-version`). Par défaut, utilise l'`appVersion` déjà présente dans `Chart.yaml`.                | Non    | -                   |
| CHECKOUT_REF  | string | Ref git (branche ou SHA) à checkout avant le packaging, ex: l'output `commit-sha` de `update-helm-chart.yml` en mode local. Défaut : le commit qui a déclenché le workflow. | Non    | -                   |
| HELM_REPOS    | string | Dépôts Helm à ajouter pour résoudre les dépendances des charts (format: `name=url`, séparés par des virgules). Ignoré si vide.                     | Non    | -                   |
| REGISTRY      | string | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)                                                                        | Non    | `ghcr.io`           |
| REPOSITORY    | string | Chemin du repository dans le registre OCI (défaut: `github.repository`)                                                                            | Non    | `github.repository` |
| RUNS_ON       | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                             | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                                                       | Requis |
| ----------------- | ---------------------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre OCI (utilise `github.actor` automatiquement pour `ghcr.io`). **Requis** quand `REGISTRY` n'est pas `ghcr.io`. | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre OCI (utilise `GITHUB_TOKEN` automatiquement pour `ghcr.io`). **Requis** avec `REGISTRY_USERNAME` dans les mêmes conditions. | Non    |

Pas de credentials GitHub App/PAT - ce workflow ne crée jamais de tag git, de release ni de commit, donc rien n'a besoin d'un credential au-delà de l'authentification au registre.

## Permissions

| Scope    | Accès | Description                              |
| -------- | ----- | ----------------------------------------- |
| contents | read  | Checkout uniquement                       |
| packages | write | Pousser le chart vers le registre OCI (`ghcr.io`) |

## Notes

- N'inspecte pas l'historique git : package exactement ce qui est pointé, à la version présente dans `Chart.yaml` sauf si `CHART_VERSION`/`APP_VERSION` la remplacent. Cela rend les releases de charts déterministes dans un monorepo, sans nécessiter de commit sur `Chart.yaml`.
- **Gardez les cycles de vie du chart et de l'application séparés** : le chart a son propre flux de versions - il est bumpé quand l'application est publiée (avec un nouvel `appVersion`), mais peut aussi être publié seul (correctif de values/template, sans changement applicatif). Le cerveau de versioning pour cela est [`update-helm-chart.yml`](./update-helm-chart.md) en mode `local` : il calcule la prochaine version du chart (compatible release-please, gère les prereleases), commit le bump sur la branche, et expose `commit-sha` en output - à fournir à ce workflow via `CHECKOUT_REF` pour que le package publié corresponde exactement à l'état commité. Les inputs `CHART_VERSION`/`APP_VERSION` restent une échappatoire pour les configurations sans commit ; préférez le `Chart.yaml` commité comme source de vérité.
- **Pas de switch `PUBLISH_OCI`, contrairement à [`release-helm.yml`](./release-helm.md)** : le registre OCI est l'unique canal de distribution de ce workflow. Dans un monorepo, les GitHub Releases et les tags git appartiennent à l'*application*, le chart ne peut donc pas se les approprier pour ses propres packages - ce qui exclut le canal tgz-sur-release + `index.yaml` que chart-releaser propose dans un dépôt de charts dédié. Un input désactivant le push OCI ne laisserait plus rien à publier à ce workflow ; il n'existe donc pas.
- **Les credentials de registre sont validés en amont** : avec un `REGISTRY` autre que `ghcr.io`, l'absence de `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` fait échouer le run avec un message explicite, plutôt que d'atteindre `helm registry login` avec un mot de passe vide et d'échouer sur une erreur d'authentification opaque.
- **Les credentials sont effacés ensuite** : une étape `helm registry logout` s'exécute dès lors que le login a réussi, y compris après un push en échec. Les runners hébergés étant éphémères, c'est sans effet chez eux, mais `RUNS_ON` supporte aussi les runners self-hosted, où la config de registre de Helm survivrait au job.
- Les charts peuvent être récupérés via : `helm pull oci://ghcr.io/<owner>/<repo>/<chart-name> --version <version>`

## Exemples

### Chart dans un monorepo, publié aux côtés de l'application

Le chart est hébergé dans le même dépôt que l'application (ex: `charts/my-app`) et publié dans le même pipeline - mais sur **son propre flux de versions**. `update-helm-chart` (mode local) calcule et commit le bump du chart (en fixant `appVersion` à la version de l'application), puis ce workflow package ce commit précis et le pousse sur le registre OCI. Pas de `gh-pages`, pas de détection de changement chart-releaser, pas de PR de bump.

```yaml
on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write

  bump-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    needs:
    - release
    if: ${{ needs.release.outputs.release-created }}
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      # UPGRADE_TYPE par défaut ('auto') : le chart reflète le bump de
      # l'application, dérivé du delta d'appVersion.
      APP_VERSION: ${{ needs.release.outputs.version }}

  release-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm-local.yml@v0
    needs:
    - bump-chart
    permissions:
      contents: read
      packages: write
    with:
      CHARTS_DIR: ./charts
      CHART_NAME: my-app
      # Package exactement le commit de bump poussé par update-helm-chart
      CHECKOUT_REF: ${{ needs.bump-chart.outputs.commit-sha }}
```

> Le chart et l'application gardent délibérément des **versions séparées** : ici une release applicative `1.4.0` peut publier le chart `0.7.3` avec `appVersion: 1.4.0`. Un correctif du chart seul relance la même paire `bump-chart` + `release-chart` avec `APP_VERSION` omis. Les inputs `CHART_VERSION`/`APP_VERSION` de ce workflow restent disponibles comme échappatoire sans commit (stamping au moment du packaging), si vous acceptez que le `Chart.yaml` en git ne reflète pas les versions publiées.

### Registre OCI personnalisé

```yaml
jobs:
  release-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm-local.yml@v0
    permissions:
      contents: read
      packages: write
    with:
      CHARTS_DIR: ./charts
      CHART_NAME: my-app
      REGISTRY: registry.example.com
      REPOSITORY: my-org/helm-charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```
