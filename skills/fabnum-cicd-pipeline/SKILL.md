---
name: fabnum-cicd-pipeline
description: Use when writing, extending or reviewing a GitHub Actions ci.yml/cd.yml that calls the reusable workflows of dnum-mi/fabnum-cicd — lint, tests, Docker/Python build, Trivy/Gitleaks/SonarQube/zizmor scans, check-jobs gate, cache and image cleanup
allowed-tools: Bash Read Write
---

# Assemble a pipeline with fabnum-cicd

Help the user wire, **in their own repository**, the reusable workflows of
[`dnum-mi/fabnum-cicd`](https://github.com/dnum-mi/fabnum-cicd): a `ci.yml` (pull request) and a `cd.yml`
(release, delivery). This skill runs nothing: it writes or reviews YAML, GitHub executes it.

> Relative links to `docs/` assume the full repository. Without it (URL install, or only the skills copied), the same
> pages are online: <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

The exact details (inputs, defaults) are in the docs shipped with the plugin (in French), to read before writing a
call: `../../docs/workflows/NN-<name>.md`. The full catalogue is in
[`references/workflows.md`](references/workflows.md).

## Before writing: ask these questions

| Question | Consequence |
|----------|-------------|
| Which language / artifacts (Docker image, Python package, npm package, Helm chart)? | selects the lint, test and build workflows (catalogue) |
| One image or several (monorepo)? | several: one `build-docker` / `attest-docker` pair per component, never a matrix for `attest-docker`; see skill `fabnum-cicd-release` for monorepos |
| `develop` (rc) and `main` (stable) branches? | pre-release: see skill `fabnum-cicd-release` |
| Does the repository require a PR for every push (ruleset)? | yes: GitHub App mandatory for any job that pushes; see skill `fabnum-cicd-auth` |
| Is `gh` installed and authenticated? | yes: the agent can check secret **names** (`gh secret list`); no: the human checks them in the UI |

## Start

1. Start from [`references/ci.yml`](references/ci.yml) (pull request) and, for releases,
   [`references/cd.yml`](references/cd.yml). Remove the jobs that do not apply, adapt the `<…>`.
2. For each chosen workflow, **open its doc** and the catalogue: required inputs, secrets, permissions.
3. **Keep `all-jobs-passed` up to date**: every job added or removed is reflected in its `needs` (see below).
4. Create the needed secrets (skill `fabnum-cicd-auth`); the agent never reads or writes their value.
5. Check with `actionlint` if available, then open a test PR.

## Rules

- **Version**: `@v0` (floating tag: the repository is in `0.x`, a minor bump can change a behaviour). To pin:
  `@v0.25` (or the commit SHA). **Never `@main`**. On the Renovate side, a `@v0` has nothing to update; a precise pin
  is raised by Renovate like any GitHub Actions dependency.
- **Permissions**: declared **per job**, never at workflow level. The caller grants the **union** of the permissions
  of the called workflow, even for a job that does not run (catalogue "Permissions" column). A missing scope fails
  parsing, not a job.
- **Never `secrets: inherit`**: pass each secret by name.
- **Credentials**: `GITHUB_TOKEN` is enough for lint, test, build, scan. As soon as an automated PR must trigger CI,
  or for automerge or cross-repository dispatch: GitHub App (skill `fabnum-cicd-auth`).
- **Third-party actions** the user adds themselves: pinned by full SHA with a version comment.
- **Lowercase image**: `ghcr.io/${GITHUB_REPOSITORY,,}` computed once then propagated.
- **Booleans** coming from `env` or outputs: they are strings, compare with `== 'true'`.
- **Concurrency**: `cancel-in-progress: true` in CI, `false` in CD.
- **Runner**: `RUNS_ON` is a JSON string (`'["ubuntu-24.04"]'`, `'["self-hosted", "linux"]'`).

## The single `check-jobs` gate

Path-filtered or matrix jobs cannot be required one by one by a ruleset: a required check that never reports blocks
the PR. Add a final job that aggregates them (doc `80-check-jobs.md`):

```yaml
  all-jobs-passed:
    name: Check jobs status
    if: ${{ always() }}
    needs: [lint-commits, lint-yaml, build]   # ALL jobs, path-filter included
    uses: dnum-mi/fabnum-cicd/.github/workflows/check-jobs.yml@v0
    permissions: {}
    with:
      NEEDS: ${{ toJson(needs) }}
```

- List **all** jobs in `needs`, not only the last ones: a skipped job counts as a success, including when it is
  skipped because its prerequisite failed.
- The check reports as **`<calling job> / Required jobs`**. Replacing a homemade gate with this one renames the
  check: merge first, let a PR run, then update the ruleset (otherwise every PR is blocked).

## Frequent pitfalls

1. Empty matrix (`fromJSON('[]')`) = error: guard with `if: … != '[]'`.
2. `build-docker` builds the **last** stage of the Dockerfile by default: set `IMAGE_TARGET` if that last stage is not
   the one to ship (for example a test stage).
3. `scan-trivy`: a distinct `CATEGORY` per scan in a matrix, `TIMEOUT` for big images; `FAIL_ON_ERROR` defaults to
   `false` (the scan informs without blocking); `SEVERITY` restricts what blocks. The image must exist before it is
   scanned.
4. `attest-docker` is called **after** `build-docker` with its `digest` and `image` outputs (`digest` is empty if
   `PUSH: false`, so there is nothing to attest); do not put it in a matrix (the outputs of a matrix job collapse into
   a single value).
5. `scan-sonarqube`: `SONAR_URL` is a required **input**; `SONAR_TOKEN` and `SONAR_PROJECT_KEY` are required secrets.
   A URL is not passed through a secret in `with:`: use a variable (`vars.`).
6. `scan-gitleaks` analyses the whole git history: the first run on an old repository may surface old secrets.
7. `lint-helm` requires `CT_CONF_PATH` (`chart-testing` configuration).
8. `clean-images` deletes any tag it is given: only pass it closed PRs.
9. Build cache: `CACHE: true` enables the GitHub Actions cache; `CACHE_MODE: min` only exports the final image
   (useful for heavy layers).

## Review an existing pipeline

Go through these in order and flag each deviation with the file and line:

1. `@main` / `@master` / `@latest` on an action or a reusable workflow.
2. `secrets: inherit`, or a secret passed to a workflow that does not declare it.
3. Permissions declared at workflow level, or that do not cover the union of the called workflow.
4. `${{ … }}` interpolated directly in a `run:` block (go through `env:`).
5. Third-party actions not pinned by SHA.
6. `all-jobs-passed` missing, or an incomplete `needs`.
7. An incomplete `APP_CLIENT_ID` / `APP_PRIVATE_KEY` pair, or a classic `GH_PAT` where an App is possible.
8. `scan-zizmor` missing: it detects injections, excessive permissions and persisted credentials.

## Going further

- Catalogue, required inputs and permissions: [`references/workflows.md`](references/workflows.md).
- Complete examples (CI, CD, Helm): `../../docs/workflows/01-introduction.md`.
- Authentication: skill `fabnum-cicd-auth`. Release and charts: skills `fabnum-cicd-release` and `fabnum-cicd-helm`.
- Local hooks (lint before commit): skill `fabnum-cicd-git-hooks`.
