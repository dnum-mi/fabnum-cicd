# Authentification

Certains workflows ont besoin d'un credential GitHub au-delà de celui fourni automatiquement. Trois modes sont supportés, et ils peuvent coexister.

## Quel mode choisir ?

Partir du haut du tableau et s'arrêter à la première ligne qui correspond.

| Si vous...                                                                                 | Utilisez                          | Secrets à définir                  |
| ------------------------------------------------------------------------------------------ | --------------------------------- | ---------------------------------- |
| build/test/scan/push vers GHCR uniquement                                                  | **`GITHUB_TOKEN`** — automatique  | aucun                              |
| avez besoin que les PRs de release/chart déclenchent la CI                                 | **GitHub App** (ou `GH_PAT`)      | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| avez besoin de l'automerge                                                                 | **GitHub App** (ou `GH_PAT`)      | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| devez déclencher un workflow dans un **autre** dépôt (`dispatch-helm-chart`)               | **GitHub App** (ou `GH_PAT`)      | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| avez besoin que les releases de chart déclenchent des triggers `release:` (`release-helm`) | **GitHub App** (ou `GH_PAT`)      | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| avez des rulesets de branche qui rejettent le push de `GITHUB_TOKEN` (`sync-prerelease-branch`) | **GitHub App**               | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| atteignez les limites de l'API GitHub pendant les scans Trivy                              | **GitHub App** (ou `GH_PAT`)      | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| atteignez les limites de l'API GitHub **dans un build Docker**                             | **GitHub App** (ou `GH_PAT`)      | les deux ci-dessus, **plus** [`BUILD_SECRET_GITHUB_TOKEN`](#ce-que-build-docker-injecte-réellement) |
| avez déjà un `GH_PAT` fonctionnel et ne voulez rien changer                                | **`GH_PAT`** — toujours supporté  | `GH_PAT`                           |

