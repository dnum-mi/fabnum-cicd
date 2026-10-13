# `update-helm-chart.yml`

Incrémente la version d'un chart Helm selon **son propre cycle de release** (logique compatible release-please, prereleases comprises), en injectant éventuellement une nouvelle `appVersion`. Le chart doit se trouver dans le dépôt qui appelle ce workflow. Deux modes de livraison :

- **`called`** - met à jour le chart via une Pull Request, éventuellement fusionnée automatiquement. C'est le mode qu'exécute un dépôt chart lorsqu'il reçoit un dispatch de [`dispatch-helm-chart.yml`](./54-dispatch-helm-chart.md).
- **`local`** - incrémente le chart et commit directement sur la branche courante, en exposant la nouvelle version en output. Conçu pour les **monorepos** où le chart est hébergé aux côtés de l'application et où le bump a lieu en cours de pipeline (à enchaîner avec [`release-helm-local.yml`](./52-release-helm-local.md) pour le publier dans le même run).

La version du chart et la version de l'application sont **volontairement découplées** : une release applicative incrémente le chart (patch/prerelease) et met à jour `appVersion`, alors qu'un changement du chart seul (laisser `APP_VERSION` vide) incrémente le chart sans toucher à `appVersion`.

> **Chart dans un dépôt séparé ?** Appelez [`dispatch-helm-chart.yml`](./54-dispatch-helm-chart.md) depuis le dépôt applicatif. Il déclenche le workflow d'entrée du dépôt chart, qui appelle celui-ci en mode `called`.

> **Quel mode, où ?** Le dépôt qui *héberge le chart* choisit le style de release : `called` = passage par une PR (style release-please), `local` = direct dans le pipeline. Les deux styles fonctionnent à l'identique, que le chart soit dans un monorepo ou dans un dépôt de chart dédié.

## Inputs

