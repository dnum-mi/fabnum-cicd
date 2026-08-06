# Authentification

Certains workflows ont besoin d'un credential GitHub au-delà de celui fourni automatiquement. Trois modes sont supportés, et ils peuvent coexister.

## Quel mode choisir ?

Partir du haut du tableau et s'arrêter à la première ligne qui correspond.

| Si vous...                                                                      | Utilisez                          | Secrets à définir                  |
| -------------------------------------------------------------------------------- | ---------------------------------- | ----------------------------------- |
| build/test/scan/push vers GHCR uniquement                                        | **`GITHUB_TOKEN`** — automatique  | aucun                                |
| avez besoin que les PRs de release/chart déclenchent la CI                       | **GitHub App** (ou `GH_PAT`)       | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`  |
| avez besoin de l'automerge                                                       | **GitHub App** (ou `GH_PAT`)       | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`  |
| devez déclencher un workflow dans un **autre** dépôt (`update-helm-chart` mode `caller`) | **GitHub App** (ou `GH_PAT`) | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`  |
| avez besoin que les releases de chart déclenchent des triggers `release:` (`release-helm`) | **GitHub App** (ou `GH_PAT`) | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`  |
| atteignez les limites de l'API GitHub pendant les scans Trivy                    | **GitHub App** (ou `GH_PAT`)       | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`  |
| atteignez les limites de l'API GitHub **dans un build Docker**                   | **GitHub App** (ou `GH_PAT`)       | les deux ci-dessus, **plus** [`BUILD_SECRET_GITHUB_TOKEN`](#ce-que-build-docker-injecte-réellement) |
| avez déjà un `GH_PAT` fonctionnel et ne voulez rien changer                      | **`GH_PAT`** — toujours supporté  | `GH_PAT`                             |

Les lignes marquées *(ou `GH_PAT`)* fonctionnent avec l'un ou l'autre credential — définir `GH_PAT` au lieu des deux secrets `APP_*`. La GitHub App est recommandée car elle est scopée par job, expire au bout d'une heure et n'est pas liée à une personne.

**Les trois modes sont acceptés par tous les workflows qui prennent un credential**, avec l'ordre de résolution suivant :

```
Token App  →  GH_PAT  →  GITHUB_TOKEN
```

Chaque étape n'est utilisée que si la précédente est absente : ajouter un credential ne retire jamais une capacité, en retirer un ne casse jamais plus que ce qu'il apportait. Si App et PAT sont configurés en même temps, **l'App l'emporte** — ce qui permet de vérifier une migration avant de supprimer le PAT.

Ne fournir qu'un seul des deux secrets `APP_CLIENT_ID` / `APP_PRIVATE_KEY` n'est jamais valide et **fait échouer le job** plutôt que de retomber silencieusement sur un mode moins privilégié.

### Où la chaîne s'arrête plus tôt

Trois cas ne vont pas jusqu'au bout de cette chaîne, chacun échouant avec un message explicite plutôt que de faire silencieusement moins que demandé :

