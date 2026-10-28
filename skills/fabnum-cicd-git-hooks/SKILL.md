---
name: fabnum-cicd-git-hooks
description: Use when installing or configuring the local git hooks of fabnum-cicd in a project — Conventional Commits check (commit-msg), ESLint/yamllint/chart-testing lint (pre-commit), GPG-signed commits check (pre-push)
allowed-tools: Bash Read Write
---

# fabnum-cicd git hooks

Help the user install, in their own project, the local hooks of `dnum-mi/fabnum-cicd`: they catch before the push what
CI would refuse.

## Where to read

Relative links assume the full repository (plugin install); otherwise use
<https://github.com/dnum-mi/fabnum-cicd/tree/main>.

- Install, per-project or global (`core.hooksPath`): [`docs/git-hooks/01-introduction.md`](../../docs/git-hooks/01-introduction.md).
- One page per hook: [`02-commit-msg.md`](../../docs/git-hooks/02-commit-msg.md),
  [`03-pre-commit.md`](../../docs/git-hooks/03-pre-commit.md), [`04-pre-push.md`](../../docs/git-hooks/04-pre-push.md).
- The hooks and example configurations: `git-hooks/` of this repository. In a plugin install, find it with
  `find ~/.claude/plugins ~/.cache/opencode/packages -path '*git-hooks/commit-msg/conventional-commit'`.

## Rules

- Ask which hooks the user wants; propose `conventional-commit` by default (without it, `release-please` computes no
  version; skill `fabnum-cicd-release`).
- Check each hook's prerequisite first (ESLint, `yamllint`, `ct`, GPG key configured). `signed-commit` refuses every
  push without a configured signing key.
- Replace the `<config_path>` placeholder in `pre-commit` hooks; only one `pre-commit` file exists per hooks
  directory, so combine hooks in a wrapper.
- Verify with `git commit --allow-empty -m "bad message"` (must be refused). Mention `--no-verify` without
  recommending it; local hooks help, CI remains the gate.