| Input                 | Type   | Description                                                                                                                                                                                                                                                                                                       | Requis | Défaut             |
| --------------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| RUN_MODE              | string | Mode de livraison du bump : `called` (ouvre une Pull Request) ou `local` (commit directement sur la branche courante). Une valeur non reconnue fait échouer le job                                                                                                                                               | Oui    | -                  |
| CHART_NAME            | string | Nom du chart à mettre à jour, sous forme de dossier dans `CHART_DIR`. À renseigner, ou `CHART_PATH`                                                                                                                                                                                                              | Non    | -                  |
| CHART_PATH            | string | Chemin du dossier du chart (celui qui contient `Chart.yaml`), ex: `deploy/helm`, pour un chart dont le dossier ne porte pas le nom. Le nom du chart - utilisé pour la branche, le titre de la PR et le commit - est lu dans `Chart.yaml` et doit être un nom de chart Helm valide. À renseigner, ou `CHART_NAME` ; `CHART_DIR` est ignoré quand il est défini | Non    | -                  |
| CHART_DIR             | string | Nom du dossier contenant les charts Helm                                                                                                                                                                                                                                                                          | Non    | `charts`           |
| APP_VERSION           | string | Version de l'application à injecter dans `Chart.yaml` (`appVersion`). Laisser vide pour conserver l'`appVersion` actuelle (release "chart-only"). Quand il est renseigné, doit respecter `^[A-Za-z0-9][A-Za-z0-9.+_-]*$`                                                                                          | Non    | -                  |
| UPGRADE_TYPE          | string | Partie SemVer à incrémenter : `auto` (défaut - dérive le niveau du delta d'appVersion, voir [Mode `auto`](#mode-auto)), `major`, `minor`, `patch` ou `prerelease`                                                                                                                                                 | Non    | `auto`             |
| PRERELEASE_IDENTIFIER | string | Identifiant de pré-release, utilisé quand le bump entre dans le flux prerelease - `UPGRADE_TYPE: prerelease`, ou `auto` avec une `APP_VERSION` en pré-release (ex: `rc`). Doit respecter `^[A-Za-z0-9-]+$`                                                                                                      | Non    | `rc`               |
| HELM_DOCS_VERSION     | string | Release de helm-docs qui régénère le README du chart, sous forme de tag. Compilée depuis les sources à exactement cette version et vérifiée contre la base de checksums Go ; `latest` est refusé                                                                                                                  | Non    | `v1.14.2`          |
| AUTOMERGE_PRERELEASE  | bool   | Fusionner automatiquement la PR quand le bump est une pré-release (mode `called`)                                                                                                                                                                                                                                 | Non    | `false`            |
| AUTOMERGE_RELEASE     | bool   | Fusionner automatiquement la PR quand le bump n'est pas une pré-release (mode `called`)                                                                                                                                                                                                                           | Non    | `false`            |
| AUTOMERGE_METHOD      | string | Méthode de fusion de la PR quand l'automerge est activé : `auto` (file d'attente jusqu'au passage des checks requis, nécessite **Allow auto-merge**) ou `admin` (fusion immédiate, en contournant la protection de branche)                                                                                       | Non    | `auto`             |
| BASE_BRANCH           | string | Branche de base contre laquelle ouvrir la Pull Request de mise à jour du chart (mode `called`)                                                                                                                                                                                                                    | Non    | `main`             |
| RUNS_ON               | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                                                                                           | Non    | `["ubuntu-24.04"]` |

## Secrets

| Secret          | Description                                                                                                                                                                                                                       | Requis | Défaut |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| APP_CLIENT_ID   | **Client ID** d'une GitHub App (pas l'App ID numérique). Avec `APP_PRIVATE_KEY`, authentifie comme une GitHub App - prend le pas sur `GH_PAT`. Voir [Authentification](./05-authentication.md)                                     | Non    | -      |
| APP_PRIVATE_KEY | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`                                                                                                                                                                    | Non    | -      |
| GH_PAT          | Personal Access Token GitHub. Alternative historique, toujours supportée (voir [Configuration du token](#configuration-du-token))                                                                                                 | Non    | -      |

> **L'automerge dépend des inputs `AUTOMERGE_*`, pas des credentials.** Ajouter des credentials App n'active jamais la fusion à lui seul. Si l'automerge est activé et qu'aucun credential n'est fourni, le job échoue plutôt que de silencieusement ne rien fusionner.

## Outputs

| Output                 | Description                                                              |
| ---------------------- | ------------------------------------------------------------------------ |
| chart-version          | Nouvelle version du chart calculée par le bump                           |
| previous-chart-version | Version du chart avant le bump                                           |
| commit-sha             | SHA du commit de bump poussé sur la branche courante (mode `local` uniquement) |

## Permissions

| Scope         | Accès | Description                                                          |
| ------------- | ----- | -------------------------------------------------------------------- |
| contents      | write | Commiter le chart et sa documentation modifiés (les deux modes)     |
| pull-requests | write | Créer et fusionner la PR de mise à jour du chart (mode `called`)    |

> **Mode `local`** : les deux scopes doivent être accordés, alors que ce mode n'utilise pas `pull-requests: write`. Le `permissions:` d'un job ne peut pas dépendre d'un input, et garder les deux modes dans un seul job est ce qui évite de dupliquer la centaine de lignes de calcul de version dans un second fichier. Le surplus porte sur votre propre dépôt, en plus du `contents: write` déjà nécessaire pour pousser.

> **Credential du push (mode `local`)** : suit la même précédence que partout ailleurs dans ce catalogue - le token de la App s'il est configuré (`APP_CLIENT_ID`/`APP_PRIVATE_KEY`), sinon `GITHUB_TOKEN`. Ce n'est pas un simple détail d'authentification : `GITHUB_TOKEN` ne peut redéclencher aucun workflow, ce qui évite au pipeline appelant de se re-déclencher lui-même, alors qu'un token de App le peut. Fournir `APP_CLIENT_ID`/`APP_PRIVATE_KEY` à un appel en mode `local` change donc ce comportement - à ne faire qu'après avoir vérifié que ce re-déclenchement est sans danger pour votre pipeline (ex : votre job de release est idempotent sur un re-run sans changement), typiquement parce que vous avez besoin de l'identité App pour une autre raison - par exemple un ruleset de branche qui exige une Pull Request pour tout push, sans exception pour `GITHUB_TOKEN` : ce dernier ne peut pas être nommé dans une liste de bypass, contrairement à une GitHub App (`actor_type: Integration`). `GH_PAT` ne fait volontairement **pas** partie de cette précédence : en fournir un pour le mode `called` laisse donc les push du mode `local` sur `GITHUB_TOKEN`.

## Configuration du token

Un credential est nécessaire pour l'**automerge**, et recommandé en mode `called` pour que la Pull Request de mise à jour du chart exécute réellement sa CI. Utilisez soit une **GitHub App** (préférée), soit un **Personal Access Token**, stocké en secret du dépôt dans ce dépôt.

### GitHub App (recommandé)

Renseignez `APP_CLIENT_ID` et `APP_PRIVATE_KEY`. Au-delà de l'automerge, la Pull Request de mise à jour du chart déclenche alors aussi les workflows `pull_request`, ce que `GITHUB_TOKEN` ne peut pas faire - voir [Authentification](./05-authentication.md).

Permissions de dépôt requises pour la App : **Contents: Read & Write, Pull requests: Read & Write, Metadata: Read**, installée sur le dépôt **courant**.

`APP_CLIENT_ID` et `APP_PRIVATE_KEY` doivent être fournis **ensemble**. N'en renseigner qu'un seul fait échouer le job plutôt que de retomber sur `GH_PAT` ou `GITHUB_TOKEN`, ce qui authentifierait silencieusement comme autre chose que la App.

### Comportement de l'automerge

Le token sert à `gh pr merge --rebase`, avec la méthode choisie par `AUTOMERGE_METHOD` :

- `auto` (défaut) met la PR en file d'attente et laisse GitHub la fusionner une fois tous les checks requis passés. Cela nécessite que **Settings > General > Allow auto-merge** soit activé sur le dépôt.
- `admin` fusionne immédiatement, en contournant la protection de branche et les checks requis.

Il n'y a **aucun repli automatique** de l'une vers l'autre. Si `auto` est sélectionné et que l'auto-merge n'est pas activé, le job échoue avec un message nommant le réglage à activer - se rabattre sur `--admin` fusionnerait au-delà des checks mêmes que l'authentification App fait exécuter.

### Fine-grained PAT

Créez un [fine-grained personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) limité à ce dépôt, avec :

| Permission    | Accès        | Raison                                                     |
| ------------- | ------------ | ---------------------------------------------------------- |
| Contents      | Read & Write | Requis par `gh pr merge`                                   |
| Pull requests | Read & Write | Activer l'auto-merge sur la PR de mise à jour du chart     |

> Si le dépôt n'a **pas** "Allow auto-merge" activé, le propriétaire du PAT doit être **administrateur du dépôt** pour que la fusion `--admin` réussisse.

### Classic PAT

Créez un [classic token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) avec le scope **`repo`**.

### Où le stocker

Ajoutez le token comme **secret de dépôt** nommé `GH_PAT` dans ce dépôt :  
**Settings > Secrets and variables > Actions > New repository secret**

## Notes

- `RUN_MODE=called` : lit la `version` actuelle du chart dans `<CHART_DIR>/<CHART_NAME>/Chart.yaml` (via `yq`), calcule `NEXT_VERSION` avec une logique compatible Release Please, met à jour `version` (et `appVersion` quand `APP_VERSION` est fourni), régénère la documentation avec `helm-docs`, puis crée/met à jour une PR contenant le bump.
- `RUN_MODE=local` : même bump que `called`, mais **commit directement sur la branche courante** au lieu d'ouvrir une PR, et expose les outputs `chart-version` / `commit-sha` pour que les jobs suivants du même pipeline puissent publier le chart (à enchaîner avec le `CHECKOUT_REF` de [`release-helm-local.yml`](./52-release-helm-local.md)). Remarques :
  - Le push est authentifié avec `GITHUB_TOKEN`, et ces push **ne déclenchent jamais de nouveau workflow** - pas de boucle de CD ; publiez le chart dans le même run à l'aide des outputs. Un `git pull --rebase` préalable tolère les push concurrents d'autres jobs du même pipeline. Ce commit ne porte volontairement pas de marqueur skip-ci : `GITHUB_TOKEN` suffit déjà à empêcher la boucle, et le marqueur supprimerait aussi les checks `pull_request` d'une pull request qu'un humain ouvrirait ensuite depuis cette branche (ex : une promotion manuelle `develop` → `main`).
  - Les push directs exigent que la branche les accepte (pas de règle de protection "require a pull request" pour `github-actions[bot]`) ; si votre branche est protégée, utilisez le mode `called` avec automerge.
  - Laissez `APP_VERSION` vide pour une **release "chart-only"** (incrémente `version`, conserve `appVersion`).
- Une valeur de `RUN_MODE` non reconnue **fait échouer le job** plutôt que de ne rien faire silencieusement.
- **Logique de bump de version** (compatible Release Please) :
  - `major` : `1.2.3` → `2.0.0`
  - `minor` : `1.2.3` → `1.3.0`
  - `patch` : `1.2.3` → `1.2.4`
  - `prerelease` : `1.2.3` → `1.2.4-rc` → `1.2.4-rc.1` → `1.2.4-rc.2` (depuis une version stable, le patch est d'abord incrémenté, puis le compteur de prerelease)
  - **Changement d'identifiant** : si l'identifiant actuel est différent de celui demandé (ex: `1.0.0-alpha.2` avec identifier `beta`), il est remplacé par le nouvel identifiant sans numéro (ex: `1.0.0-beta`)
  - **Version actuelle en prerelease avec `major`/`minor`/`patch`** : publie d'abord la version officielle (ex: `1.2.3-rc.1` → `1.2.3`)
- **Automerge (mode `called`)** : si `AUTOMERGE_PRERELEASE: true` (quand le bump est une pré-release) ou `AUTOMERGE_RELEASE: true` (sinon), le workflow fusionne automatiquement la PR. La distinction porte sur le flux **résolu**, pas sur l'entrée `UPGRADE_TYPE` : sous `auto`, un bump rc est bien traité comme une pré-release. Il ne dépend que de ces inputs - fournir des credentials ne l'active jamais à lui seul, et si aucun credential n'est fourni le job **échoue** plutôt que de passer silencieusement.
  - `AUTOMERGE_METHOD: auto` (défaut) utilise `gh pr merge --auto` ; la fusion a lieu une fois les checks requis passés. Nécessite *Allow auto-merge* sur le dépôt, et échoue en nommant ce réglage s'il est désactivé.
  - `AUTOMERGE_METHOD: admin` utilise `gh pr merge --admin` pour fusionner immédiatement, en contournant la protection de branche et les checks requis.
  - Il n'y a **aucun repli automatique** de l'une vers l'autre.
  - La stratégie de fusion est `--rebase`.
- **Injection** : `APP_VERSION` et `PRERELEASE_IDENTIFIER` sont écrits dans `Chart.yaml` avec `yq` + `strenv()`, jamais avec `sed` - ils ne peuvent donc être que stockés, jamais interprétés. Ils sont en plus validés en début de job.
- La documentation du chart est régénérée avec la version de helm-docs fixée par `HELM_DOCS_VERSION`.
- Schéma de nommage de la branche (mode `called`) : `<chart-name>-v<NEXT_VERSION>`.
- Outils requis : `yq`, et Go (installé par le workflow) pour compiler `helm-docs`.

### Mode `auto`

`UPGRADE_TYPE: auto` fait refléter au chart le bump de l'application, au lieu d'un niveau figé par l'appelant :

- **Le niveau** est dérivé du delta d'appVersion - ce que `Chart.yaml` contient avant la mise à jour comparé à `APP_VERSION` (majeur différent → `major`, mineur différent → `minor`, sinon `patch`). La comparaison porte sur la base `X.Y.Z` seule.
- **Le flux** est choisi par la forme d'`APP_VERSION` : une prerelease (ex: `0.3.0-rc.1`) entre ou continue le cycle rc du chart, une version stable applique le bump classique (ou retire le suffixe si le chart est en cycle). Une seule valeur couvre donc les deux branches d'un pipeline à deux branches - plus besoin de conditionner sur `github.ref_name`.

| Chart actuel (version / appVersion) | `APP_VERSION` | Résultat | Pourquoi |
| --- | --- | --- | --- |
| `0.2.8` / `0.2.2` | `0.2.3-rc` | `0.2.9-rc` | delta patch, entrée en cycle |
| `0.2.8` / `0.2.2` | `0.3.0-rc` | `0.3.0-rc` | delta minor, le cycle s'ouvre au bon niveau |
| `0.3.0-rc` / `0.3.0-rc` | `0.3.0-rc.1` | `0.3.0-rc.1` | itération du cycle |
| `0.2.9-rc.2` / `0.2.3-rc.1` | `0.3.0-rc.1` | `0.3.0-rc.2` | escalade en cours de cycle : la base monte, le compteur est conservé tel quel - la même règle que release-please applique à l'application |
| `0.3.0-rc.2` / `0.3.0-rc.2` | `0.3.0` | `0.3.0` | promotion : le niveau est déjà dans la base, on retire le suffixe |
| `0.3.0` / `0.3.0` | `0.3.1` | `0.3.1` | hotfix direct sur la branche de release |

Quand il n'y a pas de delta à lire, `auto` retombe sur un bump `patch` avec un avertissement plutôt que d'échouer - c'est la valeur par défaut, elle ne peut pas exiger ce que l'appelant n'a pas fourni :

- `APP_VERSION` vide (release chart-only) : bump `patch`, avec un avertissement suggérant un niveau explicite.
- `appVersion` actuelle non-semver (ex: `latest`, courant sur un chart antérieur au pipeline) : bump `patch` pour ce run ; le run écrit une vraie version dans `appVersion`, donc le delta est dérivable dès le run suivant. Le flux suit toujours la forme d'`APP_VERSION` : une pré-release ne produira jamais une version stable du chart.

Seule une `APP_VERSION` fournie mais non-semver fait échouer le run : cette valeur-là vient de l'appelant sur ce run précis.

## Exemples

> Ces exemples utilisent des credentials GitHub App, le mode recommandé. Pour utiliser un personal access token à la place, remplacez les deux lignes `APP_*` par <span v-pre>`GH_PAT: ${{ secrets.GH_PAT }}`</span> - rien d'autre ne change. Voir [Authentification](./05-authentication.md) pour la mise en place complète de l'un ou l'autre.

### Mode called

Exécute la mise à jour de version dans le dépôt courant. Lit `charts/my-service/Chart.yaml`, incrémente `version` d'un cran minor, positionne `appVersion: 1.4.0`, régénère la documentation avec `helm-docs` et ouvre une PR avec les changements.

```yaml
jobs:
  bump-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-service
      APP_VERSION: 1.4.0
      UPGRADE_TYPE: minor