| Cas                                                          | S'arrête à           | Pourquoi                                                        |
| -------------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------ |
| Automerge (`release-app`, `update-helm-chart`)                | Token App ou `GH_PAT`  | `GITHUB_TOKEN` ne peut pas fusionner une pull request              |
| Dispatch cross-repository (`update-helm-chart` mode `caller`) | Token App ou `GH_PAT`  | `GITHUB_TOKEN` est scopé à son propre dépôt                        |
| Build secret de `build-docker`                                | ce que vous demandez   | La valeur est lisible par tout ce que le Dockerfile exécute, donc le credential est nommé explicitement plutôt que de retomber silencieusement sur un autre — voir [Ce que `build-docker` injecte réellement](#ce-que-build-docker-injecte-réellement) |

## Pourquoi le mode App existe

`GITHUB_TOKEN` est volontairement empêché de déclencher d'autres workflows, pour éviter les boucles d'automatisation. L'effet de bord est qu'une pull request ouverte avec `GITHUB_TOKEN` **ne déclenche jamais les workflows `pull_request`** — les PRs de release sont fusionnées sans qu'aucun check n'ait tourné.

Un token d'installation GitHub App n'est pas soumis à cette règle : les pull requests automatisées se comportent comme des pull requests humaines. Il dispose aussi de plus de marge sur les limites d'API : 5000 requêtes/heure contre 1000/heure par dépôt pour `GITHUB_TOKEN`.

## Mode 1 : `GITHUB_TOKEN`

**Créer :** rien. **Stocker :** rien. **Passer :** rien. Chaque job en reçoit un automatiquement ; seul le bloc `permissions:` est à configurer.

Ce que vous perdez en restant sur ce mode :

| Limite                                | Conséquence                                                       |
| -------------------------------------- | -------------------------------------------------------------------- |
| Ne peut pas déclencher de workflows     | Les PRs de release/chart s'ouvrent **sans aucun check**             |
| 1000 requêtes/heure par dépôt          | Les grosses matrices de build échouent en cours de route (`403 rate limit exceeded`) |
| Ne peut pas fusionner de pull request   | `AUTOMERGE_*: true` fait échouer le job                              |

Si rien de tout ça ne vous concerne, restez sur ce mode — c'est celui à privilégier.

## Mode 2 : GitHub App

### Étape 1 : Créer l'App

**Settings → Developer settings → GitHub Apps → New GitHub App.**

| Champ                                    | Valeur                                                                     |
| ------------------------------------------ | ----------------------------------------------------------------------------- |
| **GitHub App name**                        | N'importe quel nom unique — il devient l'auteur des PRs (ex: `my-org-ci` → `my-org-ci[bot]`) |
| **Homepage URL**                           | N'importe quelle URL valide, non utilisée                                    |
| **Webhook → Active**                       | **Décocher.** Ces workflows ne reçoivent pas de webhooks                     |
| **Where can this GitHub App be installed** | *Only on this account*                                                       |

**Une seule App suffit.** Lui accorder l'union de ce dont les workflows ont besoin :

| Permission     | Accès          | Nécessaire pour                        |
| -------------- | -------------- | ----------------------------------------- |
| Metadata       | Read-only      | Obligatoire pour toute App                |
| Contents       | Read and write | Commits, tags, releases                   |
| Pull requests  | Read and write | Ouvrir et fusionner des pull requests     |
| Issues         | Read and write | Labels release-please                     |
| Actions        | Read and write | `update-helm-chart` mode `caller` uniquement |

Chaque workflow mint ensuite son propre token, réduit à ce dont ce job a besoin :

| Workflow                                  | Token réduit à                                | Portée                    |
| -------------------------------------------- | ------------------------------------------------ | ---------------------------- |
| `release-app.yml`                            | `contents`, `pull-requests`, `issues` = write   | dépôt courant                |
| `update-helm-chart.yml` (`called`/`local`)   | `contents`, `pull-requests` = write             | dépôt courant                |
| `update-helm-chart.yml` (`caller`)           | `actions: write`                                | dépôt du chart uniquement    |
| `release-helm.yml`                           | `contents: write`                               | dépôt courant                |
| `build-docker.yml`                           | `contents`, `metadata` = read                   | dépôt courant                |
| `scan-trivy.yml`                             | `contents`, `metadata` = read                   | dépôt courant                |

Une App, une clé privée, plusieurs tokens réduits différemment.

> **La réduction de scope est essentielle.** Un token minté sans valeur `permission-*` hérite de **toutes les permissions de l'installation**. C'est pourquoi `build-docker.yml` demande toujours explicitement `contents: read` : son token est monté dans le build Docker, où tout script d'installation, hook postinstall ou binaire précompilé exécuté par le Dockerfile peut le lire.

### Étape 2 : Générer une clé privée

En bas des réglages de l'App, **Generate a private key**. Un fichier `.pem` est téléchargé — il ne peut plus être récupéré ensuite. Quiconque le détient peut minter des tokens pour tous les dépôts sur lesquels l'App est installée, avec toutes les permissions de l'installation.

### Étape 3 : Installer l'App

**Install App → Only select repositories →** choisir les dépôts qui exécutent ces workflows. Installer aussi restrictivement que possible : c'est la liste d'installation, pas la réduction par mint, qui borne une clé privée fuitée.

### Étape 4 : Stocker les secrets

Par dépôt : **Settings → Secrets and variables → Actions → New repository secret.**

| Nom               | Valeur                                                        |
| ------------------ | ---------------------------------------------------------------- |
| `APP_CLIENT_ID`     | le **Client ID** de l'App (ressemble à `Iv23li…`)                |
| `APP_PRIVATE_KEY`   | le `.pem` complet, avec les lignes `-----BEGIN…`/`-----END…`     |

> Le **Client ID**, pas l'App ID numérique. Les deux apparaissent sur la page de réglages de l'App et seul l'un des deux fonctionne.

Les deux mêmes secrets servent à tous les workflows.

### Étape 5 : Câbler les secrets

Chaque job qui accepte les credentials App reçoit les deux mêmes secrets ; chacun mint en interne son propre token réduit.

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
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ghcr.io/my-org/my-app
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      IMAGE_CONTEXT: ./
      IMAGE_DOCKERFILE: ./Dockerfile
      # Relève le budget d'API pour mise/aqua/ubi dans le build. Mint un token
      # séparé et en lecture seule ; 'app' échoue plutôt que de retomber sur un
      # credential qu'il ne peut pas réduire.
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
      CHARTS_DIR: ./charts
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

`scan-trivy.yml` accepte les deux mêmes secrets et les utilise uniquement pour relever le budget de téléchargement de la base Trivy.

### Étape 6 : Vérifier

Pousser un commit qui produit une release. Trois choses doivent visiblement changer :

1. La PR de release est ouverte par `votre-app[bot]`, pas `github-actions[bot]`.
2. Elle **a des checks** — la CI qui ne tournait jamais sur les PRs de release tourne désormais.
3. Le log de chaque job affiche une étape *Generate GitHub App token* exécutée plutôt qu'ignorée. Si elle a été ignorée, les secrets ne sont pas arrivés jusqu'au workflow.

## Mode 3 : Personal access token

Accepté par tous les workflows qui prennent un credential, aux mêmes endroits qu'un token App et résolu juste après lui. À privilégier si un PAT fonctionne déjà, ou si créer une App n'en vaut pas la peine.

### Étape 1 : Créer le token

**Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token.** Scoper à *Only select repositories* et accorder uniquement ce qui est réellement utilisé :

| Permission     | Accès          | Nécessaire pour                                                                     |
| -------------- | -------------- | --------------------------------------------------------------------------------------- |
| Contents       | Read           | build secret de `build-docker`, téléchargement de la base Trivy dans `scan-trivy`      |
| Contents       | Read and write | `release-app`, `release-helm`, `update-helm-chart` — push de commits, tags, releases   |
| Pull requests  | Read and write | Automerge dans `release-app` et `update-helm-chart`                                    |
| Actions        | Read and write | `update-helm-chart` mode `caller` uniquement — à accorder sur le dépôt **chart**       |

> **Utiliser un token en lecture seule pour `build-docker`.** Sa valeur est montée dans le build Docker, lisible par tout ce que le Dockerfile exécute. `BUILD_SECRET_GITHUB_TOKEN: pat` accepte un `GH_PAT` mais refuse toujours de retomber sur le `GITHUB_TOKEN` du job — scoper le PAT à `Contents: read` et rien de plus.

### Étape 2 : Stocker le token

**Settings → Secrets and variables → Actions → New repository secret**, nommé `GH_PAT`.

### Étape 3 : Câbler le secret

Le même pipeline qu'en mode 2, avec un seul secret au lieu de deux :

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      AUTOMERGE_RELEASE: true
      AUTOMERGE_METHOD: auto
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}
```

### Compromis face à une GitHub App

Un PAT est fonctionnellement équivalent — il déclenche les workflows, les PRs de release ont bien leur CI, et il relève la limite de la même façon. Ce qui diffère :

- Il agit **en votre nom**. Chaque commit, tag et merge est attribué à votre compte.
- Il partage un seul budget de 5000 requêtes/heure avec tout ce que vous faites sur GitHub, au lieu d'un budget dédié par installation.
- Il expire. Les fine-grained tokens durent au plus un an et le pipeline casse le jour de l'expiration. Les tokens App sont mintés par job et expirent en une heure ; la clé privée derrière n'expire jamais.
- Il ne peut pas être réduit par job. Une App mint un token qui ne porte que ce dont le job a besoin ; un PAT porte tout ce qui lui a été accordé, partout où il est utilisé.

## Automerge

L'automerge se déclenche quand `AUTOMERGE_RELEASE` / `AUTOMERGE_PRERELEASE` vaut `true`. Il est gaté uniquement sur ces inputs — ajouter les credentials App n'active jamais l'automerge tout seul. Si l'automerge est activé sans credential fourni, le job **échoue** plutôt que de silencieusement ne rien fusionner.

`AUTOMERGE_METHOD` choisit comment :

| Valeur              | Comportement                                                                    | Prérequis                                       |
| --------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `auto` (défaut)       | Met la PR en file d'attente ; GitHub la fusionne une fois les checks requis passés  | *Allow auto-merge* activé dans Settings → General  |
| `admin`               | Fusionne immédiatement, **en contournant la protection de branche et les checks requis** | L'acteur doit pouvoir contourner la protection    |

`auto` est le défaut car l'intérêt de l'authentification App est justement que les PRs de release exécutent enfin leur CI — fusionner en `admin` ignorerait ce résultat. Il n'y a pas de repli automatique entre les deux : si `auto` est sélectionné et que l'auto-merge n'est pas activé sur le dépôt, le job échoue avec un message indiquant quel réglage changer.

## Dispatch cross-repository (`update-helm-chart` mode `caller`)

Le mode `caller` déclenche un workflow dans un dépôt **différent**, donc le token est minté scopé à ce dépôt-là — ce qui veut dire que l'App doit être installée sur le dépôt **chart**, pas sur celui qui exécute ce job.

```yaml
trigger-chart-update:
  uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
  permissions: {}
  with:
    RUN_MODE: caller
    WORKFLOW_NAME: update-app-version.yml
    CHART_REPO: my-org/helm-charts
    CHART_NAME: my-app
    APP_VERSION: 1.4.0
    UPGRADE_TYPE: minor
  secrets:
    APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
    APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

