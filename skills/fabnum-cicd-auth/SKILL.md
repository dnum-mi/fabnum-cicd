---
name: fabnum-cicd-auth
description: Use when a fabnum-cicd workflow needs a GitHub credential beyond GITHUB_TOKEN — choosing between GITHUB_TOKEN, a GitHub App (APP_CLIENT_ID/APP_PRIVATE_KEY) and a PAT (GH_PAT), creating the App, wiring secrets into a caller workflow, or debugging "Resource not accessible", missing CI on release PRs, automerge or dispatch failures
allowed-tools: Bash Read Write
---

# Authentication for fabnum-cicd workflows

Help the user choose and wire the GitHub credential of their workflows. Source of truth, to read for any detail:
`../../docs/workflows/05-authentication.md` (in French).

> Relative links to `docs/` assume the full repository. Without it (URL install, or only the skills copied), the same
> pages are online: <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

## Rules for the agent

- **Never ask for, read, write or print the value** of a secret, a `.pem` key or a token. The human creates and enters
  them in GitHub. The agent writes the YAML that **references** them and says which **names** to create.
- With an authenticated `gh`, check **names** only: `gh secret list` and `gh variable list` (add
  `-R <org>/<repo>` for another repository). Without `gh`, give the path in the UI and ask for confirmation.
- Never write `secrets: inherit`: pass each secret by name.

## Which mode to choose

Start at the top and stop at the first row that matches.

| The project… | Mode | Secrets to create |
|--------------|------|-------------------|
| builds, tests, scans, pushes to GHCR only | `GITHUB_TOKEN` (automatic) | none |
| wants the **release PR** or chart PR to trigger CI | GitHub App (or `GH_PAT`) | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| wants **automerge** (`AUTOMERGE_*`) | GitHub App (or `GH_PAT`) | same |
| triggers a workflow in **another repository** (`dispatch-helm-chart`) | GitHub App (or `GH_PAT`) | same |
| has a **ruleset** that refuses the `GITHUB_TOKEN` push (`sync-prerelease-branch`) | GitHub App **only** | same |
| already has a working `GH_PAT` | `GH_PAT` | `GH_PAT` |

Resolution order when several are provided: **App token → `GH_PAT` → `GITHUB_TOKEN`**. The App wins, which lets you
check a migration before deleting the PAT. Recommend the App: it is scoped per job, expires after an hour and is not
tied to a person.

Why the App: a PR opened with `GITHUB_TOKEN` **does not trigger** `pull_request` workflows. Release PRs are then
mergeable without any check having run.

## Create the App (once, by the human)

1. *Settings → Developer settings → GitHub Apps → New GitHub App*. Webhook **unchecked**. Installable *Only on this account*.
2. Permissions: Metadata (read), Contents, Pull requests and Issues (read/write). Add *Actions* (read/write) for
   `dispatch-helm-chart`, *Workflows* for `sync-prerelease-branch`.
3. *Generate a private key*: a `.pem` is downloaded, **only once**.
4. *Install App → Only select repositories*: only the repositories concerned (for `dispatch-helm-chart`, **also the
   chart repository**).
5. In each repository, *Settings → Secrets and variables → Actions*: `APP_CLIENT_ID` (the **Client ID** `Iv23li…`, not
   the numeric App ID) and `APP_PRIVATE_KEY` (the whole `.pem`, `BEGIN`/`END` lines included).

## Wire it in the caller workflow

```yaml
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

With a fine-grained PAT instead: `GH_PAT: ${{ secrets.GH_PAT }}` (never a classic token where an App is possible).
`sync-prerelease-branch` does not accept a PAT, only the App pair.

Check: the release PR is opened by `<app>[bot]` (not `github-actions[bot]`), it **has checks**, and the "Generate
GitHub App token" step ran in the logs. The first release may surface checks that have been broken for a long time:
that is expected.

## Pitfalls

1. **Both App secrets, or neither.** Providing only one fails the job (`APP_CLIENT_ID and APP_PRIVATE_KEY must be
   supplied together`) instead of falling back to a less privileged mode.
2. **`Client ID` ≠ `App ID`.** Only the Client ID works.
3. **A job's `permissions:` block only governs `GITHUB_TOKEN`.** A `Resource not accessible by integration` error with
   an App token is fixed in the App's **installation** settings, not in the YAML.
4. **Automerge depends on the `AUTOMERGE_*` inputs**, not on the credentials. `AUTOMERGE_METHOD: auto` requires
   *Allow auto-merge* in *Settings → General*; `admin` bypasses branch protection and required checks.
5. **Reusable workflows do not inherit secrets**: pass them explicitly in `secrets:`.
6. **`dispatch-helm-chart`**: the App must be installed on the chart repository; `CHART_REPO` is written `owner/repo`.
7. An installation token expires after an hour: never pass one between jobs.
8. **`build-docker` with `BUILD_SECRET_GITHUB_TOKEN`**: the value is readable by anything the Dockerfile runs; only use
   a read-only token (`contents: read`).

## Going further

- Full troubleshooting, two Apps, migration from a PAT: `../../docs/workflows/05-authentication.md`.
- Using these credentials in a pipeline: skill `fabnum-cicd-pipeline`.
