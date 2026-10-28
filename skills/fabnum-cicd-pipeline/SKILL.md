---
name: fabnum-cicd-pipeline
description: Use when writing, extending or reviewing a GitHub Actions ci.yml/cd.yml that calls the reusable workflows of dnum-mi/fabnum-cicd — lint, tests, Docker/Python build, Trivy/Gitleaks/SonarQube/zizmor scans, check-jobs gate, cache and image cleanup
allowed-tools: Bash Read Write
---

# Assemble a pipeline with fabnum-cicd

Help the user wire, **in their own repository**, the reusable workflows of
[`dnum-mi/fabnum-cicd`](https://github.com/dnum-mi/fabnum-cicd). This skill holds no catalogue: read the sources.

## Where to read (never from memory)

Relative links assume the full repository (plugin install); otherwise use
<https://github.com/dnum-mi/fabnum-cicd/tree/main>.

- Overview, complete CI/CD examples and good practices:
  [`docs/workflows/01-introduction.md`](../../docs/workflows/01-introduction.md). It has the sections "Pipeline CI
  complet", "Pipeline CD avec release et déploiement" and "Pipeline pour charts Helm": start from the one that matches.
- One page per workflow: `docs/workflows/NN-<name>.md` (list in the overview).
- Exact inputs, secrets, defaults: the `on.workflow_call` block of `.github/workflows/<name>.yml`.
- A working caller: this repository's own `.github/workflows/ci.yml` and `cd.yml`.
- Single gate for required checks: [`docs/workflows/80-check-jobs.md`](../../docs/workflows/80-check-jobs.md).

## Process

1. Ask: language and artifacts (Docker, Python, npm, Helm)? one image or several? `develop` + `main`? a ruleset
   requiring PRs? is `gh` available (secret **names** only)?
2. Read the overview, then the page and `workflow_call` of every workflow you will call.
3. Write `ci.yml` (pull request) and `cd.yml` (release); end `ci.yml` with the `check-jobs` gate listing **all** jobs
   in `needs`.
4. Credentials: skill `fabnum-cicd-auth`. Releases: `fabnum-cicd-release`. Charts: `fabnum-cicd-helm`.
5. Check with `actionlint` if available, then open a test PR.

## Rules

The full list is the "Bonnes pratiques" section of the overview; the ones to never break:

- `@v0` (or a precise pin / SHA). **Never `@main`**.
- **Never `secrets: inherit`**: pass each secret by name.
- Permissions are declared **per job** and must cover the **union** of the called workflow's permissions, even for a
  job that does not run. A missing scope fails parsing.
- Never ask for, read or print a secret value; only reference secret names.
- Third-party actions pinned by full SHA; no `${{ … }}` interpolated directly in `run:` (go through `env:`).