|                    |                                                             |
| -------------------- | --------------------------------------------------------------- |
| App installée sur    | `my-org/helm-charts` (la valeur de `CHART_REPO`)                |
| Permission de l'App  | **Actions: Read and write**                                     |
| Secrets stockés dans | le dépôt qui exécute ce job, pas le dépôt chart                 |
| Portée du token      | `CHART_REPO` uniquement — jamais le dépôt courant                |
| Forme de `CHART_REPO`| `owner/repository` — un nom seul échoue à la validation         |

`AUTOMERGE_METHOD` est transmis avec le dispatch pour que le choix reste celui de l'appelant. Cela suppose que le workflow d'entrée du dépôt chart **déclare un input `AUTOMERGE_METHOD`** ; sinon GitHub rejette tout le dispatch (`422 Unexpected inputs provided`). Le dispatch réessaie alors automatiquement sans cet input et avertit :

```
::warning::'update-app-version.yml' in 'my-org/helm-charts' does not declare an
AUTOMERGE_METHOD input, so the chart repository's own default applies
```

## Ce que `build-docker` injecte réellement

`BUILD_SECRET_GITHUB_TOKEN` monte un credential dans `/run/secrets/github_token`, lisible par tout script d'installation, hook postinstall ou binaire précompilé exécuté par le Dockerfile. C'est le seul endroit où le repli habituel App → `GH_PAT` → `GITHUB_TOKEN` serait activement dangereux, car **les trois n'ont pas la même largeur et le dernier est le plus large**. Le credential est donc nommé explicitement :

