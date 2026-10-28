---
name: fabnum-cicd-release
description: Use when setting up automated releases with fabnum-cicd — release-please (release-app), Conventional Commits and lint-commits, develop/main pre-release flow and sync-prerelease-branch, publishing to npm or PyPI, monorepo releases, or triggering the CPiN mirror with sync-cpin
allowed-tools: Bash Read Write
---

# Releases with fabnum-cicd

Help the user automate, in their own repository, the chain commit → release PR → tag → publication.
Helm charts have their own skill: `fabnum-cicd-helm`. Detailed docs (in French), to read before writing a call:
`../../docs/workflows/50-release-app.md`, `55-release-npm.md`, `57-sync-prerelease-branch.md`,
`58-release-pypi.md`, `72-sync-cpin.md`, `90-monorepo-release.md`.

> Relative links to `docs/` assume the full repository. Without it (URL install, or only the skills copied), the same
> pages are online: <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

## The principle

1. Commits follow **Conventional Commits** (`feat:`, `fix:`, `feat!:`…). `release-please` derives the version and the
   changelog from them: a `docs:` or `chore:` commit triggers **no** release.
2. `release-app` opens and maintains a **release PR**. Merging it creates the tag and the GitHub release.
3. Publication jobs (image, package, chart) run on `release-created == 'true'`.

## Set up

1. **Validate commits**: `lint-commits` job in CI (skill `fabnum-cicd-pipeline`) and, locally, the `commit-msg` hook
   (skill `fabnum-cicd-git-hooks`).
2. **Create at the root** `release-please-config.json` and `.release-please-manifest.json` (examples and options:
   `../../docs/workflows/50-release-app.md`, Configuration section). Put the **current** version in the manifest.
   Choose the project's `release-type` (`node`, `python`, `simple`…).
3. **Call `release-app`** in `cd.yml`, with the GitHub App (without it, CI does not run on the release PR: skill
   `fabnum-cicd-auth`):

```yaml
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      TAG_MAJOR_AND_MINOR: true        # also creates the v1 and v1.2 tags
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

4. **Guard** every publication job: `if: ${{ needs.release.outputs.release-created == 'true' }}`
   (`release-app` is idempotent: it runs on every push). Useful outputs: `version`, `tag-name`.
5. Full template: `../fabnum-cicd-pipeline/references/cd.yml`.

## Pre-release (`develop` → `main`)

To publish release candidates (`1.2.3-rc.1`) from `develop` and final versions from `main`:

- `release-app` with `ENABLE_PRERELEASE: true`. Default branches: `PRERELEASE_BRANCH: develop`,
  `RELEASE_BRANCH: main`. Default files `release-please-config-rc.json` and `.release-please-manifest-rc.json`
  for the pre-release (structure in doc 50).
- **`sync-prerelease-branch` as the last job**, with `needs:` = **exactly** the jobs that commit to the release branch
  (the `release` job, and any local chart bump), nothing else. Otherwise the pre-release branch goes stale and
  `release-app` fails on it ("is missing N commit(s)").
- Pass `sync-prerelease-branch` the **same** `PRERELEASE_CONFIG_FILE` / `*_MANIFEST_FILE` as `release-app`.
- A ruleset that refuses `GITHUB_TOKEN` requires the App pair (a PAT is not accepted here); pushing with an App token
  triggers the CD on the pre-release branch.

## Publish a package

| Target | Workflow | To know |
|--------|----------|---------|
| npm / GitHub Packages | `release-npm` | `contents: read` + `id-token: write`; trusted publishing (OIDC) possible without a token, otherwise secret `NPM_TOKEN`; `DRY_RUN` to try |
| PyPI | `build-python` then `release-pypi` | `release-pypi` consumes the `build-python` artifact (`ARTIFACT` required); only permission `id-token: write`; trusted publishing (OIDC), secret `PYPI_TOKEN` otherwise |

## Monorepo

One release PR for the whole repository: manifest-mode config, one package per directory, outputs
`releases-created` / `paths-released` / `release-outputs` (the single-package outputs stay empty). Full pipeline
(several images, a single chart): `../../docs/workflows/90-monorepo-release.md`.

## Sync the CPiN mirror (`sync-cpin`)

Triggers the GitLab pipeline of the mirror project. Stick to what `../../docs/workflows/72-sync-cpin.md` says:
required inputs `GITLAB_URL` (as `https://`, otherwise the job refuses), `GIT_MIRROR_PROJECT_ID` (numeric id or
encoded path) and `REPOSITORY_NAME`; `BRANCH_TO_SYNC` or `SYNC_ALL` to choose what to sync; required secret
`GIT_MIRROR_TOKEN`. `ADDITIONAL_VARIABLES` is a JSON object of pipeline variables. The agent never handles the token
value.

## Pitfalls

1. **No release?** No `feat`/`fix` commit since the last one: `docs`/`chore`/`ci` are ignored.
2. **Immutable releases**: `release-helm` with `CREATE_GITHUB_RELEASE: true` is incompatible; for `release-app`,
   config `"draft": true` + `"force-tag-creation": true` and `PUBLISH_DRAFT_RELEASE: true`.
3. `AUTOMERGE_*` merges nothing without an App/PAT credential, and fails rather than silently ignoring it.
4. `outputs` booleans: strings, compare with `== 'true'`.
5. `sync-prerelease-branch` in a single-branch repository: useless, remove `ENABLE_PRERELEASE` and that job.

## Going further

- Docs: `../../docs/workflows/50-release-app.md` to `58-release-pypi.md`, `72-sync-cpin.md`, `90-monorepo-release.md`.
- Helm charts: skill `fabnum-cicd-helm`.
