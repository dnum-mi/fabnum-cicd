# `release-npm.yml`

Installe les dépendances, construit le paquet (optionnel) et publie un ou plusieurs paquets sur n'importe quel registre compatible NPM.

Supporte les runtimes Node.js et Bun, tous les gestionnaires de paquets majeurs (npm, yarn, pnpm, bun) et tout registre — npmjs.org, GitHub Packages ou un hôte personnalisé.

## Inputs

| Input             | Type    | Description                                                                                                | Requis | Défaut                       |
| ----------------- | ------- | ---------------------------------------------------------------------------------------------------------- | ------ | ---------------------------- |
| RUNTIME           | string  | Runtime JavaScript (`node` ou `bun`). Vide = auto-détection                                                 | Non    | `""`                         |
| RUNTIME_VERSION   | string  | Version du runtime. Vide = défaut par runtime (Node.js 24, Bun latest)                                      | Non    | -                            |
| PACKAGE_MANAGER   | string  | Gestionnaire de paquets (`npm`, `yarn`, `pnpm`, `bun`). Vide = auto-détection                               | Non    | `""`                         |
| WORKING_DIRECTORY | string  | Répertoire de travail pour l'installation, le build et la publication                                       | Non    | `.`                          |
| REGISTRY_URL      | string  | URL du registre NPM                                                                                         | Non    | `https://registry.npmjs.org` |
| SCOPE             | string  | Scope du registre NPM (ex. `@my-org`). Laisser vide pour un paquet sans scope.                              | Non    | -                            |
| PRE_COMMAND       | string  | Commande shell exécutée à la racine du dépôt avant install/build (ex. build des dépendances d'un monorepo)  | Non    | -                            |
| BUILD_COMMAND     | string  | Commande shell de build du paquet (exécutée dans `WORKING_DIRECTORY`)                                       | Non    | -                            |
| PUBLISH_COMMAND   | string  | Commande de publication personnalisée (remplace la publication auto-détectée). Exécutée dans `WORKING_DIRECTORY` | Non | -                        |
| TAG               | string  | Dist-tag NPM de la version publiée (ex. `latest`, `beta`, `next`)                                           | Non    | `latest`                     |
| ACCESS            | string  | Niveau d'accès du paquet (`public` ou `restricted`)                                                         | Non    | `public`                     |
| DRY_RUN           | boolean | Publication à blanc (validation sans envoi)                                                                 | Non    | `false`                      |
| FAIL_ON_ERROR     | boolean | Faire échouer le workflow en cas d'erreur de publication                                                    | Non    | `true`                       |
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                      | Non    | `["ubuntu-24.04"]`           |

## Secrets

| Secret    | Description                                                                                                                                                                                             | Requis |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| NPM_TOKEN | Token d'authentification du registre NPM. Optionnel si le registre a configuré la publication de confiance (OIDC) pour le workflow appelant - voir [Publication de confiance](#publication-de-confiance-oidc). | Non |

## Permissions

| Scope    | Accès | Description                                                          |
| -------- | ----- | -------------------------------------------------------------------- |
| contents | read  | Checkout du dépôt                                                     |
| id-token | write | Émission du token OIDC pour la publication de confiance (npm, pnpm)   |

## Notes

- L'authentification passe par la variable d'environnement `NODE_AUTH_TOKEN`, alimentée par `NPM_TOKEN` — le mécanisme standard compris par npm, yarn, pnpm et bun.
- Avec le runtime **Node.js**, `actions/setup-node` crée automatiquement l'entrée d'authentification `.npmrc` à partir de `REGISTRY_URL` et `SCOPE`.
- Avec le runtime **Bun**, l'URL du registre et le token sont écrits manuellement dans le `.npmrc` utilisateur (puis supprimés en fin de job), `actions/setup-node` n'étant pas invoqué — cela couvre le registre par défaut comme les registres scopés. Bun est installé dès que `PACKAGE_MANAGER: bun` est utilisé, même avec `RUNTIME: node`. Bun n'a pas de support OIDC ([oven-sh/bun#24855](https://github.com/oven-sh/bun/issues/24855)) : sans `NPM_TOKEN`, la publication bascule de façon transparente sur la CLI npm, qui gère l'échange OIDC — l'installation et le build restent sous bun.
- **Auto-détection** (à la [`@antfu/ni`](https://github.com/antfu-collective/ni)) : quand `PACKAGE_MANAGER`/`RUNTIME` sont vides, le workflow remonte de `WORKING_DIRECTORY` vers la racine du checkout, en cherchant à chaque niveau le champ corepack `packageManager` de `package.json` d'abord, puis les fichiers de lock (`bun.lockb`/`bun.lock` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm), avec npm en dernier recours. Un job scopé sur un paquet de monorepo (`WORKING_DIRECTORY: packages/my-lib`) détecte donc le gestionnaire depuis le lock de la racine du workspace. Le runtime résolu est Bun quand le gestionnaire détecté est bun, sinon Node.js. Renseignez les inputs explicitement pour passer outre. Le gestionnaire détecté sélectionne aussi l'étape de publication correspondante.
- **pnpm/yarn** sont installés automatiquement via Corepack quand le gestionnaire détecté est `pnpm` ou `yarn` ; la version épinglée dans le champ `packageManager` de `package.json` (le cas échéant) est utilisée. Yarn Berry (`.yarnrc.yml`) installe avec `--immutable`, classique avec `--frozen-lockfile`.
- L'étape de publication `yarn` utilise `yarn npm publish` (Yarn Berry / v2+).
- `pnpm publish` est appelé avec `--no-git-checks` pour ne pas exiger un état git propre en CI.
- `PRE_COMMAND` s'exécute à la **racine du dépôt** avec `NODE_AUTH_TOKEN` défini — utile pour construire des paquets partagés du workspace avant publication. `BUILD_COMMAND` s'exécute dans `WORKING_DIRECTORY`.
- `PUBLISH_COMMAND` remplace entièrement l'étape de publication auto-détectée — la bonne option pour Turborepo, Lerna ou tout outillage de release personnalisé.
- `DRY_RUN` ajoute `--dry-run` à la commande de publication pour valider le packaging sans envoi. Note : `yarn npm publish` (Yarn Berry) ne supporte pas `--dry-run`, donc `DRY_RUN: true` n'est pas supporté avec `PACKAGE_MANAGER: yarn`.
- `FAIL_ON_ERROR: false` est utile quand certains paquets d'une matrice sont peut-être déjà publiés.
- Les caches de dépendances sont indexés par gestionnaire de paquets, OS, architecture et le hash combiné de tous les fichiers de lock.
- `FAIL_ON_ERROR` est appliqué par une étape de contrôle explicite en fin de job, pas par `continue-on-error`. Une expression à cet endroit (<span v-pre>`${{ !inputs.FAIL_ON_ERROR }}`</span>) se résout silencieusement à `true` même quand l'input est défini, ce qui neutralise le contrôle — l'étape échoue, le job réussit, et la seule trace est une annotation `failure` dans le résumé du run. Rapports, artefacts et nettoyage s'exécutent avant le contrôle.

### Publication de confiance (OIDC)

npm et pnpm supportent la [publication de confiance](https://docs.npmjs.com/trusted-publishers/) : publier via un token OIDC éphémère plutôt qu'un `NPM_TOKEN` longue durée. Pour l'utiliser :

1. Sur npmjs.com, configurez un trusted publisher pour le paquet pointant vers votre dépôt et **le fichier de workflow d'entrée réellement déclenché par GitHub** (ex. `.github/workflows/cd.yml`) — pas ce `release-npm.yml` réutilisable. npm valide le workflow appelant qui a démarré le run, pas les workflows réutilisables qu'il appelle.
2. Accordez `id-token: write` au job appelant (dans votre `cd.yml`) — ce workflow le demande déjà en interne, mais les deux sont requis car les permissions doivent être explicites à chaque niveau d'une chaîne d'appel de workflows réutilisables.
3. Omettez le secret `NPM_TOKEN`, ou gardez-le en repli — la CLI npm (≥ 11.5.1, livrée avec Node.js 24+) tente OIDC d'abord et ne bascule sur un token statique que si OIDC n'est pas disponible.
4. Le support OIDC de pnpm est plus récent et a connu des régressions sur certaines versions (voir [pnpm#11513](https://github.com/pnpm/pnpm/issues/11513)) — épinglez une version `packageManager` connue comme fonctionnelle et vérifiez une vraie publication avant de vous y fier exclusivement.
5. bun n'a pas de support OIDC ([oven-sh/bun#24855](https://github.com/oven-sh/bun/issues/24855)) : avec `PACKAGE_MANAGER: bun` et sans `NPM_TOKEN`, ce workflow publie via la CLI npm au lieu de `bun publish` — aucun changement côté appelant au-delà de la suppression du secret.

Si vous migrez un paquet existant d'un token vers la publication de confiance, pensez à mettre à jour le chemin de workflow enregistré du trusted publisher chaque fois que le fichier d'entrée change (ex. après migration de la CI/CD vers des workflows réutilisables).

## Exemples

### Publication simple sur npmjs.org

Installe les dépendances avec npm et publie le paquet à la racine du dépôt.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      id-token: write
    with:
      WORKING_DIRECTORY: .
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Publication de confiance (sans token)

Une fois un trusted publisher configuré sur npmjs.com pour ce dépôt et ce fichier de workflow appelant (voir [Publication de confiance](#publication-de-confiance-oidc)), le secret `NPM_TOKEN` peut être supprimé — `id-token: write` suffit.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      id-token: write
    with:
      WORKING_DIRECTORY: .
```

### Monorepo : build des dépendances partagées puis publication

Construit d'abord un paquet partagé du workspace (`PRE_COMMAND` à la racine), puis installe et construit le paquet cible avant publication.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      id-token: write
    with:
      RUNTIME: bun
      RUNTIME_VERSION: 1.3.10
      PACKAGE_MANAGER: bun
      PRE_COMMAND: bun run build --filter=@my-org/shared
      BUILD_COMMAND: bun run build
      WORKING_DIRECTORY: ./packages/my-lib
      TAG: latest
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Publication sur GitHub Packages

Pointez `REGISTRY_URL` vers GitHub Packages et passez `github.token` comme secret. La permission `packages: write` est requise sur le job appelant.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      packages: write
      id-token: write
    with:
      REGISTRY_URL: "https://npm.pkg.github.com"
      SCOPE: "@my-org"
      TAG: latest
    secrets:
      NPM_TOKEN: ${{ github.token }}
```

### Prérelease avec validation à blanc

Publie sous le dist-tag `beta`. `DRY_RUN: true` valide le packaging sans envoi — utile avant la vraie release.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      id-token: write
    with:
      TAG: beta
      DRY_RUN: true
      ACCESS: public
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Commande de publication personnalisée (Turborepo / Lerna)

Quand un outil de release gère la publication, remplacez entièrement l'étape par défaut via `PUBLISH_COMMAND`.

```yaml
jobs:
  release-npm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-npm.yml@v0
    permissions:
      contents: read
      id-token: write
    with:
      PUBLISH_COMMAND: "npx turbo publish --filter=./packages/*"
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```
