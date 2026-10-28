# Skills pour agents

Les skills sont des fiches d'instructions que votre agent de code (Claude Code) charge quand la tâche s'y prête. Ils
l'aident à appliquer, **dans votre projet**, les recommandations et la mise en œuvre de ce dépôt : écrire un `ci.yml`
avec les bons workflows, configurer les releases, choisir l'authentification, installer les git hooks.

Ils n'exécutent rien eux-mêmes et ne manipulent jamais la valeur d'un secret : l'agent écrit des fichiers, GitHub
exécute les workflows, et c'est vous qui créez les secrets.

## Skills disponibles

| Skill | Quand l'agent le charge | Sources dans ce dépôt |
| ----- | ----------------------- | --------------------- |
| [`fabnum-cicd-pipeline`](../../skills/fabnum-cicd-pipeline/SKILL.md) | écrire, étendre ou relire un `ci.yml` / `cd.yml` : lint, tests, build, scans, porte `check-jobs`, nettoyage | [workflows](../../.github/workflows/), [introduction](../workflows/01-introduction.md) |
| [`fabnum-cicd-auth`](../../skills/fabnum-cicd-auth/SKILL.md) | choisir et câbler `GITHUB_TOKEN`, GitHub App ou PAT ; dépanner une erreur de permission | [authentification](../workflows/05-authentication.md) |
| [`fabnum-cicd-release`](../../skills/fabnum-cicd-release/SKILL.md) | releases automatiques, Conventional Commits, pré-release, publication npm / PyPI, monorepo, `sync-cpin` | [release-app](../workflows/50-release-app.md), [sync-prerelease-branch](../workflows/57-sync-prerelease-branch.md), [monorepo](../workflows/90-monorepo-release.md) |
| [`fabnum-cicd-helm`](../../skills/fabnum-cicd-helm/SKILL.md) | lint, test, version, publication et signature d'un chart ; chart dans un dépôt séparé | [docs 51 à 54 et 56](../workflows/51-release-helm.md) |
| [`fabnum-cicd-git-hooks`](../../skills/fabnum-cicd-git-hooks/SKILL.md) | installer les hooks `commit-msg`, `pre-commit`, `pre-push` | [git hooks](../git-hooks/01-introduction.md) |

Le catalogue complet des workflows (entrées requises, secrets, permissions à accorder) est dans
[`skills/fabnum-cicd-pipeline/references/workflows.md`](../../skills/fabnum-cicd-pipeline/references/workflows.md).

## Installation

Voir la section [Skills pour agents](../../README.md#skills-pour-agents-claude-code) du README.

## Maintenir les skills

- Les skills sont **versionnés avec les workflows** : une modification d'un workflow (entrée, secret, permission)
  s'accompagne de la mise à jour du catalogue.
- `ci/tests/skills-catalog.test.sh` compare le catalogue au `on.workflow_call` et aux permissions de chaque workflow,
  vérifie que les liens du catalogue et les chemins relatifs des `SKILL.md` existent, et que les skills
  n'appellent que des workflows existants. Il
  tourne dans la CI dès qu'un fichier de `skills/` ou de `.claude-plugin/` change.
- Les gabarits `references/ci.yml` et `references/cd.yml` ne sont pas exécutés : les relire quand un workflow qu'ils
  appellent change.
- Un nouveau skill est un dossier `skills/<nom>/SKILL.md` dont le `name` est le nom du dossier ; il est repris
  automatiquement par la marketplace (`.claude-plugin/marketplace.json`).
