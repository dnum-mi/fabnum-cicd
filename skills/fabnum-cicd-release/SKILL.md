---
name: fabnum-cicd-release
description: Use when setting up automated releases with fabnum-cicd — release-please (release-app), Conventional Commits and lint-commits, develop/main pre-release flow and sync-prerelease-branch, publishing to npm or PyPI, monorepo releases, or triggering the CPiN mirror with sync-cpin
allowed-tools: Bash Read Write
---

# Releases with fabnum-cicd

Help the user automate, in their own repository, the chain commit → release PR → tag → publication. Charts have their
own skill: `fabnum-cicd-helm`.

## Where to read

Relative links assume the full repository (plugin install); otherwise use
<https://github.com/dnum-mi/fabnum-cicd/tree/main>.

| Topic | Page |
|-------|------|
| release-please, configuration, pre-release | [`50-release-app.md`](../../docs/workflows/50-release-app.md) |
| npm / PyPI | [`55-release-npm.md`](../../docs/workflows/55-release-npm.md), [`58-release-pypi.md`](../../docs/workflows/58-release-pypi.md) |
| pre-release branch sync | [`57-sync-prerelease-branch.md`](../../docs/workflows/57-sync-prerelease-branch.md) |
| monorepo | [`90-monorepo-release.md`](../../docs/workflows/90-monorepo-release.md) |
| CPiN mirror | [`72-sync-cpin.md`](../../docs/workflows/72-sync-cpin.md) (stick to it) |
| Commit format | [`10-lint-commits.md`](../../docs/workflows/10-lint-commits.md) |

Exact inputs and secrets: the `on.workflow_call` of `.github/workflows/<name>.yml`.

## Rules

- Commits follow **Conventional Commits**; `docs:`/`chore:`/`ci:` alone trigger no release. Enforce with the
  `lint-commits` job and the `commit-msg` hook (skill `fabnum-cicd-git-hooks`).
- `release-app` needs the GitHub App to let CI run on the release PR (skill `fabnum-cicd-auth`).
- Guard every publication job with `needs.release.outputs.release-created == 'true'` (a string).
- With a pre-release branch, `sync-prerelease-branch` is the last job, and its `needs` are exactly the jobs that commit
  to the release branch.
- Never handle a token value (`GIT_MIRROR_TOKEN`, `NPM_TOKEN`, `PYPI_TOKEN`): reference the name only.

## Process

Ask the release type and branches, read the pages above, then write `release-please-config.json`,
`.release-please-manifest.json` (current version) and the `cd.yml` jobs.
