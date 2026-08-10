# `sync-prerelease-branch.yml`

Resynchronise la branche de pré-release sur la branche de release après une release, en la rebasant.

Ce workflow maintient un invariant unique :

> **La branche de pré-release, c'est la branche de release plus le seul travail non encore publié.**

## Pourquoi un workflow séparé

Une release dépose sur la branche de release des commits que la branche de pré-release n'a pas :

- `chore(main): release X.Y.Z` de release-please — modifie le manifeste et `CHANGELOG.md`
- `chore(chart): release ...` de [`update-helm-chart.yml`](./update-helm-chart.md) en mode `local` — modifie `Chart.yaml` et le README du chart

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
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                             | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description                                    |
| -------- | ----- | ---------------------------------------------- |
| contents | write | Pousser la branche de pré-release rebasée      |

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
```

### Selon la forme du dépôt

| Forme du dépôt                     | Commits sur la branche de release après le job de release | Ce job     |
| ---------------------------------- | ---------------------------------------------------------- | ---------- |
| Application seule (sans chart)      | aucun                                                      | `needs: [release]` |
| Application + chart local (monorepo) | le bump du chart                                          | `needs: [..., bump-chart-local]` |
| Application + chart distant         | aucun — le bump atterrit dans l'*autre* dépôt              | `needs: [release]` |
| Dépôt de charts seul, mono-branche  | —                                                          | inutile    |

## Filet de sécurité

Oublier ce job, ou oublier une entrée dans son `needs:`, resterait invisible jusqu'à ce qu'une version sorte fausse. [`release-app.yml`](./release-app.md#assertion-de-synchronisation) **assère donc l'invariant** au début de chaque run sur la branche de pré-release, avant tout calcul de version, et échoue en le nommant. Vous n'avez rien à configurer pour cela.

## Notes

- **Ne s'exécute que depuis la branche de release.** Placez le `if:` côté appelant (voir l'exemple) : le job n'a rien à propager quand il tourne depuis la branche de pré-release elle-même.
- **En régime établi, le rebase est un simple fast-forward.** La promotion ayant versé les commits de la branche de pré-release dans la branche de release, `RELEASE_BRANCH..PRERELEASE_BRANCH` est vide et rien n'est rejoué. Le rebase ne fait un vrai travail que si la branche de pré-release a bougé pendant la release — possible dès que le `concurrency` de l'appelant est indexé sur la branche — et c'est précisément le cas qu'un `git push` simple rejetterait.
- **Cela suppose que la promotion préserve les commits** (merge ou rebase-merge). Un **squash** de `PRERELEASE_BRANCH` → `RELEASE_BRANCH` casse cette propriété : les commits d'origine ne sont plus des ancêtres, le rebase les rejoue tous, et les conflits deviennent la norme.
- **Un conflit fait échouer le job** plutôt que de laisser la branche périmée : la régression de version serait sinon silencieuse.
- **Le push utilise le `GITHUB_TOKEN` du checkout**, qui ne peut pas déclencher de workflow. Déplacer la branche de pré-release ne relance donc pas la CD de l'appelant. Ne fournissez pas de token App ni de PAT à ce workflow.
- `RELEASE_BRANCH` et `PRERELEASE_BRANCH` doivent différer — sinon le job échoue plutôt que de rebaser une branche sur elle-même sans jamais rien synchroniser.