| Valeur       | Résout vers                                       | Réduit à                                                    | Réduit par                    |
| ------------- | ---------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------- |
| `none`        | rien d'injecté *(défaut)*                            | —                                                                  | —                                  |
| `app`         | token App ; **échoue** si absent                     | `contents: read` + `metadata: read`, ce dépôt uniquement        | ce workflow, au moment du mint     |
| `pat`         | token App, sinon `GH_PAT` ; **échoue** si aucun des deux | ce qui a été accordé au PAT                                    | vous                                |
| `job-token`   | token App, sinon `GH_PAT`, sinon `GITHUB_TOKEN`      | **rien** — tout le bloc `permissions:` du job appelant           | personne ; ne peut pas être réduit |

Un job appelant `build-docker.yml` accorde généralement `packages: write`, `id-token: write` et `attestations: write`, donc `job-token` peut donner un credential de push registre à tout le build. Le workflow émet un `::warning::` chaque fois que ce mode retombe réellement sur le token du job.

Ordre de préférence : **`app` → `pat` (lecture seule) → `none`.** Ne recourir à `job-token` que délibérément.

## Ce qui piège tout le monde

**Le bloc `permissions:` du job ne s'applique pas au token App.**

```yaml
permissions:
  contents: write # ne gouverne que GITHUB_TOKEN
```

