# `release-helm.yml`

Publication des charts Helm via `chart-releaser`, qui détecte automatiquement les charts dont la version a changé depuis le dernier tag git et les package. Deux **canaux de distribution indépendants** peuvent ensuite être activés - voir [Canaux de distribution](#canaux-de-distribution) :

- `PUBLISH_OCI: true` - pousser les packages sur un registre OCI (ex: `ghcr.io`).
- `CREATE_GITHUB_RELEASE: true` - les attacher à une GitHub Release par chart et maintenir un dépôt Helm classique (`index.yaml`) sur une branche de pages.

Les deux valent `false` par défaut et **au moins un doit être activé**, sinon le run échoue. Adapté à un **dépôt de charts dédié**, où les tags git du dépôt appartiennent aux charts.

Pour un **monorepo** - un chart hébergé aux côtés du code applicatif, où l'espace de tags est dominé par les tags de l'application et où la détection de changement de chart-releaser (basée sur les tags) devient peu fiable - utilisez [`release-helm-local.yml`](./release-helm-local.md) à la place. Les deux sont des workflows séparés plutôt qu'un seul avec un switch de mode : chacun ne déclare que les permissions dont sa propre logique a besoin, pour qu'un appelant monorepo n'ait jamais à accorder `contents: write` pour un chemin de code chart-releaser qu'il n'exécutera jamais. Voir [`release-helm-local.yml`](./release-helm-local.md#pourquoi-un-workflow-séparé) pour le raisonnement complet.

## Inputs

| Input                 | Type    | Description                                                                                                                                                                                                                                                                                                              | Requis | Défaut              |
| --------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| CHARTS_DIR            | string  | Répertoire contenant les charts Helm                                                                                                                                                                                                                                                                                     | Non    | `./charts`          |
| PUBLISH_OCI           | boolean | Pousser les charts packagés sur le registre OCI (voir `REGISTRY`/`REPOSITORY`). Indépendant de `CREATE_GITHUB_RELEASE` ; au moins un des deux doit être activé.                                                                                                                                                       | Non    | `false`             |
| CREATE_GITHUB_RELEASE | boolean | Créer en plus une GitHub Release et un tag git pour chaque chart modifié, et mettre à jour `index.yaml` sur la branche `PAGES_BRANCH`. Nécessite que cette branche existe déjà.                                                                                                                                       | Non    | `false`             |
| PAGES_BRANCH          | string  | Branche recevant `index.yaml` et les artefacts de release quand `CREATE_GITHUB_RELEASE` est `true`. Doit déjà exister.                                                                                                                                                                                                  | Non    | `gh-pages`          |
| HELM_REPOS            | string  | Dépôts Helm à ajouter (format: `name=url`, séparés par des virgules)                                                                                                                                                                                                                                                     | Non    | -                   |
| REGISTRY              | string  | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)                                                                                                                                                                                                                                                                                                              | Non    | `ghcr.io`           |
| REPOSITORY            | string  | Chemin du repository dans le registre OCI (défaut: `github.repository`)                                                                                                                                                                                                                                                                                                                  | Non    | `github.repository` |
| RUNS_ON               | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                                                                                                                   | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                               | Requis |
| ----------------- | --------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre OCI (`github.actor` automatiquement pour `ghcr.io`). **Requis** avec `PUBLISH_OCI: true` quand `REGISTRY` n'est pas `ghcr.io`. | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre OCI (`GITHUB_TOKEN` automatiquement pour `ghcr.io`). **Requis** avec `REGISTRY_USERNAME` dans les mêmes conditions. | Non    |
| APP_CLIENT_ID     | Client ID d'une GitHub App. À fournir avec `APP_PRIVATE_KEY` pour que chart-releaser authentifie comme une App - contrairement à `GITHUB_TOKEN`, les releases créées peuvent alors déclencher des triggers `release:`. Voir [`authentication.md`](./authentication.md). | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                        | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux. Comme un token App, il peut déclencher des workflows - la même précaution s'applique au push sur `PAGES_BRANCH`. | Non    |

## Permissions

| Scope    | Accès | Description                                                                          |
| -------- | ----- | ------------------------------------------------------------------------------------ |
| contents | write | Créer des releases GitHub (mode `chart-releaser` avec `CREATE_GITHUB_RELEASE: true`) |
| packages | write | Pousser les charts vers le registre OCI quand `PUBLISH_OCI` est `true`               |

> **À propos de la permission inutilisée.** Le workflow déclare les deux scopes sur son job, et la clé `permissions:` de GitHub Actions n'accepte aucune expression - `packages: write` est donc accordé même avec `PUBLISH_OCI: false`, où rien ne l'utilise. La restreindre imposerait de séparer les deux canaux dans deux fichiers de workflow, doublant leur nombre pour retirer un scope qu'aucune étape n'appelle dans cette configuration.

## Canaux de distribution

Le workflow package les charts une fois et peut les diffuser par deux canaux, activables indépendamment :

| | `PUBLISH_OCI: true` | `CREATE_GITHUB_RELEASE: true` |
| --- | --- | --- |
| Côté consommateur | `helm pull oci://<registre>/<repo>/<chart>` | `helm repo add <nom> https://<owner>.github.io/<repo>` |
| Nécessite | Helm 3.8+ | n'importe quel Helm 3 |
| Prérequis dépôt | aucun | la `PAGES_BRANCH` (défaut `gh-pages`) doit déjà exister |
| Charts privés | authentification au registre | les assets de release suivent la visibilité du dépôt |
| Permission utilisée | `packages: write` | `contents: write` |
| [Releases immuables](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) | compatible (ne crée aucune release GitHub) | **incompatible** - voir l'avertissement plus bas |

