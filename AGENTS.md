# Instructions pour un agent qui consomme ce dépôt

Ce fichier s'adresse à un agent (assistant de code, skill, générateur de pipeline) chargé de mettre en place une CI/CD dans **un autre dépôt** en s'appuyant sur celui-ci. Il ne décrit aucun input : il indique où les lire, pour rester vrai quand les workflows évoluent.

## Ce que le dépôt expose

Des workflows GitHub Actions réutilisables (`on: workflow_call`) dans `.github/workflows/`, et des git hooks dans `git-hooks/`. Rien d'autre : pas d'action composite, pas de template GitLab CI, pas de chart Helm. `ci.yml` et `cd.yml` sont la CI/CD du dépôt lui-même et ne s'appellent pas.

Un dépôt consommateur référence un workflow ainsi :

```yaml
jobs:
  lint-commits:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-commits.yml@<ref>
    permissions:
      contents: read
```

`<ref>` est soit le tag majeur mobile `v0` (convention de la documentation : le consommateur suit les évolutions), soit un tag exact `vX.Y.Z` (reproductible : les montées passent par une PR). Le dépôt est en `0.x` : un `feat` peut changer un défaut sans marqueur *breaking*. Quel que soit le choix, **lire la documentation à la même ref que celle écrite dans le `uses:`**, et ne jamais inventer un numéro de version — le résoudre depuis les releases du dépôt.

## Ordre de lecture pour composer un pipeline

1. [`docs/workflows/01-introduction.md`](./docs/workflows/01-introduction.md) — catalogue des workflows et pipelines complets (CI de pull request, CD de release, charts Helm) à adapter.
2. [`docs/workflows/05-authentication.md`](./docs/workflows/05-authentication.md) — quel credential pour quel besoin (`GITHUB_TOKEN`, GitHub App, `GH_PAT`) et l'ordre de résolution.
3. La fiche `docs/workflows/NN-<workflow>.md` de chaque workflow retenu : inputs, secrets, notes, exemples.
4. Le bloc `on.workflow_call` du fichier `.github/workflows/<workflow>.yml` — **il fait foi** en cas d'écart avec la fiche. Les `description:` des inputs y portent le raisonnement et les contre-indications.
5. [`docs/workflows/90-monorepo-release.md`](./docs/workflows/90-monorepo-release.md) si le dépôt cible publie plusieurs applications ou un chart aux côtés du code.
6. [`CHANGELOG.md`](./CHANGELOG.md) pour les changements de comportement entre deux tags.

## Pièges à ne pas reproduire chez un consommateur

- Le guide monorepo écrit `uses: ./.github/workflows/<x>.yml` parce qu'il décrit ce dépôt. Chez un consommateur, remplacer par `dnum-mi/fabnum-cicd/.github/workflows/<x>.yml@<ref>`.
- Les secrets ne sont pas hérités par un workflow appelé : les câbler explicitement dans `secrets:` de chaque job appelant.
- Les `permissions:` se déclarent sur le job appelant : il faut l'union de celles que déclarent les jobs du workflow appelé, y compris ceux qu'un input désactive — un workflow appelé ne peut pas en obtenir davantage. La fiche la donne quand elle a une section dédiée ; sinon la lire dans le YAML.
- Fournir un seul des deux secrets `APP_CLIENT_ID` / `APP_PRIVATE_KEY` fait échouer le job. L'automerge et le dispatch vers un autre dépôt exigent une App ou un `GH_PAT` : `GITHUB_TOKEN` ne suffit pas.
- Avec `ENABLE_PRERELEASE: true`, `release-app` vérifie que la branche de pré-release contient la branche de release. Le job qui maintient cet invariant, [`sync-prerelease-branch.yml`](./docs/workflows/57-sync-prerelease-branch.md), est à ordonnancer par l'appelant, en dernier, avec exactement le `needs:` que prescrit sa fiche.
- `release-helm` pousse l'index sur la branche de pages (`gh-pages` par défaut) et ne la crée pas.
- `sync-cpin` est le seul pont vers Cloud Pi Natif : il déclenche le pipeline du dépôt miroir GitLab. Ce pipeline, le registre et le déploiement côté CPiN sont hors de ce dépôt. L'URL GitLab, l'ID du projet miroir et le token se passent par variables et secrets du dépôt consommateur, jamais en clair dans un fichier.

## Si vous modifiez ce dépôt

- Commits au format Conventional Commits : `feat` et `fix` déclenchent une release, `docs` non.
- Un bloc `run:` n'interpole jamais `${{ }}` : les valeurs passent par `env:`. Le harnais `ci/tests/` extrait les `run:` du YAML pour les exécuter et échoue sinon.
- Les actions tierces sont épinglées par SHA avec la version en commentaire.
- Avant une PR : `./ci/tests/run.sh` (`bash >= 4`, `yq >= 4`), `actionlint`, `yamllint -c ci/configs/yamllint.yaml .github/workflows`.