Les lignes marquées *(ou `GH_PAT`)* fonctionnent avec l'un ou l'autre credential — définir `GH_PAT` au lieu des deux secrets `APP_*`. La GitHub App est recommandée car elle est scopée par job, expire au bout d'une heure et n'est pas liée à une personne ; voir [Compromis face à une GitHub App](#compromis-face-à-une-github-app).

**Les trois modes sont acceptés par tous les workflows qui prennent un credential**, avec normalement l'ordre de résolution suivant :

```
Token App  →  GH_PAT  →  GITHUB_TOKEN
```

Chaque étape n'est utilisée que si la précédente est absente : ajouter un credential ne retire jamais une capacité, en retirer un ne casse jamais plus que ce qu'il apportait. Si App et PAT sont configurés en même temps, **l'App l'emporte** — ce qui permet de vérifier une migration avant de supprimer le PAT.

Ne fournir qu'un seul des deux secrets `APP_CLIENT_ID` / `APP_PRIVATE_KEY` n'est jamais valide et **fait échouer le job** plutôt que de retomber silencieusement sur un mode moins privilégié ; voir [Les deux secrets App, ou aucun](#les-deux-secrets-app-ou-aucun).

`sync-prerelease-branch.yml` est la seule exception aux trois modes : il n'accepte que la paire App, et utilise `GITHUB_TOKEN` sinon (voir [sa page](./57-sync-prerelease-branch.md#quand-les-rulesets-rejettent-github_token)).

### Où la chaîne s'arrête plus tôt

Trois cas ne vont pas jusqu'au bout de cette chaîne, chacun échouant avec un message explicite plutôt que de faire silencieusement moins que demandé :

| Cas                                               | S'arrête à            | Pourquoi                                                           |
| ------------------------------------------------- | --------------------- | ------------------------------------------------------------------ |
| Automerge (`release-app`, `update-helm-chart`)    | Token App ou `GH_PAT` | `GITHUB_TOKEN` ne peut pas fusionner une pull request              |
| Dispatch cross-repository (`dispatch-helm-chart`) | Token App ou `GH_PAT` | `GITHUB_TOKEN` est scopé à son propre dépôt                        |
| Build secret de `build-docker`                    | ce que vous demandez  | La valeur est lisible par tout ce que le Dockerfile exécute, donc le credential est nommé explicitement plutôt que de retomber silencieusement sur un autre — voir [Ce que `build-docker` injecte réellement](#ce-que-build-docker-injecte-réellement) |

## Pourquoi le mode App existe

`GITHUB_TOKEN` est volontairement empêché de déclencher d'autres workflows, pour éviter les boucles d'automatisation. L'effet de bord est qu'une pull request ouverte avec `GITHUB_TOKEN` **ne déclenche jamais les workflows `pull_request`** — les PRs de release sont fusionnées sans qu'aucun check n'ait tourné.

Un token d'installation GitHub App n'est pas soumis à cette règle : les pull requests automatisées se comportent comme des pull requests humaines. Il dispose aussi de plus de marge sur les limites d'API : 5000 requêtes/heure contre 1000/heure par dépôt pour `GITHUB_TOKEN`.

## Mode 1 : `GITHUB_TOKEN`

**Créer :** rien. **Stocker :** rien. **Passer :** rien. Chaque job en reçoit un automatiquement ; seul le bloc `permissions:` est à configurer.

Un pipeline complet qui n'a besoin d'aucun secret :

```yaml
name: CI

on:
  pull_request:
    branches:
    - main

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

  scan:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
      packages: read
    with:
      IMAGE: ghcr.io/my-org/my-app:pr-${{ github.event.pull_request.number }}
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

Ce que vous perdez en restant sur ce mode :

| Limite                                | Conséquence                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------------ |
| Ne peut pas déclencher de workflows   | Les PRs de release/chart s'ouvrent **sans aucun check**                              |
| 1000 requêtes/heure par dépôt         | Les grosses matrices de build échouent en cours de route (`403 rate limit exceeded`) |
| Ne peut pas fusionner de pull request | `AUTOMERGE_*: true` fait échouer le job                                              |

Si rien de tout ça ne vous concerne, restez sur ce mode — c'est celui à privilégier.

## Mode 2 : GitHub App

Tout ce qui suit est une configuration à faire une seule fois. Elle fonctionne de la même façon avec un compte personnel et avec une organisation.

### Étape 1 : Créer l'App

**Settings → Developer settings → GitHub Apps → New GitHub App.**

| Champ                                      | Valeur                                                                                       |
| ------------------------------------------ | -------------------------------------------------------------------------------------------- |
| **GitHub App name**                        | N'importe quel nom unique — il devient l'auteur des PRs (ex: `my-org-ci` → `my-org-ci[bot]`) |
| **Homepage URL**                           | N'importe quelle URL valide, non utilisée ; l'URL de votre dépôt convient                    |
| **Webhook → Active**                       | **Décocher.** Ces workflows ne reçoivent pas de webhooks                                     |
| **Where can this GitHub App be installed** | *Only on this account*                                                                       |

**Une seule App suffit.** Lui accorder l'union de ce dont les workflows ont besoin :

| Permission    | Accès          | Nécessaire pour                       |
| ------------- | -------------- | ------------------------------------- |
| Metadata      | Read-only      | Obligatoire pour toute App            |
| Contents      | Read and write | Commits, tags, releases               |
| Pull requests | Read and write | Ouvrir et fusionner des pull requests |
| Issues        | Read and write | Labels release-please                 |
| Actions       | Read and write | `dispatch-helm-chart` uniquement      |

Chaque workflow mint ensuite son propre token, réduit à ce dont ce job a besoin :

| Workflow                     | Token réduit à                                | Portée                    |
| ---------------------------- | --------------------------------------------- | ------------------------- |
| `release-app.yml`            | `contents`, `pull-requests`, `issues` = write | dépôt courant             |
| `update-helm-chart.yml`      | `contents`, `pull-requests` = write           | dépôt courant             |
| `sync-prerelease-branch.yml` | `contents: write`                             | dépôt courant             |
| `dispatch-helm-chart.yml`    | `actions: write`                              | dépôt du chart uniquement |
| `release-helm.yml`           | `contents: write`                             | dépôt courant             |
| `build-docker.yml`           | `contents`, `metadata` = read                 | dépôt courant             |
| `scan-trivy.yml`             | `contents`, `metadata` = read                 | dépôt courant             |

Une App, une clé privée, plusieurs tokens réduits différemment.

> **La réduction de scope est essentielle.** Un token minté sans valeur `permission-*` hérite de **toutes les permissions de l'installation**. C'est pourquoi `build-docker.yml` demande toujours explicitement `contents: read` : son token est monté dans le build Docker, où tout script d'installation, hook postinstall ou binaire précompilé exécuté par le Dockerfile peut le lire. Si vous ajoutez une étape de mint, réduisez-la.

#### Comment la portée sur les dépôts est déterminée

Les permissions définissent *ce que* peut faire un token. `owner` et `repositories` définissent *où*. `actions/create-github-app-token` les résout ainsi :

| `owner`    | `repositories` | Portée obtenue                                        |
| ---------- | -------------- | ----------------------------------------------------- |
| non défini | non défini     | **Le dépôt courant uniquement**                       |
| défini     | non défini     | **Tous les dépôts de l'installation de cet owner** ⚠️ |
| défini     | défini         | Exactement les dépôts listés                          |

> [!CAUTION]
> **Définir `owner` sans `repositories` élargit le token à toute l'installation** — avec toutes les permissions de l'installation, pas celles du job courant. C'est la seule ligne qui transforme un token mono-dépôt en token à l'échelle de l'organisation, et elle a l'air inoffensive.

Chaque mint sur le même dépôt dans ces workflows laisse donc **les deux non définis**. Seul `dispatch-helm-chart.yml` les définit, car il cible réellement un autre dépôt, et il les définit **ensemble**.

Cela peut ressembler à un pari sur une valeur par défaut là où être explicite serait plus sûr. C'est délibéré, car les modes de défaillance ne sont pas symétriques :

- **Laisser les deux non définis :** pour élargir, quelqu'un doit *ajouter* une ligne. Un ajout est visible en review et ne peut pas arriver par accident.
- **Définir les deux explicitement :** pour élargir, il suffit de *supprimer* ou de vider une ligne. Un mauvais merge, un refactoring ou une expression qui s'évalue à vide produit silencieusement un token valable sur toute l'installation — sans erreur ni avertissement.

Une suppression accidentelle est bien plus probable qu'un ajout accidentel : la forme non définie est donc celle qui échoue en sécurité. Il n'existe de plus aucune écriture propre : les expressions Actions n'ont pas de `split()`, et `github.repository` vaut `owner/repo`, donc restreindre `repositories` au dépôt courant revient soit à `github.event.repository.name` (qui dépend du payload de l'événement déclencheur), soit à une étape `run` supplémentaire par job — une vraie complexité pour une valeur que l'action déduit déjà correctement.

**Si vous ajoutez une étape de mint, copiez-en une existante.** Définir `permission-*` pour ce dont le job a besoin, et ne pas toucher à `owner`/`repositories` sauf si vous traversez délibérément vers un autre dépôt — auquel cas définir les deux.

<details>
<summary>Durcissement optionnel : une App de build séparée</summary>

La réduction par mint borne ce qu'un *token* fuité peut faire. Elle ne borne pas ce qu'une *clé privée* fuitée peut faire — une clé mint n'importe quelle permission détenue par l'installation.

La clé n'est jamais exposée au build Docker (seul le token minté l'est) : il s'agit donc d'une défense en profondeur plutôt que du correctif d'une faille précise. Pour cette marge supplémentaire, créer une seconde App avec uniquement **Metadata: read** et **Contents: read**, l'installer sur les dépôts qui construisent des images, et passer ses credentials à `build-docker.yml`. Une clé fuitée à cet endroit ne mint rien d'autre que des lectures.

Exemple complet : [Deux Apps : isoler le credential de build](#deux-apps--isoler-le-credential-de-build).

</details>

### Étape 2 : Générer une clé privée

En bas des réglages de l'App, **Generate a private key**. Un fichier `.pem` est téléchargé — il ne peut plus être récupéré ensuite. Quiconque le détient peut minter des tokens pour tous les dépôts sur lesquels l'App est installée, avec toutes les permissions de l'installation.

### Étape 3 : Installer l'App

**Install App → Only select repositories →** choisir les dépôts qui exécutent ces workflows. Installer aussi restrictivement que possible : c'est la liste d'installation, pas la réduction par mint, qui borne une clé privée fuitée.

### Étape 4 : Stocker les secrets

Par dépôt : **Settings → Secrets and variables → Actions → New repository secret.**

| Nom               | Valeur                                                        |
| ----------------- | ------------------------------------------------------------- |
| `APP_CLIENT_ID`   | le **Client ID** de l'App (ressemble à `Iv23li…`)             |
| `APP_PRIVATE_KEY` | le `.pem` complet, avec les lignes `-----BEGIN…`/`-----END…`  |

> Le **Client ID**, pas l'App ID numérique. Les deux apparaissent sur la page de réglages de l'App et seul l'un des deux fonctionne. Utiliser l'App ID est l'erreur de configuration la plus courante — voir [Dépannage](#dépannage).

Les deux mêmes secrets servent à tous les workflows.

### Étape 5 : Câbler les secrets

Un pipeline de release complet. Chaque job qui accepte les credentials App reçoit les deux mêmes secrets ; chacun mint en interne son propre token réduit.

```yaml
name: CD

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
    with:
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
      AUTOMERGE_METHOD: auto
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  build:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      # Relève le budget d'API pour mise/aqua/ubi dans le build. Mint un token
      # séparé et en lecture seule ; voir l'avertissement à l'étape 1. 'app'
      # échoue plutôt que de retomber sur un credential qu'il ne peut pas
      # réduire.
      BUILD_SECRET_GITHUB_TOKEN: app
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  bump-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: patch
      AUTOMERGE_RELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  release-chart:
    needs:
    - release
    - bump-chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      # Canal classique laissé par défaut : c'est lui qui crée les GitHub
      # Releases, donc le seul pour lequel les credentials ci-dessous servent à
      # quelque chose (sous GITHUB_TOKEN ils ne déclencheraient aucun trigger
      # `release:`).
      CHARTS_DIR: ./charts
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

`scan-trivy.yml` accepte les deux mêmes secrets et les utilise uniquement pour relever le budget de téléchargement de la base Trivy — les ajouter tels quels à l'exemple de CI du mode 1.

### Étape 6 : Vérifier

Pousser un commit qui produit une release. Trois choses doivent visiblement changer :

1. La PR de release est ouverte par `votre-app[bot]`, pas `github-actions[bot]`.
2. Elle **a des checks** — la CI qui ne tournait jamais sur les PRs de release tourne désormais.
3. Le log de chaque job affiche une étape *Generate GitHub App token* exécutée plutôt qu'ignorée. Si elle a été ignorée, les secrets ne sont pas arrivés jusqu'au workflow.

> **Attendez-vous à ce que la première release fasse remonter des échecs.** Des checks qui ne tournaient jamais tournent désormais, et certains peuvent être cassés depuis un moment. C'est la fonctionnalité qui joue son rôle, pas un signe que la configuration est mauvaise.

## Mode 3 : Personal access token

Accepté par tous les workflows qui prennent un credential, aux mêmes endroits qu'un token App et résolu juste après lui. À privilégier si un PAT fonctionne déjà, ou si créer une App n'en vaut pas la peine.

### Étape 1 : Créer le token

**Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.** Scoper à *Only select repositories* et accorder uniquement les lignes qui correspondent à ce qui est réellement utilisé :

| Permission    | Accès          | Nécessaire pour                                                                                                                       |
| ------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Contents      | Read           | build secret de `build-docker`, téléchargement de la base Trivy dans `scan-trivy`                                                     |
| Contents      | Read and write | `release-app`, `release-helm`, `update-helm-chart`, `sync-prerelease-branch` — push de commits, tags, releases, branche de prerelease |
| Pull requests | Read and write | Automerge dans `release-app` et `update-helm-chart`                                                                                   |
| Actions       | Read and write | `dispatch-helm-chart` uniquement — à accorder sur le dépôt **chart**                                                                  |

Un token classique avec le scope **`repo`** fonctionne aussi, mais donne accès à tous les dépôts que le compte peut atteindre.

`sync-prerelease-branch` n'accepte pas de PAT : seule une App peut figurer dans la liste de bypass d'un ruleset.

> **Utiliser un token en lecture seule pour `build-docker`.** Sa valeur est montée dans le build Docker, où tout script d'installation, hook postinstall ou binaire précompilé exécuté par le Dockerfile peut la lire. `BUILD_SECRET_GITHUB_TOKEN: pat` accepte un `GH_PAT` mais refuse toujours de retomber sur le `GITHUB_TOKEN` du job — scoper le PAT à `Contents: read` et rien de plus. Sans App et sans problème de rate limit à résoudre, laisser la valeur à `none`. Voir [Ce que `build-docker` injecte réellement](#ce-que-build-docker-injecte-réellement).

### Étape 2 : Stocker le token

**Settings → Secrets and variables → Actions → New repository secret**, nommé `GH_PAT`.

### Étape 3 : Câbler le secret

Le même pipeline qu'en mode 2, avec un seul secret au lieu de deux :

```yaml
name: CD

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
    with:
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
      AUTOMERGE_METHOD: auto
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  build:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      # 'pat' accepte GH_PAT mais refuse toujours de retomber sur le
      # GITHUB_TOKEN du job. Utiliser 'job-token' pour obtenir délibérément ce
      # repli.
      BUILD_SECRET_GITHUB_TOKEN: pat
    # Token en lecture seule ici — voir l'avertissement à l'étape 1.
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  bump-chart:
    needs: release
    if: ${{ needs.release.outputs.release-created == 'true' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: patch
      AUTOMERGE_RELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  release-chart:
    needs:
    - release
    - bump-chart
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      # Canal classique laissé par défaut : c'est lui qui crée les GitHub
      # Releases, donc le seul pour lequel le token ci-dessous sert à quelque
      # chose
      CHARTS_DIR: ./charts
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Compromis face à une GitHub App

Un PAT est fonctionnellement équivalent — il déclenche les workflows, les PRs de release ont bien leur CI, et il relève la limite de la même façon. Ce qui diffère :

- Il agit **en votre nom**. Chaque commit, tag et merge est attribué à votre compte, et il porte votre accès à tous les dépôts sélectionnés.
- Il partage un seul budget de 5000 requêtes/heure avec tout ce que vous faites sur GitHub, au lieu d'un budget dédié par installation.
- Il expire. Les fine-grained tokens durent au plus un an et le pipeline casse le jour de l'expiration. Les tokens App sont mintés par job et expirent en une heure par conception ; la clé privée derrière n'expire jamais.
- Il ne peut pas être réduit par job. Une App mint un token qui ne porte que ce dont le job a besoin ; un PAT porte tout ce qui lui a été accordé, partout où il est utilisé.

## Avancé

### Dispatch cross-repository (`dispatch-helm-chart`)

[`dispatch-helm-chart.yml`](./54-dispatch-helm-chart.md) déclenche un workflow dans un dépôt **différent**, donc le token est minté scopé à ce dépôt-là — ce qui veut dire que l'App doit être installée sur le dépôt **chart**, pas sur celui qui exécute ce job.

```yaml
trigger-chart-update:
  uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
  # Aucun scope sur le GITHUB_TOKEN : le dispatch est entièrement authentifié
  # par le token de l'App (ou GH_PAT), minté par le job, et rien n'est écrit sur
  # ce dépôt-ci. C'est précisément pourquoi le dispatch a son propre workflow
  # réutilisable : GitHub valide au parsing les permissions de *tous* les jobs
  # du workflow appelé, donc un job qui partagerait le fichier imposerait ses
  # scopes à cet appel.
  permissions: {}
  with:
    WORKFLOW_NAME: update-app-version.yml
    CHART_REPO: my-org/helm-charts
    CHART_NAME: my-app
    APP_VERSION: 1.4.0
    UPGRADE_TYPE: minor
  secrets:
    APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
    APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Checklist pour ce cas :

|                       |                                                                   |
| --------------------- | ----------------------------------------------------------------- |
| App installée sur     | `my-org/helm-charts` (la valeur de `CHART_REPO`)                  |
| Permission de l'App   | **Actions: Read and write**                                       |
| Secrets stockés dans  | le dépôt qui exécute ce job, pas le dépôt chart                   |
| Portée du token       | `CHART_REPO` uniquement — jamais le dépôt courant                 |
| Forme de `CHART_REPO` | `owner/repository` — un nom seul échoue à la validation           |
| Branche ciblée        | `BASE_BRANCH` (défaut `main`), passée à `gh workflow run --ref`   |

Le dispatch passe toujours `--ref` explicitement plutôt que de laisser `gh workflow run` résoudre lui-même la branche par défaut de `CHART_REPO` : cette résolution passe par une requête GraphQL `defaultBranchRef` que le scope `Actions: Read and write` seul de ce token ne peut pas satisfaire. Voir [Dépannage](#dépannage) ci-dessous.

#### `AUTOMERGE_METHOD` à travers le dispatch

Le dispatch ne fusionne rien lui-même ; il confie le travail au dépôt chart, qui exécute `update-helm-chart.yml` en mode `called` et fusionne là-bas. `AUTOMERGE_METHOD` est transmis avec le dispatch pour que le choix reste celui du dépôt applicatif.

Cela suppose que le workflow d'entrée du dépôt chart **déclare un input `AUTOMERGE_METHOD`**. Sinon, GitHub rejette tout le dispatch (`422 Unexpected inputs provided`) plutôt que d'ignorer la valeur en trop. Le dispatch réessaie donc une fois sans cet input et avertit :

```
::warning::'update-app-version.yml' in 'my-org/helm-charts' does not declare an
AUTOMERGE_METHOD input, so the chart repository's own default applies
```

Le dispatch réussit quand même — le dépôt chart utilise simplement son propre défaut (`auto`). Pour piloter la méthode depuis le dépôt applicatif, ajouter l'input au workflow d'entrée du dépôt chart (`workflow_dispatch`/`workflow_call`).

### Deux Apps : isoler le credential de build

Durcissement optionnel de l'étape 1. Créer une seconde App avec uniquement **Metadata: read** et **Contents: read**, stocker ses credentials sous d'autres noms de secrets, et les mapper à chaque appel :

```yaml
release:
  uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
  permissions:
    contents: write
    issues: write
    pull-requests: write
  secrets:
    APP_CLIENT_ID: ${{ secrets.RELEASE_APP_CLIENT_ID }}
    APP_PRIVATE_KEY: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}

build:
  uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
  permissions:
    packages: write
    contents: read
  with:
    IMAGE_NAME: ghcr.io/my-org/my-app
    IMAGE_TAG: ${{ github.sha }}
    IMAGE_CONTEXT: ./
    IMAGE_DOCKERFILE: ./Dockerfile
    BUILD_SECRET_GITHUB_TOKEN: app
    # App différente : une clé fuitée depuis le build ne mint que des lectures.
  secrets:
    APP_CLIENT_ID: ${{ secrets.BUILD_APP_CLIENT_ID }}
    APP_PRIVATE_KEY: ${{ secrets.BUILD_APP_PRIVATE_KEY }}
```

Les noms des inputs du workflow ne changent jamais — seul change le secret mappé dessus.

### Migrer depuis un PAT

L'App est prioritaire quand les deux sont présents : la bascule peut donc être vérifiée avant de retirer quoi que ce soit. Passer les deux pour une release :

```yaml
release:
  uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
  permissions:
    contents: write
    issues: write
    pull-requests: write
  with:
    AUTOMERGE_RELEASE: true
  secrets:
    APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
    APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
    # Conservé pour un seul run. Inutilisé tant que les credentials App sont résolus.
    GH_PAT: ${{ secrets.GH_PAT }}
```

Vérifier que l'auteur de la pull request est devenu `votre-app[bot]`, puis supprimer la ligne `GH_PAT:` et le secret. En cas de problème, retirer les deux lignes `APP_*` rebascule directement sur le PAT, sans autre changement.

## Automerge

L'automerge se déclenche quand `AUTOMERGE_RELEASE` / `AUTOMERGE_PRERELEASE` vaut `true`. Il est gaté uniquement sur ces inputs — ajouter les credentials App n'active jamais l'automerge tout seul. Si l'automerge est activé sans credential fourni, le job **échoue** plutôt que de silencieusement ne rien fusionner.

`AUTOMERGE_METHOD` choisit comment :

| Valeur           | Comportement                                                                             | Prérequis                                          |
| ---------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `auto` (défaut)  | Met la PR en file d'attente ; GitHub la fusionne une fois les checks requis passés       | **Allow auto-merge** activé dans Settings → General |
| `admin`          | Fusionne immédiatement, **en contournant la protection de branche et les checks requis** | L'acteur doit pouvoir contourner la protection     |

`auto` est le défaut car l'intérêt de l'authentification App est justement que les PRs de release exécutent enfin leur CI — fusionner en `admin` ignorerait ce résultat. Il n'y a pas de repli automatique entre les deux : si `auto` est sélectionné et que l'auto-merge n'est pas activé sur le dépôt, le job échoue avec un message indiquant quel réglage changer.

## Ce qui piège tout le monde

**Le bloc `permissions:` du job ne s'applique pas au token App.**

```yaml
permissions:
  contents: write # ne gouverne que GITHUB_TOKEN
```

Ce bloc contrôle `GITHUB_TOKEN`. L'autorité d'un token App vient de ce que l'installation de l'App a reçu, réduit par les valeurs `permission-*` demandées par le workflow. Élargir `permissions:` ne corrigera jamais une erreur de permission liée au token App. Deux systèmes distincts, même mot — en cas d'erreur de permission, vérifier les réglages d'installation de l'App, pas le YAML du workflow.

## Dépannage

| Symptôme                                                      | Cause                                                                                                                 | Solution                                                                                                                  |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `Input required and not supplied: private-key`                | Secrets non transmis via le bloc `secrets:` du job appelant                                                           | Les workflows réutilisables n'héritent pas des secrets automatiquement — les passer explicitement                         |
| `Resource not accessible by integration`                      | L'App n'a pas la permission, ou n'est pas installée sur le dépôt                                                      | Vérifier l'**installation**, pas `permissions:` du job — si le message mentionne `defaultBranchRef`, voir la ligne en bas |
| `HttpError: Not Found` au moment du mint                      | App non installée sur l'owner/dépôt demandé                                                                           | L'installer, ou corriger `CHART_REPO`                                                                                     |
| L'automerge échoue en demandant `Allow auto-merge`            | `AUTOMERGE_METHOD=auto` avec le réglage désactivé sur le dépôt                                                        | L'activer dans Settings → General, ou passer `AUTOMERGE_METHOD: admin`                                                    |
| `Automerge is enabled but no credential was supplied`         | `AUTOMERGE_*` à `true` sans App ni PAT                                                                                | Fournir les credentials, ou passer `AUTOMERGE_*: false`                                                                   |
| Le token fonctionne puis échoue ~une heure plus tard          | Les tokens d'installation expirent après 1 heure                                                                      | Ils sont mintés par job ; ne jamais en passer un entre jobs                                                               |
| Rien ne change après l'ajout des secrets                      | Mauvais nom de secret, ou App ID numérique utilisé au lieu du Client ID                                               | Vérifier que l'étape "Generate GitHub App token" a tourné et n'a pas été ignorée                                          |
| `APP_CLIENT_ID and APP_PRIVATE_KEY must be supplied together` | L'un des deux est manquant, vide ou mal orthographié au niveau de l'appel                                             | Fournir les deux, ou aucun — voir [Les deux secrets App, ou aucun](#les-deux-secrets-app-ou-aucun)                        |
| `CHART_REPO must be 'owner/repository'`                       | `CHART_REPO` fourni sans owner, ex: `helm-charts`                                                                     | Utiliser la forme complète `owner/repo`                                                                                   |
| Le mode caller avertit que `AUTOMERGE_METHOD` n'est pas déclaré | Le workflow d'entrée du dépôt chart est antérieur à cet input                                                       | Ajouter `AUTOMERGE_METHOD` à ses inputs `workflow_dispatch`/`workflow_call`                                               |
| `unable to determine default branch for <repo>: GraphQL: Resource not accessible by integration (repository.defaultBranchRef)` | Le dispatch en mode caller résolvait la branche par défaut de `CHART_REPO` via GraphQL, ce qui demande plus que `Actions: Read and write` | Déjà corrigé en passant toujours `--ref BASE_BRANCH` ; si la branche par défaut de `CHART_REPO` n'est pas `main`, renseigner `BASE_BRANCH` explicitement |

### Les deux secrets App, ou aucun

`APP_CLIENT_ID` et `APP_PRIVATE_KEY` ne servent qu'ensemble. En fournir un seul est toujours une erreur — une faute de frappe à l'appel, ou un secret jamais créé — et l'ordre de résolution y répondrait silencieusement avec `GH_PAT` ou `GITHUB_TOKEN`. Vous obtiendriez un run vert authentifié avec autre chose que l'App, soit exactement le mode de défaillance que cette page cherche à éviter.

Chaque job qui mint un token **échoue donc immédiatement** lorsqu'un seul des deux est présent, avant tout travail :

```
::error::APP_CLIENT_ID and APP_PRIVATE_KEY must be supplied together, but only one was.
```

Ne fournir **aucun** des deux est une configuration supportée, pas une erreur : c'est le mode 1 ou le mode 3.

## Ce que `build-docker` injecte réellement

`BUILD_SECRET_GITHUB_TOKEN` monte un credential dans `/run/secrets/github_token`, lisible par tout script d'installation, hook postinstall ou binaire précompilé exécuté par le Dockerfile. C'est le seul endroit où le repli habituel App → `GH_PAT` → `GITHUB_TOKEN` serait activement dangereux, car **les trois n'ont pas la même largeur et le dernier est le plus large**. Le credential est donc nommé explicitement :

| Valeur      | Résout vers                                              | Réduit à                                                         | Réduit par                         |
| ----------- | -------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------- |
| `none`      | rien d'injecté *(défaut)*                                | —                                                                | —                                  |
| `app`       | token App ; **échoue** si absent                         | `contents: read` + `metadata: read`, ce dépôt uniquement         | ce workflow, au moment du mint     |
| `pat`       | token App, sinon `GH_PAT` ; **échoue** si aucun des deux | ce qui a été accordé au PAT                                      | vous                               |
| `job-token` | token App, sinon `GH_PAT`, sinon `GITHUB_TOKEN`          | **rien** — tout le bloc `permissions:` du job appelant           | personne ; ne peut pas être réduit |

Un job appelant `build-docker.yml` accorde généralement `packages: write`, donc `job-token` peut donner un credential de push registre à tout le build. Une dépendance transitive compromise du build pourrait publier une image avec. Le workflow émet un `::warning::` chaque fois que ce mode retombe réellement sur le token du job.

**`GITHUB_TOKEN` ne peut-il pas simplement être réduit pour cet usage ?** Non. Ses permissions sont fixées au démarrage du job, à partir du bloc `permissions:` croisé avec ce que l'appelant a accordé, et il n'existe aucune API pour les atténuer le temps d'une seule étape. Le job de build a besoin de `packages: write` pour pousser l'image, c'est donc ce que porte le token. Minter un token App distinct et plus étroit est le seul moyen d'injecter quelque chose en lecture seule — c'est exactement ce que fait `app`.

Ordre de préférence : **`app` → `pat` (lecture seule) → `none`.** Ne recourir à `job-token` que délibérément.

## Sécurité contre les boucles

**Les tokens App et les PATs déclenchent tous deux des workflows** — c'est le but, et c'est aussi le risque. `GITHUB_TOKEN` est le seul mode auquel cette section ne s'applique pas. Trois règles que suivent les workflows, utiles à connaître si vous les modifiez :

- **`actions/checkout` conserve `GITHUB_TOKEN`.** Ces workflows poussent les tags, les branches de prerelease et les bumps de chart avec `git`. Avec un credential capable de déclencher des workflows, ces pushes relanceraient le pipeline CD de l'appelant. Seules les étapes qui ont réellement besoin du credential élevé le reçoivent.
- **Le commit de bump du chart ne porte volontairement aucun marqueur skip-ci.** En mode `local`, le bump du chart est poussé directement sur la branche qui déclenche le CD, mais il reste sur `GITHUB_TOKEN` — c'est la même règle que ci-dessus, pas une règle distincte. Un marqueur skip-ci n'apporterait rien ici (`GITHUB_TOKEN` ne peut déjà pas déclencher de nouveau run, ni sur `push` ni sur `pull_request`) tout en causant un vrai tort : il est évalué sur le seul message du commit, quel que soit le credential qui l'a écrit, et supprimerait donc aussi les checks de toute pull request qu'un humain ouvrirait ensuite DEPUIS cette branche — une promotion `develop` → `main`, par exemple, n'aurait aucun check jusqu'à l'arrivée d'un nouveau commit.
- **`release-helm.yml` pousse la branche pages avec le même token que celui qui crée les releases.** Fournir l'un ou l'autre credential élevé permet donc à ce push de déclencher aussi des workflows, pas seulement à la création de la release. Vérifier d'abord que rien ne se déclenche sur votre `PAGES_BRANCH`.

### Ce que la règle du checkout ne couvre *pas*

Conserver `GITHUB_TOKEN` sur `actions/checkout` ne borne **que les pushes `git`**. Tout ce qu'une action crée via l'API utilise le token propre à cette action, et avec une authentification App ou PAT ces événements se déclenchent normalement :

| Créé par                                              | Credential              | Déclenche des workflows ?        |
| ----------------------------------------------------- | ----------------------- | -------------------------------- |
| `git push` des tags `v1` / `v1.2`                     | Token du checkout       | Non                              |
| `git push` de la branche de prerelease                | Token du checkout       | Non                              |
| `git push` du bump de chart en mode `local`           | Token du checkout       | Non                              |
| Le tag `vX.Y.Z` et la Release de release-please       | Token App / `GH_PAT`    | **Oui**                          |
| La pull request de release                            | Token App / `GH_PAT`    | **Oui** — c'est le but           |
| La pull request de mise à jour du chart               | Token App / `GH_PAT`    | **Oui** — c'est le but           |
| Le push de la *branche* de mise à jour du chart elle-même | Token App / `GH_PAT` | **Oui**                          |

Avant de basculer un dépôt sur une App ou un PAT, vérifier donc ce sur quoi il se déclenche. `on: pull_request:` est ce que vous activez délibérément. `on: push: tags:` et `on: release:` vont aussi se mettre à se déclencher, ce qui est facile à manquer — sous `GITHUB_TOKEN`, ce n'était jamais le cas.

La dernière ligne est celle qui surprend : `create-pull-request` pousse la branche `<chart-name>-v<version>` avec le même token que celui qui ouvre la pull request, donc un workflow déclenché sur `push:` avec un pattern de branche large (`'**'`, ou tout ce qui correspond à ce nom) se met à se déclencher dès qu'un credential élevé est fourni. Restreindre ces patterns aux branches réellement visées.

## Notes de sécurité

- La clé privée est longue durée, utilisable hors GitHub Actions, et mint des tokens pour tous les dépôts sur lesquels l'App est installée. Sa portée est **plus étroite qu'un PAT classique** mais **plus large que `GITHUB_TOKEN`** — installer aussi restrictivement que possible et garder la clé dans le moins de dépôts possible.
- Les tokens sont mintés par job, scopés au dépôt courant, et réduits avec `permission-*` à ce dont ce job a besoin — un token sans `permission-*` hériterait de toutes les permissions de l'installation. Ils ne sont jamais écrits dans `GITHUB_OUTPUT`, `GITHUB_ENV`, ni dans les outputs de job.
- La portée sur les dépôts vient du fait de laisser `owner` et `repositories` non définis, ce que l'action résout vers le dépôt courant. Définir `owner` seul élargirait un token à toute l'installation — voir [Comment la portée sur les dépôts est déterminée](#comment-la-portée-sur-les-dépôts-est-déterminée) avant d'ajouter ou de modifier une étape de mint.
- Les pull requests venant de forks ne reçoivent aucun secret du dépôt, donc aucun credential App ne peut atteindre un build déclenché par un fork. Ajouter `pull_request_target` ou `secrets: inherit` à un job atteignable depuis un fork romprait cette garantie.
- Pour renouveler la clé : en générer une seconde, mettre à jour le secret, puis supprimer la première. Les deux sont valides entre-temps, donc pas d'interruption de service.
