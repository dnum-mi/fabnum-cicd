# Catalogue of reusable workflows

Call: `uses: dnum-mi/fabnum-cicd/.github/workflows/<name>.yml@v0`. All inputs are `UPPER_CASE`; `RUNS_ON`
(JSON string, default `["ubuntu-24.04"]`) is accepted by every workflow.

This table is **checked by `ci/tests/skills-catalog.test.sh`** against the `on.workflow_call` and the `permissions` of
each workflow: if a workflow changes, the test fails until the table is updated.

- **Required inputs**: without them the call is rejected. The other inputs have a default: see the doc (in French).
- **Secrets**: optional except those marked "required"; the `APP_CLIENT_ID` + `APP_PRIVATE_KEY` pair goes
  **together or not at all** (see skill `fabnum-cicd-auth`).
- **Permissions**: the union of those of every job of the called workflow. GitHub validates them at parsing, even for a
  job that does not run: the caller must grant them all (`security-events`, `pull-requests`… included).

| Workflow | Purpose | Required inputs | Secrets | Permissions to grant | Doc |
| --- | --- | --- | --- | --- | --- |
| `attest-docker` | SLSA provenance, SBOM, cosign signature of a pushed image | `IMAGE_NAME`, `DIGEST` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `attestations: write`, `id-token: write`, `packages: write` | [31](../../../docs/workflows/31-attest-docker.md) |
| `attest-helm` | Sign (cosign) and attest (SLSA) charts published to OCI | `CHARTS` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `attestations: write`, `id-token: write`, `packages: write` | [56](../../../docs/workflows/56-attest-helm.md) |
| `build-docker` | Multi-arch build, optional push; outputs `digest`, `image` | `IMAGE_NAME`, `IMAGE_TAG`, `IMAGE_DOCKERFILE`, `IMAGE_CONTEXT` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `BUILD_SECRETS`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: read`, `packages: write` | [30](../../../docs/workflows/30-build-docker.md) |
| `build-python` | Build the package and check the wheel; `dist/` artifact | — | — | `contents: read` | [32](../../../docs/workflows/32-build-python.md) |
| `check-jobs` | A single requirable check that aggregates every job | `NEEDS` | — | `{}` | [80](../../../docs/workflows/80-check-jobs.md) |
| `clean-cache` | Delete the caches of a closed PR | — | — | `actions: write` | [70](../../../docs/workflows/70-clean-cache.md) |
| `clean-images` | Delete GHCR images of closed PRs | `IMAGE` | — | `packages: write` | [71](../../../docs/workflows/71-clean-images.md) |
| `dispatch-helm-chart` | Trigger the update of a chart hosted in another repository | `CHART_REPO`, `CHART_NAME` | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `{}` | [54](../../../docs/workflows/54-dispatch-helm-chart.md) |
| `lint-commits` | Check the Conventional Commits of a PR | — | — | `contents: read` | [10](../../../docs/workflows/10-lint-commits.md) |
| `lint-helm-schema` | Validate a chart's values against a JSON Schema | `CHART_PATH` | — | `contents: read` | [12](../../../docs/workflows/12-lint-helm-schema.md) |
| `lint-helm` | Lint charts (chart-testing) and their doc (helm-docs) | `CT_CONF_PATH` | — | `contents: read` | [11](../../../docs/workflows/11-lint-helm.md) |
| `lint-python` | Lint and type-check a Python project (uv) | — | — | `contents: read` | [15](../../../docs/workflows/15-lint-python.md) |
| `lint-yaml` | yamllint on a directory | — | — | `contents: read` | [14](../../../docs/workflows/14-lint-yaml.md) |
| `release-app` | release-please: release PR, tags, changelog, pre-release; outputs `release-created`, `version` | — | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: write`, `issues: write`, `pull-requests: write` | [50](../../../docs/workflows/50-release-app.md) |
| `release-helm-local` | Publish to OCI the chart of an application repository / monorepo | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `contents: read`, `packages: write` | [52](../../../docs/workflows/52-release-helm-local.md) |
| `release-helm` | Publish charts from a dedicated chart repository (OCI and/or GitHub Pages) | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT`, `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE` | `contents: write`, `packages: write` | [51](../../../docs/workflows/51-release-helm.md) |
| `release-npm` | Publish an npm package (npmjs.org, GitHub Packages, private registry) | — | `NPM_TOKEN` | `contents: read`, `id-token: write` | [55](../../../docs/workflows/55-release-npm.md) |
| `release-pypi` | Publish the `build-python` distributions to PyPI | `ARTIFACT` | `PYPI_TOKEN` | `id-token: write` | [58](../../../docs/workflows/58-release-pypi.md) |
| `scan-gitleaks` | Secrets in the whole git history | — | — | `contents: read`, `pull-requests: write`, `security-events: write` | [42](../../../docs/workflows/42-scan-gitleaks.md) |
| `scan-sonarqube` | Code quality (SonarQube) | `SONAR_URL` | `SONAR_TOKEN` (required), `SONAR_PROJECT_KEY` (required) | `contents: read`, `issues: write`, `pull-requests: write` | [40](../../../docs/workflows/40-scan-sonarqube.md) |
| `scan-trivy` | Vulnerabilities: image (`IMAGE`), configuration (`PATH`) or tarball | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: read`, `packages: read`, `pull-requests: write`, `security-events: write` | [41](../../../docs/workflows/41-scan-trivy.md) |
| `scan-zizmor` | Security audit of GitHub Actions workflows | — | — | `contents: read` | [45](../../../docs/workflows/45-scan-zizmor.md) |
| `sync-cpin` | Trigger the sync to GitLab CPiN (see doc 72) | `GITLAB_URL`, `GIT_MIRROR_PROJECT_ID`, `REPOSITORY_NAME` | `GIT_MIRROR_TOKEN` (required) | `{}` | [72](../../../docs/workflows/72-sync-cpin.md) |
| `sync-prerelease-branch` | Rebase the pre-release branch onto the release branch (last job) | — | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` | `contents: write` | [57](../../../docs/workflows/57-sync-prerelease-branch.md) |
| `test-docker` | Run a command in an image (registry or tarball) | `COMMAND` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `contents: read`, `packages: read` | [24](../../../docs/workflows/24-test-docker.md) |
| `test-helm` | `ct install` dans un cluster Kind | `CT_CONF_PATH` | — | `contents: read` | [20](../../../docs/workflows/20-test-helm.md) |
| `test-python` | Python tests (uv), coverage as an artifact | — | — | `contents: read` | [22](../../../docs/workflows/22-test-python.md) |
| `update-helm-chart` | Update `Chart.yaml` (`RUN_MODE: local` or `called`); output `commit-sha` | `RUN_MODE` | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: write`, `pull-requests: write` | [53](../../../docs/workflows/53-update-helm-chart.md) |
