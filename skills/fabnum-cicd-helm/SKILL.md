---
name: fabnum-cicd-helm
description: Use when linting, testing, versioning, publishing or signing Helm charts with fabnum-cicd — lint-helm, lint-helm-schema, test-helm, update-helm-chart, release-helm, release-helm-local, attest-helm, or dispatching a chart bump to a separate chart repository (dispatch-helm-chart)
allowed-tools: Bash Read Write
---

# Helm charts with fabnum-cicd

Help the user wire the lifecycle of a Helm chart: checks, versioning, publication, signing. Platform-specific
deployment constraints are out of scope.

## Where to read

Relative links assume the full repository (plugin install); otherwise use
<https://github.com/dnum-mi/fabnum-cicd/tree/main>.

- Checks: [`11-lint-helm.md`](../../docs/workflows/11-lint-helm.md),
  [`12-lint-helm-schema.md`](../../docs/workflows/12-lint-helm-schema.md),
  [`20-test-helm.md`](../../docs/workflows/20-test-helm.md).
- Versioning and publication: [`53-update-helm-chart.md`](../../docs/workflows/53-update-helm-chart.md),
  [`51-release-helm.md`](../../docs/workflows/51-release-helm.md),
  [`52-release-helm-local.md`](../../docs/workflows/52-release-helm-local.md).
- Separate chart repository: [`54-dispatch-helm-chart.md`](../../docs/workflows/54-dispatch-helm-chart.md).
- Signing: [`56-attest-helm.md`](../../docs/workflows/56-attest-helm.md).
- Exact inputs and secrets: the `on.workflow_call` of `.github/workflows/<name>.yml`.

## First question: where does the chart live?

| Situation | Chain |
|-----------|-------|
| In the application repository | `update-helm-chart` (`RUN_MODE: local`) then `release-helm-local` |
| In a separate repository | app side: `dispatch-helm-chart`; chart side: a workflow calling `update-helm-chart` (`RUN_MODE: called`) |
| Dedicated chart repository | `release-helm` |

Do not use `release-helm` in an application monorepo.

## Rules

- `dispatch-helm-chart` needs the GitHub App installed on the chart repository (skill `fabnum-cicd-auth`); the chart
  repository's entry workflow must declare every input the dispatch sends (see doc 54), otherwise HTTP 422.
- The dispatch is asynchronous: a green app job does not mean the chart was updated.
- With a pre-release branch, a bump job that commits to `main` goes into `sync-prerelease-branch`'s `needs` (skill
  `fabnum-cicd-release`).
- GitHub Pages is public even for a private repository; `CREATE_GITHUB_RELEASE: true` is incompatible with immutable
  releases (use OCI).
- Never handle a secret value (`GPG_PRIVATE_KEY`, `GPG_PASSPHRASE`, registry password).