Ce bloc contrôle `GITHUB_TOKEN`. L'autorité d'un token App vient de ce que l'installation de l'App a reçu, réduit par les valeurs `permission-*` demandées par le workflow. Élargir `permissions:` ne corrigera jamais une erreur de permission liée au token App. Deux systèmes distincts, même mot — en cas d'erreur de permission, vérifier les réglages d'installation de l'App, pas le YAML du workflow.

## Dépannage

| Symptôme                                                        | Cause                                                                    | Solution                                                                       |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `Input required and not supplied: private-key`                     | Secrets non transmis via le bloc `secrets:` du job appelant                 | Les workflows réutilisables n'héritent pas des secrets automatiquement          |
| `Resource not accessible by integration`                           | L'App n'a pas la permission, ou n'est pas installée sur le dépôt            | Vérifier l'**installation**, pas `permissions:` du job                          |
| `HttpError: Not Found` au moment du mint                           | App non installée sur l'owner/dépôt demandé                                 | L'installer, ou corriger `CHART_REPO`                                          |
| L'automerge échoue en demandant `Allow auto-merge`                 | `AUTOMERGE_METHOD=auto` avec le réglage désactivé sur le dépôt              | L'activer dans Settings → General, ou passer `AUTOMERGE_METHOD: admin`         |
| `Automerge is enabled but no credential was supplied`              | `AUTOMERGE_*` à `true` sans App ni PAT                                      | Fournir les credentials, ou passer `AUTOMERGE_*: false`                        |
| Le token fonctionne puis échoue ~une heure plus tard                | Les tokens d'installation expirent après 1 heure                            | Ils sont mintés par job ; ne jamais en passer un entre jobs                    |
| Rien ne change après l'ajout des secrets                           | Mauvais nom de secret, ou App ID numérique utilisé au lieu du Client ID     | Vérifier que l'étape "Generate GitHub App token" a tourné et n'a pas été ignorée |
| `APP_CLIENT_ID and APP_PRIVATE_KEY must be supplied together`      | L'un des deux est manquant, vide ou mal orthographié au niveau de l'appel   | Fournir les deux, ou aucun                                                     |
| `CHART_REPO must be 'owner/repository'`                            | `CHART_REPO` fourni sans owner, ex: `helm-charts`                           | Utiliser la forme complète `owner/repo`                                        |

## Notes de sécurité

- La clé privée est longue durée, utilisable hors GitHub Actions, et mint des tokens pour tous les dépôts sur lesquels l'App est installée. Sa portée est **plus étroite qu'un PAT classique** mais **plus large que `GITHUB_TOKEN`** — installer aussi restrictivement que possible et garder la clé dans le moins de dépôts possible.
- Les tokens sont mintés par job, scopés au dépôt courant, et réduits avec `permission-*` à ce dont ce job a besoin. Ils ne sont jamais écrits dans `GITHUB_OUTPUT`, `GITHUB_ENV`, ni dans les outputs de job.
- Les pull requests venant de forks ne reçoivent aucun secret du dépôt, donc aucun credential App ne peut atteindre un build déclenché par un fork.
- Pour renouveler la clé : en générer une seconde, mettre à jour le secret, puis supprimer la première. Les deux sont valides entre-temps, donc pas d'interruption de service.
