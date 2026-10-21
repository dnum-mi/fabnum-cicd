# `release-app.yml`

Crée des releases avec [`release-please`](https://github.com/googleapis/release-please), peut taguer les versions majeure/mineure et supporte l'automerge des PRs générées.

> **Références :** [googleapis/release-please-action](https://github.com/googleapis/release-please-action) · [googleapis/release-please](https://github.com/googleapis/release-please)

## Inputs

| Input                    | Type    | Description                                                                                                                                                                                                                                                          | Requis | Défaut                             |
| ------------------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------------------------- |
| ENABLE_PRERELEASE        | boolean | Activer la fonctionnalité de pré-release                                                                                                                                                                                                                             | Non    | `false`                            |
| TAG_MAJOR_AND_MINOR      | boolean | Taguer les versions majeure et mineure                                                                                                                                                                                                                               | Non    | `false`                            |
| AUTOMERGE_PRERELEASE     | boolean | Fusionner automatiquement la PR de pré-release                                                                                                                                                                                                                       | Non    | `false`                            |
| AUTOMERGE_RELEASE        | boolean | Fusionner automatiquement la PR de release                                                                                                                                                                                                                           | Non    | `false`                            |
| AUTOMERGE_METHOD         | string  | Méthode de fusion de la PR quand l'automerge est activé : `auto` (met en file d'attente, GitHub fusionne une fois les checks requis passés, nécessite **Allow auto-merge** sur le dépôt) ou `admin` (fusionne immédiatement en contournant la protection de branche) | Non    | `auto`                             |
| RELEASE_PR_AUTHOR        | string  | Durcissement optionnel : n'agir que sur les PRs de release ouvertes par ce login — voir [Quelles pull requests sont éligibles](#quelles-pull-requests-sont-éligibles)                                                                                                | Non    | `""`                               |
| PRERELEASE_BRANCH        | string  | Branche sur laquelle créer les pré-releases                                                                                                                                                                                                                          | Non    | `develop`                          |
| RELEASE_BRANCH           | string  | Branche sur laquelle créer les releases                                                                                                                                                                                                                              | Non    | `main`                             |
| RELEASE_CONFIG_FILE      | string  | Fichier de configuration release-please pour la branche de release                                                                                                                                                                                                   | Non    | `release-please-config.json`       |
| RELEASE_MANIFEST_FILE    | string  | Fichier manifest release-please pour la branche de release                                                                                                                                                                                                           | Non    | `.release-please-manifest.json`    |
| PRERELEASE_CONFIG_FILE   | string  | Fichier de configuration release-please pour la branche de pré-release                                                                                                                                                                                               | Non    | `release-please-config-rc.json`    |
| PRERELEASE_MANIFEST_FILE | string  | Fichier manifest release-please pour la branche de pré-release                                                                                                                                                                                                       | Non    | `.release-please-manifest-rc.json` |
| RELEASE_ASSET_PATHS      | string  | Liste de chemins locaux séparés par des virgules à uploader comme assets de release (ex: `dist/app-linux-amd64,dist/app-darwin-amd64`)                                                                                                                               | Non    | -                                  |
| RELEASE_ARTIFACT_NAMES   | string  | Nom ou pattern glob d'artefacts (uploadés par des jobs précédents via `actions/upload-artifact`) à télécharger et attacher à la release (ex: `my-binaries` ou `my-app-*`)                                                                                            | Non    | -                                  |
| PUBLISH_DRAFT_RELEASE    | boolean | Publier la release GitHub une fois les assets attachés. À activer avec `"draft": true` et `"force-tag-creation": true` dans la config release-please pour rester compatible avec les [releases immuables](#compatibilité-avec-les-releases-immuables)                | Non    | `false`                            |
| RUNS_ON                  | string  | Labels des runners au format JSON (ex: `'["ubuntu-24.04"]'` ou `'["self-hosted", "linux"]'`)                                                                                                                                                                         | Non    | `["ubuntu-24.04"]`                 |

## Secrets

| Secret          | Description                                                                                                                                                                             | Requis | Défaut |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| APP_CLIENT_ID   | **Client ID** d'une GitHub App (pas l'App ID numérique). Avec `APP_PRIVATE_KEY`, authentifie comme une App — prend le pas sur `GH_PAT`. Voir [Authentification](./05-authentication.md) | Non    | -      |
| APP_PRIVATE_KEY | Clé privée (PEM) de la GitHub App. Requis avec `APP_CLIENT_ID`                                                                                                                          | Non    | -      |
| GH_PAT          | Personal Access Token GitHub. Alternative historique, toujours supportée (voir [Configuration du token](#configuration-du-token))                                                       | Non    | -      |

> Fournir des credentials App permet à la PR de release de déclencher les workflows `pull_request`, donc à sa CI de tourner réellement — ce que `GITHUB_TOKEN` ne peut pas faire. Cela fait aussi déclencher les triggers `push: tags:` et `release:` par le **tag** et la **release GitHub** créés par release-please, ce que `GITHUB_TOKEN` ne faisait jamais. Vérifiez sur quoi votre pipeline se déclenche avant de basculer. Voir [Authentification](./05-authentication.md).

> `APP_CLIENT_ID` et `APP_PRIVATE_KEY` doivent être fournis **ensemble**. En définir un seul fait échouer le job plutôt que de retomber sur `GH_PAT` ou `GITHUB_TOKEN`.

> **L'automerge dépend des inputs `AUTOMERGE_*`, pas des credentials.** Ajouter des credentials App n'active jamais la fusion à lui seul. Si l'automerge est activé et qu'aucun credential n'est fourni, le job échoue plutôt que de silencieusement ne rien faire.

## Outputs

| Output           | Description                                                                                                                                                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| release-created  | Indique si une release a été créée lors de ce run                                                                                                                                                                                      |
| version          | Version semver complète (ex: `1.2.3`)                                                                                                                                                                                                  |
| major-tag        | Tag de version majeure (ex: `1`)                                                                                                                                                                                                       |
| minor-tag        | Tag de version mineure (ex: `2`)                                                                                                                                                                                                       |
| patch-tag        | Tag de version patch (ex: `3`)                                                                                                                                                                                                         |
| tag-name         | Tag complet créé (ex: `v1.2.3`) - pour un job aval qui doit nommer la release explicitement plutôt que reconstruire le préfixe du tag                                                                                                  |
| releases-created | Indique si au moins une release a été créée - renseigné aussi en mode manifest (monorepo), où `release-created` ci-dessus reste vide pour un dépôt sans package racine                                                                 |
| paths-released   | Tableau JSON des chemins de packages pour lesquels une release a été créée (`[]` si rien n'a été publié) - à passer à une matrice avec `fromJSON`                                                                                      |
| release-outputs  | Tous les outputs de release-please sous forme d'un seul objet JSON, pour les valeurs par chemin (`<path>--tag_name`, `<path>--version`, ...) : `fromJSON(needs.release.outputs.release-outputs)[format('{0}--tag_name', matrix.path)]` |

**Appelants monorepo.** Avec une config manifest contenant un package par répertoire et aucun package racine, les six outputs mono-package restent vides - release-please nomme chaque output d'après le chemin auquel il appartient. Utilisez `releases-created` comme condition, `paths-released` comme matrice et `release-outputs` pour le tag et la version de chaque entrée :

```yaml
  binaries:
    needs: [release]
    if: ${{ needs.release.outputs.releases-created == 'true' }}
    strategy:
      matrix:
        path: ${{ fromJSON(needs.release.outputs.paths-released) }}
    steps:
    - env:
        TAG: ${{ fromJSON(needs.release.outputs.release-outputs)[format('{0}--tag_name', matrix.path)] }}
      run: gh release upload "$TAG" dist/*
```

## Permissions

| Scope         | Accès | Description                                                          |
| ------------- | ----- | -------------------------------------------------------------------- |
| contents      | write | Créer des tags/commits et mettre à jour les fichiers manifest        |
| issues        | write | Créer ou mettre à jour les issues ouvertes par l'outil de release    |
| pull-requests | write | Créer, mettre à jour et fusionner optionnellement les PRs de release |

## Configuration du token

Un credential n'est requis que lorsque `AUTOMERGE_PRERELEASE` ou `AUTOMERGE_RELEASE` est activé. Utilisez soit une **GitHub App** (recommandé), soit un **Personal Access Token**, stocké comme secret du dépôt qui exécute ce workflow.

### GitHub App (recommandé)

Définir `APP_CLIENT_ID` et `APP_PRIVATE_KEY`. Au-delà de l'automerge, cela permet aussi à la PR de release de déclencher les workflows `pull_request`, ce que `GITHUB_TOKEN` ne peut pas faire — voir [Authentification](./05-authentication.md) pour la configuration complète.

Permissions de dépôt requises pour l'App : **Contents: Read & Write**, **Pull requests: Read & Write**, **Issues: Read & Write**, **Metadata: Read**.

### Quelles pull requests sont éligibles

Le nom d'une branche source est choisi par celui qui ouvre la pull request — pour une PR depuis un fork, c'est simplement une branche de son propre dépôt — il identifie donc une pull request mais n'autorise rien. Trois filtres déterminent ce que ce workflow modifie ou fusionne :

1. **Les pull requests depuis un fork sont rejetées d'emblée.** Sans cela, n'importe quel utilisateur GitHub pourrait ouvrir une PR depuis une branche nommée `release-please--branches--main` et la faire fusionner dans votre branche de release — avec `AUTOMERGE_METHOD: admin`, en contournant la protection de branche et tous les checks requis.
2. **La branche doit correspondre exactement**, soit à `release-please--branches--<base>`, soit à `release-please--branches--<base>--components--<name>` — les deux seules formes produites par release-please. Une simple correspondance de préfixe acceptait aussi `release-please--branches--main-anything`.
3. **L'auteur de la pull request doit correspondre**, ce qui ferme le cas restant que la vérification de fork ne couvre pas : quelqu'un ayant un accès en push qui fabrique une branche de forme release-please dans votre propre dépôt.

Les trois sont actifs par défaut et ne demandent aucune configuration. L'auteur est **dérivé du credential qui a ouvert la pull request** :

| Credential     | Auteur attendu par le workflow | Dérivé de                                                             |
| -------------- | ------------------------------ | --------------------------------------------------------------------- |
| GitHub App     | `app/<app-slug>`               | l'output `app-slug` de l'action de token elle-même                    |
| `GITHUB_TOKEN` | `app/github-actions`           | fixe — c'est toujours l'auteur                                        |
| `GH_PAT`       | *(vérification ignorée)*       | l'auteur est le propriétaire du token, ce qui ne peut pas être dérivé |

> Notez le préfixe `app/`. C'est ainsi que l'API rapporte un auteur bot — **pas** `github-actions[bot]`. Définir `RELEASE_PR_AUTHOR: github-actions[bot]` ne correspondrait à rien et arrêterait silencieusement toute fusion.

Ne définissez `RELEASE_PR_AUTHOR` que pour surcharger la dérivation — fixez le login du propriétaire de votre PAT avec `GH_PAT`, ou passez `*` pour désactiver la vérification d'auteur tout en conservant les gardes fork et branche.

**Un tiers peut-il falsifier l'auteur ?** Non. `author.login` est défini par GitHub à partir de l'identité qui a ouvert la pull request ; il n'est pas fourni par l'attaquant. Le `GITHUB_TOKEN` d'un fork est un token d'installation limité à ce fork, il ne peut donc pas ouvrir de pull request dans votre dépôt — et la vérification de fork rejette les pull requests cross-repository avant même d'examiner l'auteur. Les deux gardes sont indépendantes, et la vérification de fork échoue en mode fermé : une pull request dont le statut de fork ne peut être déterminé est refusée plutôt qu'autorisée.

**Ce qui reste.** Quelqu'un qui *a déjà un accès en push* pourrait ajouter un workflow qui fait ouvrir par votre propre bot `github-actions` une pull request sur une branche de forme release-please. Elle passe les trois filtres. `RELEASE_PR_AUTHOR` n'y change rien — l'auteur correspondrait. C'est la frontière de confiance de l'accès en push plutôt que quelque chose que le workflow peut fermer : quiconque peut pousser un workflow peut déjà exécuter du code arbitraire en CI. Si cela compte pour votre dépôt, exigez une revue sur `.github/workflows/**` via CODEOWNERS, et préférez `AUTOMERGE_METHOD: auto` pour que la protection de branche continue de s'appliquer.

### Comment la fusion s'effectue

L'étape d'automerge utilise `gh pr merge --rebase`, avec la méthode choisie par `AUTOMERGE_METHOD` :

- `auto` (par défaut) met la PR en file d'attente et laisse GitHub la fusionner une fois tous les status checks requis passés. Cela nécessite que **Settings > General > Allow auto-merge** soit activé sur le dépôt.
- `admin` force la fusion immédiatement, en contournant la protection de branche et les status checks requis.

Il n'y a **aucun repli automatique de l'un vers l'autre**. Si `auto` est sélectionné et que l'auto-merge n'est pas activé sur le dépôt, le job échoue avec un message nommant le réglage à activer. C'est délibéré : retomber sur `--admin` fusionnerait au-delà des checks mêmes que l'authentification App fait tourner.

L'étape fusionne **toutes** les pull requests release-please ouvertes ciblant la branche courante, ce qui couvre les monorepos utilisant `separate-pull-requests` (une pull request par composant) — pas seulement la première trouvée.

### Fine-grained PAT

Créez un [fine-grained personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) limité au **dépôt courant** avec les permissions suivantes :

| Permission    | Accès        | Raison                                                               |
| ------------- | ------------ | -------------------------------------------------------------------- |
| Contents      | Read & Write | Pousser des commits (synchronisation du manifest, rebase de branche) |
| Pull requests | Read & Write | Activer l'auto-merge sur les PRs de release                          |

> Avec `AUTOMERGE_METHOD: admin`, le propriétaire du PAT doit être **administrateur du dépôt** pour que la fusion forcée réussisse.

### Classic PAT

Vous pouvez aussi créer un [token classic](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) avec le scope **`repo`**.

### Où le stocker

Ajoutez le credential comme **secrets du dépôt** (`APP_CLIENT_ID` + `APP_PRIVATE_KEY`, ou `GH_PAT`) :  
**Settings > Secrets and variables > Actions > New repository secret**

Si les deux sont définis, l'App prend le pas — utile pour vérifier la bascule avant de supprimer le PAT.

## Notes

- Définir `ENABLE_PRERELEASE: false` pour désactiver toute fonctionnalité de pré-release et travailler uniquement avec les branches de release.
- Les fichiers de configuration et manifest sont configurables via les inputs, avec des valeurs par défaut sensées pour les workflows de release et pré-release.
- Sur `RELEASE_BRANCH` (par défaut `main`), utilise les fichiers spécifiés par `RELEASE_CONFIG_FILE` et `RELEASE_MANIFEST_FILE`.
- Sur `PRERELEASE_BRANCH` (par défaut `develop`), utilise les fichiers spécifiés par `PRERELEASE_CONFIG_FILE` et `PRERELEASE_MANIFEST_FILE` (seulement quand `ENABLE_PRERELEASE: true`).
- Si `TAG_MAJOR_AND_MINOR: true`, crée les tags `v<major>` et `v<major>.<minor>` après la création d'une release.
- Si `AUTOMERGE_*` est activé et qu'un credential est fourni, tente de fusionner automatiquement la PR de release.
- **Assère** que `PRERELEASE_BRANCH` contient tout ce qui est publié sur `RELEASE_BRANCH`, avant tout calcul de version — voir [Assertion de synchronisation](#assertion-de-synchronisation). Le rebase lui-même appartient à [`sync-prerelease-branch.yml`](./57-sync-prerelease-branch.md).
- **Assère** que le point de départ de release-please sur `PRERELEASE_BRANCH` est dans la branche — voir [Ancre de release-please](#ancre-de-release-please).
- **N'exécute pas release-please** quand `PRERELEASE_BRANCH` est identique à `RELEASE_BRANCH` — voir [Branche de pré-release identique](#branche-de-pré-release-identique-à-la-branche-de-release).
- **Assère** qu'une PR de release fusionnée devient un tag et une release, et refuse de démarrer tant qu'une PR abandonnée peut l'en empêcher — voir [Assertions de release](#assertions-de-release). Rien à configurer.
- `RELEASE_ASSET_PATHS` uploade des fichiers déjà présents sur le système de fichiers du runner. `RELEASE_ARTIFACT_NAMES` accepte un nom ou un pattern glob — les artefacts correspondants sont téléchargés via `actions/download-artifact` avant d'être attachés à la release ; les deux inputs peuvent être utilisés ensemble.
- `PUBLISH_DRAFT_RELEASE: true` publie la release une fois les assets attachés. Sans effet si la release n'est pas un brouillon, ce qui rend l'étape rejouable. Voir [releases immuables](#compatibilité-avec-les-releases-immuables).

## Assertion de synchronisation

Sur un run de `PRERELEASE_BRANCH` (et seulement avec `ENABLE_PRERELEASE: true`), le workflow vérifie **avant tout calcul de version** que la branche de pré-release contient bien tout ce que la branche de release a publié. Rien à configurer : les deux noms de branches sont déjà des inputs.

C'est l'invariant dont dépend chaque version calculée ici : *la branche de pré-release, c'est la branche de release plus le seul travail non publié*. Quand il tient, release-please et un éventuel bump de chart partent de l'état publié. Quand il ne tient pas, ils partent de l'état où la branche a été figée, et émettent des versions **sous** celles déjà publiées — silencieusement.

Ce qui maintient l'invariant est un job que **l'appelant** ordonnance ([`sync-prerelease-branch.yml`](./57-sync-prerelease-branch.md)), et aucun workflow ne peut vérifier qu'il a bien été câblé. L'assertion attrape donc toutes les façons dont cela peut casser : job absent, `needs:` incomplet, synchronisation en échec, force-push, ou une forme de pipeline que personne n'avait anticipée.

En échec, le run s'arrête avec le nombre de commits manquants et la marche à suivre. Deux causes possibles :

- **Le job de synchronisation manque ou son `needs:` ne couvre pas tout le pipeline.** C'est le cas à corriger.
- **Un pipeline de release tourne encore sur la branche de release.** Le `concurrency` par défaut étant indexé sur la branche, un run de pré-release peut démarrer pendant une release : rejouer le run une fois celle-ci terminée suffit.

> L'assertion repose sur un appel `compare` de l'API GitHub plutôt que sur `git merge-base --is-ancestor` : l'ascendance exige un historique réel, et `actions/checkout` laisse le clone superficiel — la forme git imposerait un `--unshallow` du dépôt à chaque run de pré-release.

> Un dépôt qui n'a pas encore créé `RELEASE_BRANCH` n'a rien à comparer : l'assertion ne fait rien plutôt que de bloquer les premières pré-releases.

## Ancre de release-please

Sur la branche de pré-release, release-please part de la release nommée d'après la version du manifeste de pré-release, retrouvée par son tag, et lit l'historique de la branche jusqu'au commit de ce tag. Après un rebase (typiquement un hotfix sur la branche de release, puis [`sync-prerelease-branch.yml`](./57-sync-prerelease-branch.md)), les commits sont rejoués sous de nouveaux SHA : le tag pointe toujours vers l'ancien commit, qui n'est plus dans la branche. release-please ne trouve plus son point d'arrêt, relit les 500 derniers commits et propose une version fausse — un majeur issu d'un vieux commit cassant, `4.0.0-rc.4` au lieu de `3.5.0-rc.5` — avec un changelog qui répète tout ce qui est déjà publié. Il ne dit rien avant d'ouvrir la PR.

Le workflow vérifie donc, avant release-please, que **l'un des deux** est dans l'historique de la branche :

- le tag de la version du manifeste de pré-release ;
- le commit `last-release-sha` de `PRERELEASE_CONFIG_FILE`, que [`sync-prerelease-branch.yml`](./57-sync-prerelease-branch.md#ancre-de-release-please-après-un-rebase) pose après chaque rebase.

Sinon le run échoue en nommant le tag et le fichier de config. Il y a deux sorties : vérifier que le job `sync-prerelease-branch` de l'appelant reçoit les mêmes `PRERELEASE_CONFIG_FILE` et `PRERELEASE_MANIFEST_FILE` que ce workflow et qu'il a tourné depuis le rebase, ou fixer `last-release-sha` à la main sur le commit de release rejoué. Ne fusionnez jamais la PR de release qu'aurait ouverte un run non asserté, et ne déplacez pas le tag : les registres et miroirs construisent des versions à partir des tags.

Rien à configurer — `PRERELEASE_CONFIG_FILE` et `PRERELEASE_MANIFEST_FILE` sont déjà des inputs. L'assertion ne fait rien quand :

- le manifeste de pré-release n'existe pas encore ;
- le manifeste suit plusieurs packages (`last-release-sha` est un commit pour tout le dépôt) : un avertissement le signale, car le problème reste entier pour eux ;
- aucun tag ne correspond à sa version, ou plusieurs en sont candidats (versions alignées entre chart et application) : un avertissement, release-please a alors sa propre résolution ;
- la branche est identique à la branche de release (voir ci-dessous).

Le commit est vérifié par l'API (`compare`), pour la même raison que la synchronisation : le clone est superficiel. Le tag est `v<version>` ou `<version>`, sinon l'unique tag qui se termine par la version (préfixe de composant), comme dans le job de synchronisation. Si l'API ne répond pas (5xx, limite de débit), le run échoue avec un message distinct plutôt que d'accuser le rebase : relancez-le.

## Branche de pré-release identique à la branche de release

Quand `PRERELEASE_BRANCH` est identique à `RELEASE_BRANCH`, elle ne porte aucun travail propre : il n'y a pas de pré-release à créer, et l'étape release-please est ignorée (ses sorties sont vides, donc "aucune release créée").

C'est l'état d'une synchronisation qui n'a pas eu de commit d'ancre à ajouter (voir [l'ancre](#ancre-de-release-please)). Le push du job de synchronisation, fait avec un token App, démarre un run de la CD sur cette branche ; sans cette règle, release-please y compte comme non publiés sur la ligne de pré-release tous les commits arrivés directement sur la branche de release (un hotfix, un correctif porté à la main) et ouvre une PR `chore(develop): release X.Y.Z-rc` pour du code déjà publié — une PR à ne jamais fusionner, qui devient périmée et conflictuelle dès la release stable. Dès que la branche de pré-release reçoit son premier commit propre, le calcul reprend normalement. L'étape d'automerge est ignorée elle aussi : elle mettrait en file une PR de release périmée que ce run n'a pas rafraîchie.

## Assertions de release

Deux vérifications encadrent release-please, toutes deux inconditionnelles et sans configuration. Elles existent parce que release-please peut pousser un commit de release sur la branche puis échouer à le taguer, et que rien d'autre dans un pipeline de release ne le remarque.

### Avant : aucune PR de release abandonnée

release-please garde une branche par cible — `release-please--branches--<branch>`, plus un suffixe `--components--<name>` par package dans un monorepo — et la réutilise pour chaque pull request de release qu'il ouvre. Une pull request **fermée sur l'une de ces branches tout en portant encore un label `autorelease:`** reste dans la comptabilité de release-please comme *la* pull request de release de cette branche. Le run suivant pousse le nouveau commit de release, ouvre une nouvelle pull request, puis tente de remettre la fermée à l'état ouvert — ce que GitHub refuse, car la nouvelle pull request occupe déjà cette paire head/base :

```
updated code for <new>, but update requested for <closed>
state cannot be changed. There is already an open pull request from
release-please--branches--main to main.
```

L'endroit où release-please s'arrête fait le dégât : **après** avoir poussé le commit de release, **avant** d'avoir labellisé la pull request qu'il vient d'ouvrir. `autorelease: pending` est la file que lit la phase de release, donc une pull request de release sans label lui est invisible — la fusionner ne produit aucun tag.

L'assertion fait échouer le run et nomme la pull request à nettoyer. Retirez-lui tous les labels `autorelease:` ; le correctif tient en un retrait de label, et rien d'autre à propos de la pull request fermée n'importe.

> C'est [googleapis/release-please#2566](https://github.com/googleapis/release-please/issues/2566). Le label `autorelease: snooze` qui produit cet état n'est pas documenté, et le crash survient avant l'écriture de tout tag.

> Une pull request de release fermée ne portant **aucun** label `autorelease:` est l'état de repartir de zéro propre à release-please et passe : il ouvre une nouvelle pull request et ne regarde plus jamais l'ancienne.

### Après : une PR de release fusionnée a bien été publiée

L'invariant que tout le workflow existe pour garantir : quand une pull request de release est fusionnée, la version qu'elle a écrite devient un tag et une release.

Rien d'autre ne l'assère. release-please rapporte `release-created` à false **aussi bien** pour un commit ordinaire que pour un commit de release qu'il n'a pas réussi à taguer, et les jobs aval conditionnés par cet output lisent les deux de la même façon — ils sont ignorés. Les binaires, l'image, le chart et leurs attestations ne sont alors silencieusement pas publiés, alors que le changelog et le manifest de la branche disent que la version a été livrée.

Cela empêche aussi la *prochaine* release d'être calculée. release-please cherche le tag que nomme le manifest ; sans plancher à partir duquel mesurer, il parcourt la branche jusqu'à son premier commit et propose **un changelog couvrant tout l'historique**. Ce symptôme apparaît généralement des jours plus tard, sur un run sans rapport, et se lit comme un tout autre bug.

La récupération suit la [procédure upstream](https://github.com/googleapis/release-please/blob/main/docs/troubleshooting.md) : remettez `autorelease: pending` sur la pull request de release fusionnée et relancez le workflow. release-please la tague alors, la relabellise `autorelease: tagged`, et les jobs aval s'exécutent.

> Indexé sur le commit en cours de build, et non sur « une pull request fusionnée porte-t-elle encore le label pending » : le label est précisément ce qui disparaît dans l'échec ci-dessus, et la fusion d'un run concurrent ferait osciller un balayage de labels. Une pull request de release dont le commit de merge **est** le commit de ce run est sans ambiguïté, que ce soit en rebase, squash ou merge-commit.

> Un run sur un commit de release qu'un run précédent a déjà publié - un re-run, ou un déclenchement manuel du CD de l'appelant sur ce commit - passe : release-please trouve la release en place et ne crée rien, et la pull request de release fusionnée porte `autorelease: tagged`, qui n'est posé qu'une fois la release existante. Une pull request laissée `pending` ou sans label échoue toujours.

> S'exécute sous `!cancelled()`, il rapporte donc aussi un run où release-please a planté sans renseigner aucun output — la façon la plus probable d'arriver ici, et où une erreur brute de validation de l'API est sinon le seul indice.

## Configuration

release-please nécessite un fichier de configuration et un fichier manifest à la racine du dépôt. Le manifest suit la version courante et est mis à jour automatiquement à chaque release.

### Config de release (`release-please-config.json`)

Config minimale pour un dépôt mono-package utilisant le type de release `node` (ajuste la version de `package.json`). Voir la [documentation release-please](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) pour toutes les options et types de release disponibles.

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "node",
      "initial-version": "0.0.1",
      "include-component-in-tag": false,
      "versioning": "prerelease",
      "prerelease": false,
      "prerelease-type": "",
      "extra-files": []
    }
  }
}
```

### Manifest de release (`.release-please-manifest.json`)

Suit la version courante de chaque chemin de package. release-please met ce fichier à jour automatiquement — définissez la version initiale à votre release actuelle.

```json
{
  ".": "0.0.1"
}
```

### Config de pré-release (`release-please-config-rc.json`)

Utilisée quand `ENABLE_PRERELEASE: true`. Structure identique à la config de release, avec en plus `prerelease-type` pour contrôler l'identifiant de pré-release ajouté à la version.

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "node",
  "prerelease-type": "rc",
  "packages": {
    ".": {
      "release-type": "node",
      "initial-version": "0.0.1",
      "include-component-in-tag": false,
      "versioning": "prerelease",
      "prerelease": true,
      "prerelease-type": "rc",
      "extra-files": []
    }
  }
}
```

### Manifest de pré-release (`.release-please-manifest-rc.json`)

```json
{
  ".": "0.0.1"
}
```

## Compatibilité avec les releases immuables

Les [*immutable releases*](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases) gèlent une release GitHub dès sa publication : plus aucun asset ne peut être ajouté, modifié ou supprimé, et le tag associé ne peut plus être déplacé ni supprimé. Le seul ordonnancement supporté est donc **créer en brouillon → attacher les assets → publier**.

Ce n'est un sujet que si vous attachez des assets, via `RELEASE_ASSET_PATHS` ou `RELEASE_ARTIFACT_NAMES`. Sans assets, le workflow est déjà compatible et il n'y a rien à faire.

Trois changements sont nécessaires, dont deux dans votre propre configuration release-please :

```jsonc
{
  "packages": {
    ".": {
      // La release est créée en brouillon : les assets peuvent y être attachés.
      "draft": true,
      // GitHub ne crée pas le tag git tant que le brouillon n'est pas publié.
      // Sans ceci, release-please ne retrouve pas la version précédente.
      "force-tag-creation": true
    }
  }
}
```

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      RELEASE_ARTIFACT_NAMES: my-app-binaries
      PUBLISH_DRAFT_RELEASE: true
```

À noter :

- **`PUBLISH_DRAFT_RELEASE` est un opt-in explicite.** L'option `draft` de release-please sert aussi à publier manuellement une release après relecture ; le workflow ne publie donc jamais un brouillon sans qu'on le lui demande.
- **L'étape est idempotente.** Une release déjà publiée est laissée telle quelle, l'étape est rejouable sans risque.
- **Les évènements `release:` arrivent plus tard.** Un brouillon ne déclenche rien ; `release: published`/`released` part de l'étape de publication, une fois les assets attachés. Vérifiez les triggers de vos workflows consommateurs.
- **Un échec en cours de route laisse un brouillon**, qu'il suffit de publier (`gh release edit <tag> --draft=false`) ou de relancer. C'est précisément ce que cette configuration évite : sans elle, sur un dépôt en releases immuables, un upload d'asset échoué laisse une release publiée incomplète et **irrécupérable**, le nom du tag étant brûlé définitivement même après suppression de la release.
- **Les tags flottants `v<major>`/`v<major>.<minor>` de `TAG_MAJOR_AND_MINOR` ne sont pas concernés** : l'immutabilité ne verrouille que les tags portant une release publiée, et release-please n'en crée que sur `v<major>.<minor>.<patch>`.

> [!WARNING]
> [`release-helm.yml`](./51-release-helm.md) avec `CREATE_GITHUB_RELEASE: true` n'est **pas** compatible avec les releases immuables : `chart-releaser` crée la release puis attache le `.tgz` en deux appels séparés, sans option de brouillon ([helm/chart-releaser#591](https://github.com/helm/chart-releaser/issues/591)). Publier les charts sur un registre OCI à la place (`PUBLISH_OCI: true`, `CREATE_GITHUB_RELEASE: false`) ne crée aucune release GitHub et n'est pas concerné.

## Exemples

Les exemples couvrent les principaux scénarios de release : une configuration complète avec support des pré-releases, un flux release uniquement, et un build qui attache des binaires compilés à la release GitHub.

> Ils utilisent des credentials GitHub App, le mode recommandé. Pour utiliser un personal access token à la place, remplacez les deux lignes `APP_*` par <span v-pre>`GH_PAT: ${{ secrets.GH_PAT }}`</span> — rien d'autre ne change. Les deux peuvent être passés ensemble pendant une migration ; l'App l'emporte. Voir [Authentification](./05-authentication.md) pour la configuration complète de l'un ou l'autre.

### Exemple simple

Configuration complète à deux branches avec `develop` pour les pré-releases et `main` pour les releases stables. `AUTOMERGE_*: true` nécessite des credentials disposant de permissions suffisantes pour contourner les règles de protection de branche. Garder `develop` rebasée sur `main` après chaque release stable est le rôle de [`sync-prerelease-branch.yml`](./57-sync-prerelease-branch.md).

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: true
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_PRERELEASE: true
      AUTOMERGE_RELEASE: true
      # Optionnel : personnaliser les fichiers de config et de manifest
      RELEASE_CONFIG_FILE: custom-release-config.json
      PRERELEASE_CONFIG_FILE: custom-prerelease-config.json
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Workflow release uniquement

Workflow à une seule branche ciblant uniquement `main`. Aucun fichier de config de pré-release n'est requis. `TAG_MAJOR_AND_MINOR: true` ajoute des alias pratiques (`v1`, `v1.2`) à chaque tag de release stable.

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: false
      TAG_MAJOR_AND_MINOR: true
      AUTOMERGE_RELEASE: true
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

### Attacher des artefacts de build à la release

Deux options sont disponibles selon l'endroit où se trouvent les artefacts.

**Option 1 — fichiers sur le système de fichiers du runner** (`RELEASE_ASSET_PATHS`) : à utiliser quand les fichiers sont produits dans le même job (ou déjà présents sur le runner).

```yaml
jobs:
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: false
      RELEASE_ASSET_PATHS: "dist/my-app-linux-amd64,dist/my-app-darwin-amd64"
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

**Option 2 — artefacts d'un job précédent** (`RELEASE_ARTIFACT_NAMES`) : accepte un nom ou un pattern glob — les artefacts correspondants uploadés via `actions/upload-artifact` dans le même run sont téléchargés automatiquement avant d'être attachés à la release.

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v6
    - name: Build
      run: make build
    - uses: actions/upload-artifact@v7
      with:
        name: my-app-binaries
        path: dist/

  release:
    needs: build
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      ENABLE_PRERELEASE: false
      RELEASE_ARTIFACT_NAMES: "my-app-binaries"  # ou un glob comme "my-app-*"
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Les deux inputs peuvent être combinés quand certains fichiers sont locaux et d'autres proviennent de jobs précédents.
