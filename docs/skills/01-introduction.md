# Skills pour agents

Les skills sont de courtes fiches d'orientation que votre agent de code (Claude Code, OpenCode) charge quand la tâche s'y prête. Ils
l'aident à appliquer, **dans votre projet**, les recommandations et la mise en œuvre de ce dépôt : écrire un `ci.yml`
avec les bons workflows, configurer les releases, choisir l'authentification, installer les git hooks.

Ils ne contiennent aucun code exécutable : l'agent écrit des fichiers et peut lancer quelques commandes (`cp`,
`gh secret list`, `actionlint`…), que votre client vous demande d'approuver. GitHub exécute les workflows. Ils ne
manipulent jamais la valeur d'un secret : c'est vous qui créez les secrets.

## Skills disponibles

| Skill | Quand l'agent le charge | Sources dans ce dépôt |
| ----- | ----------------------- | --------------------- |
| [`fabnum-cicd-pipeline`](../../skills/fabnum-cicd-pipeline/SKILL.md) | écrire, étendre ou relire un `ci.yml` / `cd.yml` : lint, tests, build, scans, porte `check-jobs`, nettoyage | [workflows](../../.github/workflows/), [introduction](../workflows/01-introduction.md) |
| [`fabnum-cicd-auth`](../../skills/fabnum-cicd-auth/SKILL.md) | choisir et câbler `GITHUB_TOKEN`, GitHub App ou PAT ; dépanner une erreur de permission | [authentification](../workflows/05-authentication.md) |
| [`fabnum-cicd-release`](../../skills/fabnum-cicd-release/SKILL.md) | releases automatiques, Conventional Commits, pré-release, publication npm / PyPI, monorepo, `sync-cpin` | [release-app](../workflows/50-release-app.md), [sync-prerelease-branch](../workflows/57-sync-prerelease-branch.md), [monorepo](../workflows/90-monorepo-release.md) |
| [`fabnum-cicd-helm`](../../skills/fabnum-cicd-helm/SKILL.md) | lint, test, version, publication et signature d'un chart ; chart dans un dépôt séparé | [docs 51 à 54 et 56](../workflows/51-release-helm.md) |
| [`fabnum-cicd-git-hooks`](../../skills/fabnum-cicd-git-hooks/SKILL.md) | installer les hooks `commit-msg`, `pre-commit`, `pre-push` | [git hooks](../git-hooks/01-introduction.md) |

## Installation

Voir le [guide d'installation](./02-installation.md) (Claude Code, OpenCode, copie).

## Maintenir les skills

- Les skills ne **recopient pas** la documentation : ils indiquent à l'agent quoi lire (`docs/`, le `on.workflow_call`
  des workflows, les `ci.yml` / `cd.yml` de ce dépôt) et ne portent que les règles transverses (`@v0`, jamais
  `secrets: inherit`, union des permissions, aucune valeur de secret). Une modification d'un workflow n'exige donc
  aucune mise à jour des skills, seulement celle de sa page de `docs/`.
- Les `SKILL.md` sont rédigés **en anglais** (langue des agents et des descriptions de skills) ; la documentation de
  `docs/` reste en français.
- Un nouveau skill est un dossier `skills/<nom>/SKILL.md` dont le `name` est le nom du dossier ; il est repris
  automatiquement par la marketplace (`.claude-plugin/marketplace.json`) et par le plugin OpenCode.
