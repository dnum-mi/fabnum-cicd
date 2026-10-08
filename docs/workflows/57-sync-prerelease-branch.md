# `sync-prerelease-branch.yml`

Resynchronise la branche de pré-release sur la branche de release après une release, en la rebasant.

Ce workflow maintient un invariant unique :

> **La branche de pré-release, c'est la branche de release plus le seul travail non encore publié.**

## Pourquoi un workflow séparé

Une release dépose sur la branche de release des commits que la branche de pré-release n'a pas :

- `chore(main): release X.Y.Z` de release-please — modifie le manifeste et `CHANGELOG.md`
- `chore(chart): release ...` de [`update-helm-chart.yml`](./53-update-helm-chart.md) en mode `local` — modifie `Chart.yaml` et le README du chart

La branche de pré-release modifie **ces mêmes fichiers** sur son propre cycle `rc`. Si elle ne les reçoit jamais, les deux branches écrivent des lignes concurrentes depuis un ancêtre commun, et deux choses cassent :

1. Les versions calculées sur la branche de pré-release partent d'une base périmée — et peuvent tomber **sous** la version déjà publiée.
2. Le rebase suivant et la promotion suivante entrent en conflit sur ces fichiers.

La seule chose qui détermine le bon moment pour resynchroniser est « la branche de release a-t-elle fini de bouger ? », et **seul le graphe de jobs de l'appelant le sait**. C'est pourquoi c'est un job que vous placez en dernier, et non un input sur un workflow qui ne voit pas ce graphe : cette seconde forme est silencieusement fausse dès qu'un pipeline commite sur la branche de release après son job de release — un bump de chart en monorepo, typiquement.

## Inputs

