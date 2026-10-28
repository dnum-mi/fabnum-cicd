---
name: fabnum-cicd-git-hooks
description: Use when installing or configuring the local git hooks of fabnum-cicd in a project — Conventional Commits check (commit-msg), ESLint/yamllint/chart-testing lint (pre-commit), GPG-signed commits check (pre-push)
allowed-tools: Bash Read Write
---

# Git hooks fabnum-cicd

Aider l'utilisateur à installer, dans son propre projet, les hooks locaux de `dnum-mi/fabnum-cicd` : ils attrapent
avant le push ce que la CI refuserait. Doc : `../../docs/git-hooks/01-introduction.md` à `04-pre-push.md`.
Les hooks eux-mêmes sont livrés avec le plugin dans `../../git-hooks/` (sinon, dans le dépôt `fabnum-cicd`).

> Les liens relatifs vers `docs/` supposent le dépôt complet. Sans lui (installation par URL ou copie des seuls
> skills), les mêmes pages sont en ligne : <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

## Choisir les hooks

| Hook | Type | Vérifie | Prérequis à installer |
|------|------|---------|-----------------------|
| `conventional-commit` | `commit-msg` | message au format `<type>(<scope>)!: <sujet>` ; types `feat fix docs style refactor perf test chore revert ci` | aucun |
| `eslint-lint` | `pre-commit` | lint JS/TS/JSON/MD/YAML | ESLint (+ `@antfu/eslint-config` recommandé) |
| `yaml-lint` | `pre-commit` | lint YAML | `yamllint` |
| `helm-lint` | `pre-commit` | lint des charts | `chart-testing` (`ct`), `yamllint`, `helm` |
| `signed-commit` | `pre-push` | tous les commits à pousser sont signés GPG | GPG configuré avec Git |

Demander à l'utilisateur lesquels il veut, en proposant d'office `conventional-commit` : sans lui, `release-please`
ne calcule pas de version (skill `fabnum-cicd-release`) et le job `lint-commits` de la CI échouera.

## Installer (dans le dépôt de l'utilisateur)

1. **Copier** chaque hook vers `.git/hooks/<type>` et le rendre exécutable (les fichiers sources ne le sont pas, sauf
   `conventional-commit`) :

```bash
cp <chemin-du-plugin>/git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
cp <chemin-du-plugin>/git-hooks/pre-push/signed-commit         .git/hooks/pre-push
chmod +x .git/hooks/commit-msg .git/hooks/pre-push
```

2. **Remplacer les `<config_path>`** dans les hooks `pre-commit` (`eslint-lint`, `yaml-lint`, `helm-lint`) par le
   chemin de la configuration du projet. Sans ça, le hook échoue. Des configurations d'exemple sont dans
   `../../git-hooks/configs/` (`eslint.config.js`, `yamllint.yaml`, `chart-testing.yaml`) : les copier dans le projet
   et les adapter.
3. **Un seul fichier `pre-commit`** existe dans `.git/hooks/` : copier deux hooks `pre-commit` l'un sur l'autre écrase
   le premier. Pour en cumuler plusieurs, écrire un `.git/hooks/pre-commit` qui appelle chacun d'eux et s'arrête au
   premier échec (`set -e`).
4. Alternative pour tous les projets d'un poste : `git config --global core.hooksPath <chemin>/git-hooks` (les hooks
   doivent alors être nommés comme leur type : `commit-msg`, `pre-commit`, `pre-push`).

Un clone neuf n'a pas ces hooks (`.git/hooks` n'est pas versionné) : l'indiquer dans le README du projet ou fournir un
script d'installation versionné.

## Vérifier

```bash
git commit --allow-empty -m "mauvais message"      # doit être refusé par commit-msg
git commit --allow-empty -m "chore: test des hooks" # doit passer
```

`--no-verify` contourne les hooks (`git commit --no-verify`, `git push --no-verify`) : le signaler, sans le conseiller.

## Pièges

1. **`signed-commit` exige une clé GPG déjà configurée** (`user.signingkey`, `commit.gpgsign true`) ; sinon tous les
   push sont refusés. Guide pas à pas : `../../docs/git-hooks/04-pre-push.md`.
2. Les hooks locaux sont une aide, pas une garantie : la CI (`lint-commits`, `lint-yaml`, `lint-helm`) reste la porte
   qui compte (skill `fabnum-cicd-pipeline`).
3. `eslint-lint` lint tout le projet, pas seulement les fichiers indexés : prévoir `ignores` dans la configuration.