```

### Mode called – avec automerge

Identique à ci-dessus, mais avec `AUTOMERGE_RELEASE: true` pour fusionner automatiquement la PR une fois les checks passés. Nécessite un credential - App ou PAT - et *Allow auto-merge* activé sur le dépôt, sauf si `AUTOMERGE_METHOD: admin` est positionné.

```yaml
jobs:
  bump-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-service
      APP_VERSION: 1.4.0
      UPGRADE_TYPE: minor
      AUTOMERGE_RELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Mode called – bump prerelease

`UPGRADE_TYPE: prerelease` incrémente la version de prerelease du chart (`1.2.3` → `1.2.4-rc` → `1.2.4-rc.1` → `1.2.4-rc.2` : depuis une version stable, le patch est d'abord incrémenté, puis le compteur). `APP_VERSION` est écrit tel quel dans `appVersion` ; seul le champ `version` du chart suit la logique de bump prerelease.

```yaml
jobs:
  bump-chart-prerelease:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: my-service
      APP_VERSION: 1.4.0-rc.1
      UPGRADE_TYPE: prerelease
      PRERELEASE_IDENTIFIER: rc
      AUTOMERGE_PRERELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Mode local – pipeline monorepo

Le chart est hébergé dans le même dépôt que l'application. Une fois la version applicative publiée par `release-app`, le chart est incrémenté **selon son propre cycle de vie** (`prerelease` sur `develop`, `patch` sur `main` - le passage de `x.y.z-rc.n` à `x.y.z` est automatique), commité directement sur la branche, puis publié sur le registre OCI dans le même run par `release-helm-local`.

```yaml
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
    if: ${{ needs.release.outputs.release-created == 'true' }}
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: local
      CHART_NAME: my-service
      # UPGRADE_TYPE par défaut ('auto') : le chart reflète le bump de
      # l'application, dérivé du delta d'appVersion, et la forme d'APP_VERSION
      # choisit le flux (cycle rc ou release) - identique sur les deux branches.
      APP_VERSION: ${{ needs.release.outputs.version }}

  release-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm-local.yml@v0
    needs:
    - bump-chart
    permissions:
      contents: read
      packages: write
    with:
      CHART_NAME: my-service
      # Package exactement le commit de bump poussé par le job précédent
      CHECKOUT_REF: ${{ needs.bump-chart.outputs.commit-sha }}
```

Pour une **release "chart-only"** (correctif du chart sans release applicative), appelez la même paire `bump-chart` + `release-chart` avec `APP_VERSION` omis - voir [Release d'un monorepo](./90-monorepo-release.md) pour le pipeline monorepo complet.