Activer les deux est possible et publie les mêmes packages par les deux chemins.

**Les deux laissés à `false` font échouer le run.** Le workflow packagerait sinon les charts, ne les publierait nulle part, et signalerait malgré tout un succès - un run vert n'ayant rien livré est plus difficile à repérer qu'un run rouge, donc l'étape de validation l'arrête d'emblée avec un message nommant les deux inputs.

## Notes

- Utilise chart-releaser-action pour automatiser le packaging et la publication des charts modifiés. `CREATE_GITHUB_RELEASE: true` crée en plus une GitHub Release, un tag git et met à jour `index.yaml` sur `PAGES_BRANCH`.
- **Comportement de `PUBLISH_OCI`** : à `true`, se connecte à `REGISTRY` et pousse chaque chart packagé. À `false`, l'étape de login est entièrement ignorée : aucun credential de registre n'est lu ni nécessaire.
- **Les credentials de registre sont validés en amont** : avec `PUBLISH_OCI: true` et un `REGISTRY` autre que `ghcr.io`, l'absence de `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` fait échouer le run avec un message explicite, plutôt que d'atteindre `helm registry login` avec un mot de passe vide et d'échouer sur une erreur d'authentification opaque.
- **Les credentials sont effacés ensuite** : une étape `helm registry logout` s'exécute dès lors que le login a réussi, y compris après un push en échec. Les runners hébergés étant éphémères, c'est sans effet chez eux, mais `RUNS_ON` supporte aussi les runners self-hosted, où la config de registre de Helm survivrait au job.
- Publie vers GitHub Container Registry (ghcr.io) par défaut, mais supporte n'importe quel registre OCI.
- **Normalisation du nom de repository** : Le chemin du repository OCI est automatiquement normalisé pour être compatible avec les registres OCI :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `My-Org/My_Charts` → `my-org/my-charts`
- Pour ghcr.io, utilise automatiquement les credentials GitHub (pas besoin de fournir REGISTRY_USERNAME/PASSWORD).
- Pour les autres registres, fournissez `REGISTRY_USERNAME` et `REGISTRY_PASSWORD` en tant que secrets.
- Configure Git avec le bot GitHub Actions pour les commits automatiques.
- **`CREATE_GITHUB_RELEASE: true`** : fournir `APP_CLIENT_ID`/`APP_PRIVATE_KEY` (ou `GH_PAT`) permet aux releases GitHub créées de déclencher des triggers `release:`, ce que `GITHUB_TOKEN` ne peut jamais faire. Le push sur `PAGES_BRANCH` utilise le même token, donc le même credential peut aussi déclencher des workflows sur cette branche - à vérifier avant d'activer. Voir [`authentication.md`](./authentication.md).

> [!WARNING]
> **`CREATE_GITHUB_RELEASE: true` n'est pas compatible avec les [*immutable releases*](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).** `chart-releaser` crée la release GitHub puis attache le `.tgz` du chart en deux appels API distincts, sans possibilité de passer par un brouillon ; sur un dépôt en releases immuables le second appel est rejeté et la release reste incomplète. Le support côté amont est suivi dans [helm/chart-releaser#591](https://github.com/helm/chart-releaser/issues/591).
>
> Le canal OCI seul (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`) ne crée aucune release GitHub et n'est donc pas concerné - c'est le canal à utiliser sur un dépôt en releases immuables.

## Exemples

### Registre OCI (GitHub Container Registry)

```yaml
name: Release Charts

on:
  push:
    branches:
    - main

jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
```

### Avec dépôts Helm personnalisés

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      CHARTS_DIR: ./charts
      HELM_REPOS: "bitnami=https://charts.bitnami.com/bitnami,stable=https://charts.helm.sh/stable"
```

### Dépôt Helm classique uniquement (sans OCI)

Crée une GitHub Release et un tag git par chart et maintient un `index.yaml` sur la branche de pages, sans rien pousser sur un registre OCI. Les consommateurs utilisent `helm repo add`. La `PAGES_BRANCH` (défaut `gh-pages`) **doit déjà exister**.

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      CREATE_GITHUB_RELEASE: true
      PAGES_BRANCH: gh-pages
```

### Chart dans un monorepo applicatif

Pour un chart hébergé aux côtés du code applicatif, voir [`release-helm-local.yml`](./release-helm-local.md) à la place - un workflow séparé, à permissions minimales, dédié à ce cas.

### Avec GitLab Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      REGISTRY: registry.gitlab.com
      REPOSITORY: my-group/my-project
    secrets:
      REGISTRY_USERNAME: ${{ secrets.GITLAB_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.GITLAB_TOKEN }}
```

### Avec Docker Hub

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      REGISTRY: registry-1.docker.io
      REPOSITORY: my-org/charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```

### Avec Azure Container Registry

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      REGISTRY: myregistry.azurecr.io
      REPOSITORY: helm-charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.AZURE_CLIENT_ID }}
      REGISTRY_PASSWORD: ${{ secrets.AZURE_CLIENT_SECRET }}
```

### Avec un répertoire de charts personnalisé

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      CHARTS_DIR: ./helm-charts
```