| Input             | Type    | Description                                                                                                                                        | Requis | Défaut             |
| ----------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| RELEASE_BRANCH    | string  | Branche sur laquelle les releases sont créées, et branche **source** de la synchronisation                                                          | Non    | `main`             |
| PRERELEASE_BRANCH | string  | Branche sur laquelle les pré-releases sont créées, et branche synchronisée                                                                         | Non    | `develop`          |
| CREATE_IF_MISSING | boolean | Créer `PRERELEASE_BRANCH` depuis `RELEASE_BRANCH` si elle n'existe pas encore, plutôt que de ne rien faire. Amorce un dépôt adoptant le flux à deux branches. | Non    | `true`             |
| PRERELEASE_CONFIG_FILE | string | Config release-please de la branche de pré-release, **même valeur que l'input de [`release-app.yml`](./50-release-app.md)**. Elle liste les fichiers que release-please réécrit et porte l'ancre ([voir plus bas](#ancre-de-release-please-après-un-rebase)) | Non | `release-please-config-rc.json` |
| PRERELEASE_MANIFEST_FILE | string | Manifeste release-please de la branche de pré-release, même valeur que l'input de `release-app.yml` | Non | `.release-please-manifest-rc.json` |
| RELEASE_MANIFEST_FILE | string | Manifeste release-please de la branche de release, même valeur que l'input de `release-app.yml` | Non | `.release-please-manifest.json` |
| MANAGED_FILES     | string  | Fichiers qu'une release réécrit sur la branche de release et que la branche de pré-release réécrit aussi sur son propre cycle, un chemin ou glob par ligne, en plus de ceux que la config release-please liste déjà (manifestes, changelogs, `extra-files`) : le fichier de version que le `release-type` bump lui-même (`version.txt` pour `simple`, `package.json` pour `node`, `Chart.yaml` pour `helm`), et `Chart.yaml` et le README du chart quand le chart est dans le dépôt. Voir [Conflits sur les fichiers réécrits par les releases](#conflits-sur-les-fichiers-réécrits-par-les-releases) | Non | vide |
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                             | Non    | `["ubuntu-24.04"]` |

## Secrets

Aucun n'est requis : par défaut le push part avec le `GITHUB_TOKEN` du job.

| Secret          | Description                                                                                                           | Requis |
| --------------- | --------------------------------------------------------------------------------------------------------------------- | ------ |
| APP_CLIENT_ID   | Client ID de la GitHub App (`Iv23li...`, pas l'App ID numérique). À fournir avec `APP_PRIVATE_KEY`                     | Non    |
| APP_PRIVATE_KEY | Clé privée de la GitHub App (PEM). Requise avec `APP_CLIENT_ID`                                                       | Non    |

Les fournir fait partir le push avec un token App, voir [Quand les rulesets rejettent `GITHUB_TOKEN`](#quand-les-rulesets-rejettent-github_token). N'en fournir qu'un seul des deux fait échouer le job plutôt que de retomber silencieusement sur `GITHUB_TOKEN`.

## Permissions

| Scope    | Accès | Description                                    |
| -------- | ----- | ---------------------------------------------- |
| contents | write | Pousser la branche de pré-release rebasée      |

Avec une App, le token minté est réduit à `contents: write` sur le dépôt courant.

## Quand les rulesets rejettent `GITHUB_TOKEN`

Le push (création de la branche de pré-release, ou `--force-with-lease` après le rebase) est soumis aux rulesets de cette branche. Un ruleset qui exige une pull request pour tout push, interdit les push non fast-forward, impose un historique linéaire ou des checks requis — y compris à la création — rejette `GITHUB_TOKEN`, qui ne peut pas être nommé dans une liste de bypass. Seule une GitHub App peut l'être.

Dans ce cas, fournissez `APP_CLIENT_ID` / `APP_PRIVATE_KEY` d'une App présente dans la liste de bypass :

```yaml
  sync-prerelease-branch:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-prerelease-branch.yml@v0
    # needs, if, permissions, with: comme ci-dessus
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

**Contrepartie : le push peut déclencher la CD de l'appelant.** Un token App, contrairement à `GITHUB_TOKEN`, déclenche les workflows. Déplacer la branche de pré-release démarre donc les workflows qui s'exécutent sur elle. Ne le faites que si un run de la CD sur cette branche, qui ne trouve rien de nouveau à publier, est sans danger pour votre pipeline — ce qui est le cas de release-please, idempotent.

## Où le placer

**En dernier**, avec un `needs:` listant **exactement** les jobs qui commitent sur la branche de release — tous ceux-là, et rien d'autre. C'est la seule règle.

En oublier un laisse la branche de pré-release périmée. En ajouter un qui ne commite rien ne la rend pas plus juste : cela permet seulement à l'échec de ce job de faire sauter la synchronisation.

```yaml
  sync-prerelease-branch:
    uses: dnum-mi/fabnum-cicd/.github/workflows/sync-prerelease-branch.yml@v0
    needs:
    - release            # commite `chore(main): release ...`
    - bump-chart-local   # commite `chore(chart): release ...`
    # build-docker et release-charts sont volontairement absents : ils ne
    # commitent rien, et les lister laisserait un build ou une publication en
    # échec sauter la synchronisation. L'ordre tient quand même, bump-chart-local
    # dépendant déjà de build-docker.
    if: ${{ github.ref_name == 'main' && needs.release.outputs.release-created == 'true' }}
    permissions:
      contents: write
    with:
      RELEASE_BRANCH: main
      PRERELEASE_BRANCH: develop
      # Mêmes valeurs que celles passées à release-app.yml
      PRERELEASE_CONFIG_FILE: .github/releases/release-please-config-prerelease.json
      PRERELEASE_MANIFEST_FILE: .github/releases/.release-please-manifest-prerelease.json
      RELEASE_MANIFEST_FILE: .github/releases/.release-please-manifest.json
      # Chart dans le dépôt : bump-chart-local réécrit ces fichiers sur la branche de release
      MANAGED_FILES: |
        helm/Chart.yaml
        helm/README.md
```

### Selon la forme du dépôt

| Forme du dépôt                     | Commits sur la branche de release après le job de release | Ce job     |
| ---------------------------------- | ---------------------------------------------------------- | ---------- |
| Application seule (sans chart)      | aucun                                                      | `needs: [release]` |
| Application + chart local (monorepo) | le bump du chart                                          | `needs: [..., bump-chart-local]` |
| Application + chart distant         | aucun — le bump atterrit dans l'*autre* dépôt              | `needs: [release]` |
| Dépôt de charts seul, mono-branche  | —                                                          | inutile    |

## Conflits sur les fichiers réécrits par les releases

Quand la branche de release a avancé (un hotfix et sa release, par exemple), le rebase rejoue le travail non publié par-dessus. Les commits de release de la branche de pré-release — `chore(develop): release 1.1.0-rc.1`, le bump du chart — réécrivent les mêmes lignes que ceux de la branche de release : manifestes, `CHANGELOG.md`, version dans `Chart.yaml`. Ces conflits-là sont structurels : ils portent sur des lignes de bookkeeping dont la bonne valeur est connue d'avance, du côté de la branche de pré-release puisque ses prochaines versions se calculent depuis cet état.

Le job résout donc de lui-même les conflits **limités à ces fichiers** : les deux manifestes, le changelog et les `extra-files` listés dans `PRERELEASE_CONFIG_FILE`, et ce que l'appelant ajoute par `MANAGED_FILES`. La résolution se fait **hunk par hunk** (`git merge-file` sur les trois versions du fichier), pas en prenant un côté entier : ce que la branche de release a changé *hors* des hunks en conflit — une dépendance corrigée par le hotfix dans le même fichier, la section d'un changelog — est conservé. Pour les hunks en conflit :

| Fichier | Côté retenu |
| --- | --- |
| manifeste de pré-release, `extra-files`, fichiers de `MANAGED_FILES` | la branche de pré-release |
| changelog (`changelog-path` de la config, ou tout fichier dont le nom contient `changelog`) | les deux côtés : un historique ne se choisit pas. Les sections de la pré-release vont au-dessus de celles de la branche de release, la plus récente en premier, avec la ligne vide entre sections que le merge supprimerait |
| manifeste de release (`RELEASE_MANIFEST_FILE`) | la branche de release : il consigne ce qu'elle a publié |

**Rien n'est supprimé sans trace.** Prendre un côté supprime les lignes de l'autre dans le hunk en conflit : un correctif sur la très ligne que la branche de pré-release a aussi modifiée disparaîtrait sinon sans laisser de trace. Chaque hunk ainsi tranché est écrit dans le log du job (un groupe nommé d'après le nombre de hunks), signalé en annotation `notice` sur le run, et listé dans le job summary comme un diff : les lignes `-` ont été supprimées, les `+` conservées à leur place, sous un en-tête nommant le fichier, la ligne et le commit rejoué. Pour des lignes de version c'est le remplacement attendu (`- 1.0.1` / `+ 1.1.0-rc.1`) ; tout autre chose mérite d'être lu avant la prochaine promotion. Un changelog garde les deux côtés et ne supprime rien. Le summary liste les 400 premières lignes ; le log les a toutes.

Un conflit sur **tout autre fichier** est du vrai travail à réconcilier à la main : garder silencieusement un côté ferait disparaître le correctif. Le job échoue alors en nommant le fichier, avec le rebase annulé et rien de poussé. Il en va de même quand un fichier a été **supprimé d'un côté** : il n'y a pas de côté à prendre. Les chemins sont lus comme des noms, jamais comme des motifs (un fichier `[id].tsx` ne sélectionne rien d'autre) ; un motif de `MANAGED_FILES` s'applique d'abord comme chemin littéral, puis comme glob.

**release-please réécrit plus que ce que la config nomme.** Le fichier de version du `release-type` — `version.txt` pour `simple`, `package.json` et `package-lock.json` pour `node`, `Chart.yaml` pour `helm` — n'est pas dans `extra-files` : listez-le dans `MANAGED_FILES`, sinon son conflit fait échouer le job (le message d'erreur le dit). Le chart bumpé par [`update-helm-chart.yml`](./53-update-helm-chart.md) est dans le même cas : listez ses fichiers.

## Ancre de release-please après un rebase

Sur la branche de pré-release, release-please part de la release nommée d'après la version du manifeste de pré-release (`1.1.0-rc.1`), retrouvée par son tag, et lit l'historique de la branche jusqu'au commit de ce tag.

Un rebase rejoue les commits sous de nouveaux SHA, ceux de release compris. Le tag, lui, pointe toujours vers le commit d'origine, qui n'est plus dans la branche : release-please ne trouve plus son point d'arrêt, relit les 500 derniers commits et propose une version fausse — un majeur issu d'un vieux commit cassant (`4.0.0-rc.4` au lieu de `3.5.0-rc.5`) — avec un changelog qui répète tout ce qui est déjà publié. Rien ne le dit avant l'ouverture de la PR.

Déplacer le tag n'est pas une option : les registres et miroirs construisent des versions à partir des tags, et une version doit continuer à désigner le commit dont elle a été construite. `last-release-sha` dans la config de pré-release dit à release-please de partir d'un autre commit ; c'est ce que ce job pose, **après chaque rebase qui a fait sortir un tag de la branche** :

1. il lit la version du manifeste de pré-release et retrouve son tag : `v<version>` ou `<version>`, sinon l'unique tag qui se termine par la version (préfixe de composant) ; plusieurs candidats (versions alignées entre chart et application) sont ambigus, le job le signale et ne pose rien ;
2. si ce tag n'est plus dans la branche, il retrouve le commit de release rejoué : même sujet **et même date d'auteur** (un rebase, un cherry-pick et un rebase-merge les conservent), parmi les commits rejoués sur la branche de release ; sinon, après une promotion par rebase-merge qui a copié toute la série sur la branche de release, le rebase ne rejoue rien (tout est déjà en amont) et c'est la copie de ce commit sur la branche de release qui sert ;
3. il commite `chore(develop): anchor release-please on 1.1.0-rc.1`, qui fixe `last-release-sha` à ce commit dans `PRERELEASE_CONFIG_FILE`, avant l'unique push.

La clé doit être dans un commit de la branche : release-please lit sa config sur GitHub, pas dans un espace de travail. Une fois la pré-release suivante taguée, release-please atteint ce tag avant le commit de l'ancre, et la clé devient inerte ; le prochain rebase qui fait sortir un tag la rafraîchit.

- **Un manifeste de pré-release à un seul package.** La clé est un commit pour tout le dépôt : elle ne peut pas servir de point de départ à plusieurs packages. Au-delà, le job le signale et ne pose rien.
- **Idempotent.** Sans nouveau rebase, ou si la clé désigne déjà le commit rejoué, aucun commit n'est ajouté.
- **Un commit d'ancre par rebase qui fait sortir un tag.** Les ancres précédentes sont rejouées avec le reste et s'empilent : un petit commit `chore` de plus à chaque hotfix resynchronisé, qui arrive sur la branche de release à la promotion, où la clé est inerte.
- **`jq` doit être présent sur le runner** (il l'est sur les runners hébergés par GitHub ; à installer sur un runner auto-hébergé).
- **En régime établi, rien à faire** : après une promotion, le manifeste porte la version stable, dont le tag est sur la branche de release.

[`release-app.yml`](./50-release-app.md#ancre-de-release-please) vérifie le résultat à chaque run de pré-release et échoue si ni le tag ni `last-release-sha` ne sont dans la branche.

## Hotfix sur la branche de release

Un correctif urgent suit le flux existant, sans procédure dédiée :

1. Branchez `hotfix/...` depuis la branche de release, corrigez, ouvrez la pull request vers elle et mergez.
2. La CD de la branche de release publie le correctif (ex. `1.4.1`), et ce job resynchronise la branche de pré-release : le rebase rejoue le travail non publié par-dessus le correctif, résout les conflits sur les fichiers de release ([voir plus haut](#conflits-sur-les-fichiers-réécrits-par-les-releases)) et réancre release-please sur le commit de release rejoué ([voir plus haut](#ancre-de-release-please-après-un-rebase)).
3. Au prochain push sur la branche de pré-release, release-please repart de la base corrigée — la pré-release suivante (ex. `1.5.0-rc.2`) contient le correctif, et elle seule figure dans son changelog.

Le seul point de friction possible est un conflit entre le correctif et le travail en cours de la branche de pré-release **sur un fichier qui n'est pas réécrit par les releases** : le job échoue alors explicitement au lieu de laisser la branche périmée (voir Notes), et le conflit se résout à la main une seule fois.

## Filet de sécurité

Oublier ce job, ou oublier une entrée dans son `needs:`, resterait invisible jusqu'à ce qu'une version sorte fausse. [`release-app.yml`](./50-release-app.md#assertion-de-synchronisation) **assère donc l'invariant** au début de chaque run sur la branche de pré-release, avant tout calcul de version, et échoue en le nommant. Une seconde assertion vérifie que le point de départ de release-please est bien dans la branche ([ancre](./50-release-app.md#ancre-de-release-please)), ce qui attrape un job de synchronisation absent ou ancien après un rebase. Vous n'avez rien à configurer pour cela.

## Notes

- **Ne s'exécute que depuis la branche de release.** Placez le `if:` côté appelant (voir l'exemple) : le job n'a rien à propager quand il tourne depuis la branche de pré-release elle-même.
- **En régime établi, le rebase est un simple fast-forward.** La promotion ayant versé les commits de la branche de pré-release dans la branche de release, `RELEASE_BRANCH..PRERELEASE_BRANCH` est vide et rien n'est rejoué. Le rebase ne fait un vrai travail que si la branche de pré-release a bougé pendant la release — possible dès que le `concurrency` de l'appelant est indexé sur la branche — et c'est précisément le cas qu'un `git push` simple rejetterait.
- **Cela suppose que la promotion préserve les commits** — comme ancêtres (merge) ou comme copies patch-identiques (rebase-merge, où le rebase reconnaît chaque commit déjà appliqué et l'écarte). Un **squash** de `PRERELEASE_BRANCH` → `RELEASE_BRANCH` casse cette propriété : les N commits d'origine sont fondus en un seul dont aucun n'est patch-identique, le rebase les rejoue tous, et les conflits deviennent la norme.
- **Le push utilise un lease explicite** sur le sommet de la branche de pré-release lu avant le rebase : un commit arrivé entre-temps est rejeté, pas écrasé. Les tags sont récupérés seuls, sans toucher aux branches de suivi.
- **Un conflit hors fichiers de release fait échouer le job** plutôt que de laisser la branche périmée : la régression de version serait sinon silencieuse. Les conflits sur les fichiers que les releases réécrivent sont, eux, résolus (voir plus haut).
- **Le push utilise par défaut le `GITHUB_TOKEN` du checkout**, qui ne peut pas déclencher de workflow. Déplacer la branche de pré-release ne relance donc pas la CD de l'appelant. Ne fournissez de token App que si un ruleset rejette ce push (voir plus haut). Les PAT ne sont pas acceptés.
- `RELEASE_BRANCH` et `PRERELEASE_BRANCH` doivent différer — sinon le job échoue plutôt que de rebaser une branche sur elle-même sans jamais rien synchroniser.
