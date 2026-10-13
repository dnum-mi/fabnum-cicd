# `release-helm.yml`

Publication des charts Helm via [`chart-releaser-action`](https://github.com/helm/chart-releaser-action), qui détecte automatiquement les charts dont la version a changé depuis le dernier tag git et les package. Deux **canaux de distribution indépendants** peuvent ensuite être activés - voir [Canaux de distribution](#canaux-de-distribution) :

- `CREATE_GITHUB_RELEASE` (**`true` par défaut**) - attacher les packages à une GitHub Release par chart et maintenir un dépôt Helm classique (`index.yaml`) sur une branche de pages.
- `PUBLISH_OCI` (`false` par défaut) - pousser les packages sur un registre OCI (ex: `ghcr.io`).

**Au moins un doit être activé**, sinon le run échoue. Le canal classique est actif par défaut parce que ce workflow s'adresse à un **dépôt de charts dédié**, où les tags git appartiennent aux charts : c'est la sortie native de `chart-releaser`, et la seule consommable par n'importe quel Helm 3. Elle suppose en revanche que la `PAGES_BRANCH` (`gh-pages` par défaut) **existe déjà** - voir [Prérequis de la branche de pages](#prérequis-de-la-branche-de-pages), et [Dépôt privé : préférer le canal OCI](#dépôt-privé--préférer-le-canal-oci) avant de l'activer sur un dépôt privé.

Pour un **monorepo** - un chart hébergé aux côtés du code applicatif, où l'espace de tags est dominé par les tags de l'application et où la détection de changement de chart-releaser (basée sur le "dernier tag") devient peu fiable - utilisez [`release-helm-local.yml`](./52-release-helm-local.md) à la place. Les deux sont des workflows séparés plutôt qu'un seul avec un switch de mode : chacun ne déclare que les permissions dont sa propre logique a besoin, pour qu'un appelant monorepo n'ait jamais à accorder `contents: write` pour un chemin de code chart-releaser qu'il n'exécutera jamais. Voir [`release-helm-local.yml`](./52-release-helm-local.md#pourquoi-un-workflow-séparé) pour le raisonnement complet.

## Inputs

| Input                 | Type    | Description                                                                                                                                                                                                                                    | Requis | Défaut              |
| --------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------- |
| CHARTS_DIR            | string  | Répertoire contenant les charts Helm                                                                                                                                                                                                           | Non    | `./charts`          |
| CREATE_GITHUB_RELEASE | boolean | Créer une GitHub Release et un tag git pour chaque chart modifié, et mettre à jour `index.yaml` sur la branche `PAGES_BRANCH`. Nécessite que cette branche existe déjà. Canal par défaut d'un dépôt de charts dédié.                           | Non    | `true`              |
| PUBLISH_OCI           | boolean | Pousser les charts packagés sur le registre OCI (voir `REGISTRY`/`REPOSITORY`). Indépendant de `CREATE_GITHUB_RELEASE` ; au moins un des deux doit être activé.                                                                                | Non    | `false`             |
| PAGES_BRANCH          | string  | Branche recevant `index.yaml` quand `CREATE_GITHUB_RELEASE` est `true`. Doit déjà exister.                                                                                                                                                     | Non    | `gh-pages`          |
| SKIP_EXISTING         | boolean | Laisser en l'état une version de chart déjà publiée au lieu de faire échouer le run - voir [Charts sans changement de version](#charts-sans-changement-de-version).                                                                            | Non    | `false`             |
| SIGN_CHART            | boolean | Signer chaque chart packagé avec GPG, produisant le fichier `.prov` que `helm verify` contrôle. Nécessite `CREATE_GITHUB_RELEASE`, `SIGNING_KEY_ID` et les secrets GPG - voir [Signature](#signature).                                          | Non    | `false`             |
| SIGNING_KEY_ID        | string  | Identité de la clé GPG de signature, telle qu'elle apparaît dans le trousseau (ex: `Jane Doe <jane@example.com>`). Requis avec `SIGN_CHART`.                                                                                                   | Non    | -                   |
| HELM_REPOS            | string  | Dépôts Helm à ajouter pour résoudre les dépendances des charts (format: `name=url`, séparés par des virgules). Ignoré si vide.                                                                                                                 | Non    | -                   |
| REGISTRY              | string  | Registre OCI pour publier les charts (ex: `ghcr.io`, `registry.gitlab.com`)                                                                                                                                                                    | Non    | `ghcr.io`           |
| REPOSITORY            | string  | Chemin du repository dans le registre OCI (défaut: `github.repository`)                                                                                                                                                                        | Non    | `github.repository` |
| RUNS_ON               | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                         | Non    | `["ubuntu-24.04"]`  |

## Secrets

| Secret            | Description                                                                                                                                                                                                                  | Requis |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| REGISTRY_USERNAME | Nom d'utilisateur pour l'authentification au registre OCI (`github.actor` automatiquement pour `ghcr.io`). **Requis** avec `PUBLISH_OCI: true` quand `REGISTRY` n'est pas `ghcr.io`.                                           | Non    |
| REGISTRY_PASSWORD | Mot de passe pour l'authentification au registre OCI (`GITHUB_TOKEN` automatiquement pour `ghcr.io`). **Requis** avec `REGISTRY_USERNAME` dans les mêmes conditions.                                                           | Non    |
| APP_CLIENT_ID     | **Client ID** d'une GitHub App (pas l'App ID numérique). Avec `APP_PRIVATE_KEY`, chart-releaser authentifie comme une GitHub App. Voir [Authentification](./05-authentication.md).                                             | Non    |
| APP_PRIVATE_KEY   | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`.                                                                                                                                                              | Non    |
| GH_PAT            | Personal Access Token, utilisé pour le même usage que les credentials App ci-dessus et résolu après eux.                                                                                                                     | Non    |
| GPG_PRIVATE_KEY   | Clé privée GPG au format ASCII-armored, utilisée pour signer les packages de charts. Requis avec `SIGN_CHART`.                                                                                                                | Non    |
| GPG_PASSPHRASE    | Passphrase de `GPG_PRIVATE_KEY`. Ne passer une valeur vide que si la clé n'en a réellement aucune.                                                                                                                            | Non    |

> **Pourquoi fournir des credentials App ici.** Les releases créées avec `GITHUB_TOKEN` ne peuvent pas déclencher de triggers `release:` - c'est la règle anti-récursion de GitHub. Si un workflow doit s'exécuter à la publication d'une release de chart, chart-releaser a besoin d'un token App. Sinon, `GITHUB_TOKEN` suffit.
>
> `cr index --push` authentifie le push sur `PAGES_BRANCH` avec le même token : un token App ou `GH_PAT` permet donc aussi à **ce** push de déclencher des workflows. Sans conséquence tant qu'aucun workflow ne se déclenche sur la branche de pages - à vérifier avant d'en pointer un dessus.
>
> Le token App n'est généré que lorsque `CREATE_GITHUB_RELEASE` est `true` - à `false`, rien dans le run n'écrit avec ce token (chart-releaser se contente de packager, et le push OCI s'authentifie auprès du registre), il n'y a donc rien à faire pour un token en écriture.
>
> `APP_CLIENT_ID` et `APP_PRIVATE_KEY` doivent être fournis **ensemble**. N'en renseigner qu'un seul fait échouer le job plutôt que de retomber sur `GH_PAT` ou `GITHUB_TOKEN`.

## Permissions

| Scope    | Accès | Description                                                                                                                                  |
| -------- | ----- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| packages | write | Pousser les charts vers le registre OCI (`ghcr.io`) quand `PUBLISH_OCI` est `true`                                                           |
| contents | write | Créer les releases/tags et mettre à jour `index.yaml` quand `CREATE_GITHUB_RELEASE` est `true` (sans risque de l'accorder systématiquement s'il est `false`) |

> **À propos de la permission inutilisée.** Le workflow déclare les deux scopes sur son job, et la clé `permissions:` de GitHub Actions n'accepte aucune expression - `packages: write` est donc accordé même avec `PUBLISH_OCI: false`, où rien ne l'utilise. La restreindre imposerait de séparer les deux canaux dans deux fichiers de workflow, doublant leur nombre pour retirer un scope qu'aucune étape n'appelle dans cette configuration.

## Canaux de distribution

Le workflow package les charts une fois et peut les diffuser par deux canaux, activables indépendamment :

| | `CREATE_GITHUB_RELEASE` (défaut `true`) | `PUBLISH_OCI` (défaut `false`) |
| --- | --- | --- |
| Côté consommateur | `helm repo add <nom> https://<owner>.github.io/<repo>` | `helm pull oci://<registre>/<repo>/<chart>` |
| Nécessite | n'importe quel Helm 3 | Helm 3.8+ |
| Prérequis dépôt | la `PAGES_BRANCH` (défaut `gh-pages`) doit déjà exister | aucun |
| Charts privés | les assets de release suivent la visibilité du dépôt, mais le site Pages est public - voir plus bas | authentification au registre |
| Permission utilisée | `contents: write` | `packages: write` |
| [Releases immuables](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) | **incompatible** - voir l'avertissement plus bas | compatible (ne crée aucune release GitHub) |

Activer les deux est possible et publie les mêmes packages par les deux chemins.

**Les deux laissés à `false` font échouer le run.** Le workflow packagerait sinon les charts, ne les publierait nulle part, et signalerait malgré tout un succès - un run vert n'ayant rien livré est plus difficile à repérer qu'un run rouge, donc l'étape de validation l'arrête d'emblée avec un message nommant les deux inputs. `CREATE_GITHUB_RELEASE` étant à `true` par défaut, atteindre ce cas suppose de l'avoir explicitement désactivé sans activer l'autre canal.

> **Et en monorepo ?** [`release-helm-local.yml`](./52-release-helm-local.md) est le pendant pour un chart hébergé aux côtés du code applicatif, et n'expose aucun de ces deux inputs : l'OCI y est le seul canal possible. Les GitHub Releases et les tags git y appartiennent à l'application, le chart ne peut donc pas les revendiquer.

### Prérequis de la branche de pages

`CREATE_GITHUB_RELEASE` étant actif par défaut, `chart-releaser` pousse `index.yaml` sur `PAGES_BRANCH` (`gh-pages` par défaut) et **ne la crée pas** - `cr index --push` échoue purement et simplement si elle est absente ([chart-releaser-action#111](https://github.com/helm/chart-releaser-action/issues/111)). Sur un dépôt neuf, il faut la créer une fois :

```sh
git switch --orphan gh-pages
git commit --allow-empty -m "chore: initialise the helm repo pages branch"
git push -u origin gh-pages
```

Puis, pour que `helm repo add https://<owner>.github.io/<repo>` réponde, activer GitHub Pages sur cette branche dans *Settings > Pages*. Sans branche de pages, préférez le canal OCI seul (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`).

### Dépôt privé : préférer le canal OCI

> [!WARNING]
> **Un site GitHub Pages est public même quand son dépôt est privé.** Activer Pages sur un dépôt de charts privé publie donc `index.yaml` - le catalogue des noms, versions et descriptions de vos charts - sur l'internet ouvert. Restreindre l'accès à un site Pages n'est possible qu'avec **GitHub Enterprise Cloud** ; Pages sur un dépôt privé demande déjà au minimum **GitHub Pro**.

Les `.tgz` eux-mêmes restent privés (ce sont des assets de release, ils suivent la visibilité du dépôt), mais c'est aussi ce qui rend le canal classique peu pratique ici : l'index est servi depuis `<owner>.github.io` et les packages depuis `github.com/<owner>/<repo>/releases/download/...`, deux hôtes différents, donc les credentials attachés à l'entrée `helm repo add` ne suivent pas jusqu'au téléchargement du chart.

Sur un dépôt privé, trois options, par ordre de préférence :

1. **Canal OCI seul** (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`) - le package ghcr.io suit la visibilité du dépôt, les consommateurs s'authentifient avec `helm registry login ghcr.io` puis `helm pull oci://ghcr.io/<owner>/<repo>/<chart> --version X`. Aucun prérequis de branche, aucune exigence de plan. Nécessite Helm 3.8+.
2. **Canal classique avec une branche de pages non publiée** - `PAGES_BRANCH` n'est qu'un nom de branche : rien n'oblige à activer Pages dessus. Pointer `PAGES_BRANCH: charts-index` et laisser *Settings > Pages* désactivé donne les GitHub Releases, les tags git et un `index.yaml` lisible seulement avec un accès au dépôt - au prix du `helm repo add https://...`, qui n'existe plus.
3. **Canal classique avec Pages activé** - uniquement si l'exposition publique du catalogue est acceptable, ou sous GitHub Enterprise Cloud avec un site en accès restreint.

> Les deux canaux ne se découplent pas plus finement : `chart-releaser-action` ne conditionne `cr index` qu'à `skip_upload`, lequel supprime aussi `cr upload`. Créer les GitHub Releases sans pousser d'`index.yaml` n'est donc pas exprimable - d'où l'option 2, qui pousse l'index sur une branche que personne ne sert.

## Outputs

| Output           | Description                                                                                                                                                                                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| published-charts | Tableau JSON des charts poussés sur le registre OCI - `{name, version, repository, digest}` par entrée. Tableau vide si `PUBLISH_OCI` est `false` ou si aucun chart n'a changé ; une version laissée en l'état car déjà publiée (`SKIP_EXISTING`) n'y figure pas |

`repository` et `digest` sont gardés séparés pour être transmis tels quels à [`attest-helm.yml`](./56-attest-helm.md), qui les passe comme sujet à cosign et comme couple `subject-name`/`subject-digest` attendu par `actions/attest-build-provenance` - la même forme que `attest-docker.yml` consomme pour les images. Le nom et la version sont relus depuis la sortie de `helm push` plutôt qu'extraits du nom de fichier du package, qui ne peut pas être découpé de façon fiable : une version de prerelease contient elle-même des tirets (`my-chart-1.2.3-rc.1.tgz`).

## Charts sans changement de version

chart-releaser package tous les charts dont les **fichiers** ont changé depuis le dernier tag - y compris un README corrigé ou un commentaire dans `values.yaml` - que leur `version` ait été incrémentée ou non. Un tel chart porte une version déjà publiée, et la suite est au choix de l'appelant :

| | `SKIP_EXISTING: false` (défaut) | `SKIP_EXISTING: true` |
| --- | --- | --- |
| Canal classique | le run échoue : la GitHub Release de cette version existe déjà | la release est laissée en l'état (le `skip-existing` propre à chart-releaser) |
| Canal OCI | le run échoue, **avant qu'aucun chart ne soit poussé** | la version est laissée en l'état, les autres charts sont poussés |
| `published-charts` | - | ne liste pas la version laissée en l'état |

Le canal OCI ne pousse jamais par-dessus une version que le registre détient déjà, dans aucun des deux modes : un consommateur épingle un chart par sa version, et la [signature](./56-attest-helm.md) est liée au digest poussé en premier, donc pousser à nouveau changerait silencieusement le sens de cette version et orphelinerait sa signature. Chaque package est recherché dans le registre (`helm show chart oci://…/<name> --version <version>`) avant tout push, si bien qu'un run ne peut pas publier la moitié de ses charts, et seul un "not found" explicite laisse passer un push - une réponse telle que *denied*, *rate limited* ou *unreachable* arrête le run au lieu d'être lue comme "non publié". Cela vaut aussi avec `SKIP_EXISTING` : il laisse une version en l'état quand le registre dit qu'elle est présente, pas quand le registre n'a pas pu être interrogé.

Un dépôt de chart dédié veut généralement `SKIP_EXISTING: true`, pour qu'un merge touchant un chart sans le publier ne produise pas un run rouge. Une version ignorée ne figurant pas dans `published-charts`, [`attest-helm.yml`](./56-attest-helm.md) ne la signe pas une seconde fois.

## Signature

Les deux canaux sont signés par des mécanismes différents, complémentaires plutôt qu'alternatifs :

| | `SIGN_CHART: true` (ici) | [`attest-helm.yml`](./56-attest-helm.md) |
| --- | --- | --- |
| Produit | un fichier de provenance GPG `.prov` | signatures cosign et/ou provenance SLSA dans le registre |
| Couvre | le canal GitHub Release / `helm repo add` | le canal OCI |
| Vérifié avec | `helm verify`, `helm install --verify` | `cosign verify` / `gh attestation verify` |
| Gestion de clé | votre clé GPG, en secrets du dépôt | keyless - aucune clé à détenir |

**`SIGN_CHART` nécessite `CREATE_GITHUB_RELEASE`.** Le fichier `.prov` est publié comme asset de release ; `helm push` ne l'emporte pas vers un registre OCI, donc sur le seul canal OCI il serait généré puis silencieusement jeté. Le workflow échoue plutôt que de laisser faire - utilisez `attest-helm.yml` pour le côté OCI.

```yaml
with:
  CREATE_GITHUB_RELEASE: true
  SIGN_CHART: true
  SIGNING_KEY_ID: "Jane Doe <jane@example.com>"
secrets:
  GPG_PRIVATE_KEY: ${{ secrets.GPG_PRIVATE_KEY }}
  GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
```

Exportez la clé avec `gpg --armor --export-secret-keys <key-id>` et stockez-la dans `GPG_PRIVATE_KEY`. Les consommateurs vérifient avec `helm verify my-chart-1.2.3.tgz` après avoir importé la clé publique correspondante.

Toute pièce manquante fait échouer le run en amont plutôt que de produire des charts non signés : chart-releaser ne considère pas une clé absente comme fatale, il package simplement sans signature - un `GPG_PRIVATE_KEY` vide, un `SIGNING_KEY_ID` vide ou une clé qui ne s'exporte pas arrêtent donc le run.

## Notes

- **Comportement de `CREATE_GITHUB_RELEASE`** : à `true`, crée une GitHub Release et un tag git pour chaque chart modifié et met à jour `index.yaml` sur la branche de pages (ex: `gh-pages`) ; cela **exige que cette branche de pages existe déjà**. À `false`, aucune branche GitHub Pages n'est nécessaire.
- **Comportement de `PUBLISH_OCI`** : à `true`, se connecte à `REGISTRY` et pousse chaque chart packagé. À `false`, l'étape de login est entièrement ignorée : aucun credential de registre n'est lu ni nécessaire.
- **Les credentials de registre sont validés en amont** : avec `PUBLISH_OCI: true` et un `REGISTRY` autre que `ghcr.io`, l'absence de `REGISTRY_USERNAME`/`REGISTRY_PASSWORD` fait échouer le run avec un message explicite, plutôt que d'atteindre `helm registry login` avec un mot de passe vide et d'échouer sur une erreur d'authentification opaque.
- **Les credentials sont effacés ensuite** : une étape `helm registry logout` s'exécute dès lors que le login a réussi, y compris après un push en échec. Les runners hébergés étant éphémères, c'est sans effet chez eux, mais `RUNS_ON` supporte aussi les runners self-hosted, où la config de registre de Helm survivrait au job.
- **`HELM_REPOS` est optionnel** : l'étape d'ajout des dépôts est ignorée quand `HELM_REPOS` est vide. Renseignez-le quand vos charts tirent des dépendances de dépôts externes.
- **Normalisation du nom de repository** : le chemin du repository OCI est automatiquement normalisé pour être compatible avec les registres OCI :
  - Les majuscules sont converties en minuscules
  - Les underscores (`_`) sont remplacés par des tirets (`-`)
  - Exemple : `My-Org/My_Charts` → `my-org/my-charts`
- Détecte les charts via `git diff` depuis le dernier tag git : un chart dont **un** fichier a changé est packagé, que la version de son `Chart.yaml` ait été incrémentée ou non - voir [Charts sans changement de version](#charts-sans-changement-de-version) pour le sort d'une version déjà publiée. Nécessite des versions de chart SemVer et `fetch-depth: 0` (le workflow le positionne).
- Les charts peuvent être récupérés via : `helm pull oci://ghcr.io/<owner>/<repo>/<chart-name> --version <version>`

> [!WARNING]
> **`CREATE_GITHUB_RELEASE: true` n'est pas compatible avec les [*immutable releases*](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).** `chart-releaser` crée la release GitHub puis attache le `.tgz` du chart en deux appels API distincts, sans possibilité de passer par un brouillon ; sur un dépôt en releases immuables le second appel est rejeté et la release reste incomplète. Le support côté amont est suivi dans [helm/chart-releaser#591](https://github.com/helm/chart-releaser/issues/591).
>
> Le canal OCI seul (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`) ne crée aucune release GitHub et n'est donc pas concerné - c'est le canal à utiliser sur un dépôt en releases immuables.

## Exemples

Chaque exemple active au moins un canal de distribution - le workflow échoue si les deux sont laissés à `false`. Ils couvrent l'OCI sur le registre `ghcr.io` par défaut, l'OCI sur un registre personnalisé avec credentials explicites, le dépôt Helm classique GitHub Pages seul, et les deux canaux ensemble.

### Registre OCI (GitHub Packages)

Package les charts modifiés et les pousse sur `ghcr.io`. Aucune branche GitHub Pages nécessaire. Des dépôts externes peuvent être pré-enregistrés via `HELM_REPOS`.

```yaml
jobs:
  release-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      CHARTS_DIR: ./charts
      HELM_REPOS: "bitnami=https://charts.bitnami.com/bitnami,jetstack=https://charts.jetstack.io"
```

### Registre OCI personnalisé

Pour pousser les charts vers un registre autre que `ghcr.io`, fournissez les credentials en secrets - ils sont requis, et le run échoue en amont sans eux :

```yaml
jobs:
  release-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      PUBLISH_OCI: true
      CHARTS_DIR: ./charts
      REGISTRY: registry.example.com
      REPOSITORY: my-org/helm-charts
    secrets:
      REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.REGISTRY_PASSWORD }}
```

### Dépôt Helm classique uniquement (sans OCI)

Crée une GitHub Release et un tag git par chart et maintient un dépôt Helm `index.yaml` sur la branche de pages, sans rien pousser sur un registre OCI. Les consommateurs utilisent `helm repo add`. La `PAGES_BRANCH` (défaut `gh-pages`) **doit déjà exister** dans le dépôt.

```yaml
jobs:
  release-charts:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm.yml@v0
    permissions:
      contents: write
      packages: write
    with:
      CREATE_GITHUB_RELEASE: true
      PAGES_BRANCH: gh-pages
```

### Les deux canaux

Publie les mêmes packages sur le registre OCI *et* via le dépôt classique sur pages :

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
      PAGES_BRANCH: gh-pages
```

### Chart dans un monorepo applicatif

Pour un chart hébergé aux côtés du code applicatif, voir [`release-helm-local.yml`](./52-release-helm-local.md) à la place - un workflow séparé, à permissions minimales, dédié à ce cas.
