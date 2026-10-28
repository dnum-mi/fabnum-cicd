---
name: fabnum-cicd-git-hooks
description: Use when installing or configuring the local git hooks of fabnum-cicd in a project — Conventional Commits check (commit-msg), ESLint/yamllint/chart-testing lint (pre-commit), GPG-signed commits check (pre-push)
allowed-tools: Bash Read Write
---

# fabnum-cicd git hooks

Help the user install, in their own project, the local hooks of `dnum-mi/fabnum-cicd`: they catch before the push what
CI would refuse. Docs (in French): `../../docs/git-hooks/01-introduction.md` to `04-pre-push.md`.
The hooks themselves ship with the plugin in `../../git-hooks/` (otherwise, in the `fabnum-cicd` repository). To find
`<plugin-path>`, run `find ~/.claude/plugins ~/.cache/opencode/packages -path '*git-hooks/commit-msg/conventional-commit'`
(Claude Code and OpenCode caches), or use the user's own clone of the repository.

> Relative links to `docs/` assume the full repository. Without it (URL install, or only the skills copied), the same
> pages are online: <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

## Choose the hooks

| Hook | Type | Checks | Prerequisite to install |
|------|------|--------|-------------------------|
| `conventional-commit` | `commit-msg` | message in the format `<type>(<scope>)!: <subject>`; types `feat fix docs style refactor perf test chore revert ci` | none |
| `eslint-lint` | `pre-commit` | JS/TS/JSON/MD/YAML lint | ESLint (+ `@antfu/eslint-config` recommended) |
| `yaml-lint` | `pre-commit` | YAML lint | `yamllint` |
| `helm-lint` | `pre-commit` | chart lint | `chart-testing` (`ct`), `yamllint`, `helm` |
| `signed-commit` | `pre-push` | every commit to push is GPG-signed | GPG configured with Git |

Ask the user which ones they want, proposing `conventional-commit` by default: without it, `release-please` computes
no version (skill `fabnum-cicd-release`) and the CI `lint-commits` job will fail.

## Install (in the user's repository)

1. **Copy** each hook to `.git/hooks/<type>` and make it executable (the source files are not, except
   `conventional-commit`):

```bash
cp <plugin-path>/git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
cp <plugin-path>/git-hooks/pre-push/signed-commit         .git/hooks/pre-push
chmod +x .git/hooks/commit-msg .git/hooks/pre-push
```

2. **Replace the `<config_path>`** in the `pre-commit` hooks (`eslint-lint`, `yaml-lint`, `helm-lint`) with the path of
   the project's configuration. Without it, the hook fails. Example configurations are in
   `../../git-hooks/configs/` (`eslint.config.js`, `yamllint.yaml`, `chart-testing.yaml`): copy them into the project
   and adapt them.
3. **Only one `pre-commit` file** exists in `.git/hooks/`: copying two `pre-commit` hooks over each other overwrites
   the first. To combine several, write a `.git/hooks/pre-commit` that calls each of them and stops at the first
   failure (`set -e`).
4. Alternative for every project on a machine: Git looks for executables named like their type (`commit-msg`,
   `pre-commit`, `pre-push`) directly in `core.hooksPath`, and `git-hooks/` holds directories, so it cannot be used as
   is. Create a directory (e.g. `~/.git-hooks`), symlink the chosen hooks into it under those names, then run
   `git config --global core.hooksPath ~/.git-hooks`. Same layout in `../../docs/git-hooks/01-introduction.md`.

A fresh clone does not have these hooks (`.git/hooks` is not versioned): say so in the project's README or provide a
versioned install script.

## Verify

```bash
git commit --allow-empty -m "bad message"        # must be refused by commit-msg
git commit --allow-empty -m "chore: test hooks"  # must pass
```

`--no-verify` bypasses the hooks (`git commit --no-verify`, `git push --no-verify`): mention it, without recommending it.

## Pitfalls

1. **`signed-commit` requires an already configured GPG key** (`user.signingkey`, `commit.gpgsign true`); otherwise
   every push is refused. Step-by-step guide: `../../docs/git-hooks/04-pre-push.md`.
2. Local hooks are a help, not a guarantee: CI (`lint-commits`, `lint-yaml`, `lint-helm`) remains the gate that
   matters (skill `fabnum-cicd-pipeline`).
3. `eslint-lint` lints the whole project, not only the staged files: plan for `ignores` in the configuration.
