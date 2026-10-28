---
name: fabnum-cicd-auth
description: Use when a fabnum-cicd workflow needs a GitHub credential beyond GITHUB_TOKEN — choosing between GITHUB_TOKEN, a GitHub App (APP_CLIENT_ID/APP_PRIVATE_KEY) and a PAT (GH_PAT), creating the App, wiring secrets into a caller workflow, or debugging "Resource not accessible", missing CI on release PRs, automerge or dispatch failures
allowed-tools: Bash Read Write
---

# Authentication for fabnum-cicd workflows

Help the user choose and wire the GitHub credential of their workflows.

## Where to read

Relative links assume the full repository (plugin install); otherwise use
<https://github.com/dnum-mi/fabnum-cicd/tree/main>.

- Modes, App creation, troubleshooting, migration from a PAT:
  [`docs/workflows/05-authentication.md`](../../docs/workflows/05-authentication.md) (the source of truth).
- Which secrets a workflow takes: its `on.workflow_call` in `.github/workflows/<name>.yml`.

## Rules

- **Never ask for, read, write or print the value** of a secret, a `.pem` key or a token. The human creates them in
  GitHub; the agent writes the YAML that **references** them and says which **names** to create.
- With an authenticated `gh`, check names only: `gh secret list`, `gh variable list` (`-R <org>/<repo>`). Without it,
  give the UI path and ask for confirmation.
- Never `secrets: inherit`.
- Resolution order: App token, then `GH_PAT`, then `GITHUB_TOKEN`. Recommend the App.
- `APP_CLIENT_ID` and `APP_PRIVATE_KEY` go together (one alone fails the job). `APP_CLIENT_ID` is the Client ID
  (`Iv23li…`), not the numeric App ID.
- A PR opened with `GITHUB_TOKEN` does not trigger CI: release PRs, chart PRs, automerge and cross-repository dispatch
  need the App (or a PAT).

## Process

Read the authentication page, pick the mode from the project's needs, then write the `secrets:` block of the caller
and list the names the human must create.
