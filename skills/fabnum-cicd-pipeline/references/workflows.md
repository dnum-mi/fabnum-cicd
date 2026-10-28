# Catalogue des workflows réutilisables

Appel : `uses: dnum-mi/fabnum-cicd/.github/workflows/<nom>.yml@v0`. Toutes les entrées sont en `UPPER_CASE` ; `RUNS_ON`
(chaîne JSON, défaut `["ubuntu-24.04"]`) est accepté par tous les workflows.

Ce tableau est **vérifié par `ci/tests/skills-catalog.test.sh`** contre le `on.workflow_call` et les `permissions` de
chaque workflow : si un workflow change, le test échoue tant que le tableau n'est pas mis à jour.

- **Entrées requises** : sans elles l'appel est rejeté. Les autres entrées ont un défaut : voir la doc.
- **Secrets** : optionnels sauf ceux marqués « requis » ; les paires `APP_CLIENT_ID` + `APP_PRIVATE_KEY` vont
  **ensemble ou pas du tout** (voir le skill `fabnum-cicd-auth`).
- **Permissions** : l'union de celles de tous les jobs du workflow appelé. GitHub les valide au parsing, même pour un
  job qui ne tourne pas : l'appelant doit toutes les accorder (`security-events`, `pull-requests`… y compris).

| Workflow | Usage | Entrées requises | Secrets | Permissions à accorder | Doc |
| --- | --- | --- | --- | --- | --- |
| `attest-docker` | Provenance SLSA, SBOM, signature cosign d'une image poussée | `IMAGE_NAME`, `DIGEST` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `attestations: write`, `id-token: write`, `packages: write` | [31](../../../docs/workflows/31-attest-docker.md) |
| `attest-helm` | Signer (cosign) et attester (SLSA) des charts publiés en OCI | `CHARTS` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `attestations: write`, `id-token: write`, `packages: write` | [56](../../../docs/workflows/56-attest-helm.md) |
| `build-docker` | Build multi-arch, push optionnel ; sorties `digest`, `image` | `IMAGE_NAME`, `IMAGE_TAG`, `IMAGE_DOCKERFILE`, `IMAGE_CONTEXT` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `BUILD_SECRETS`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: read`, `packages: write` | [30](../../../docs/workflows/30-build-docker.md) |
| `build-python` | Construire le paquet et contrôler la wheel ; artefact `dist/` | — | — | `contents: read` | [32](../../../docs/workflows/32-build-python.md) |
| `check-jobs` | Un seul check exigible qui agrège tous les jobs | `NEEDS` | — | `{}` | [80](../../../docs/workflows/80-check-jobs.md) |
| `clean-cache` | Supprimer les caches d'une PR fermée | — | — | `actions: write` | [70](../../../docs/workflows/70-clean-cache.md) |
| `clean-images` | Supprimer des images GHCR de PR fermées | `IMAGE` | — | `packages: write` | [71](../../../docs/workflows/71-clean-images.md) |
| `dispatch-helm-chart` | Déclencher la mise à jour d'un chart hébergé dans un autre dépôt | `CHART_REPO`, `CHART_NAME` | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `{}` | [54](../../../docs/workflows/54-dispatch-helm-chart.md) |
| `lint-commits` | Vérifier les Conventional Commits d'une PR | — | — | `contents: read` | [10](../../../docs/workflows/10-lint-commits.md) |
| `lint-helm-schema` | Valider les values d'un chart contre un JSON Schema | `CHART_PATH` | — | `contents: read` | [12](../../../docs/workflows/12-lint-helm-schema.md) |
| `lint-helm` | Lint des charts (chart-testing) et de leur doc (helm-docs) | `CT_CONF_PATH` | — | `contents: read` | [11](../../../docs/workflows/11-lint-helm.md) |
| `lint-python` | Lint et vérification de types d'un projet Python (uv) | — | — | `contents: read` | [15](../../../docs/workflows/15-lint-python.md) |
| `lint-yaml` | yamllint sur un dossier | — | — | `contents: read` | [14](../../../docs/workflows/14-lint-yaml.md) |
| `release-app` | release-please : PR de release, tags, changelog, pré-release ; sorties `release-created`, `version` | — | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: write`, `issues: write`, `pull-requests: write` | [50](../../../docs/workflows/50-release-app.md) |
| `release-helm-local` | Publier en OCI le chart d'un dépôt applicatif / monorepo | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `contents: read`, `packages: write` | [52](../../../docs/workflows/52-release-helm-local.md) |
| `release-helm` | Publier des charts depuis un dépôt de charts dédié (OCI et/ou GitHub Pages) | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT`, `GPG_PRIVATE_KEY`, `GPG_PASSPHRASE` | `contents: write`, `packages: write` | [51](../../../docs/workflows/51-release-helm.md) |
| `release-npm` | Publier un paquet npm (npmjs.org, GitHub Packages, registre privé) | — | `NPM_TOKEN` | `contents: read`, `id-token: write` | [55](../../../docs/workflows/55-release-npm.md) |
| `release-pypi` | Publier sur PyPI les distributions de `build-python` | `ARTIFACT` | `PYPI_TOKEN` | `id-token: write` | [58](../../../docs/workflows/58-release-pypi.md) |
| `scan-gitleaks` | Secrets dans tout l'historique git | — | — | `contents: read`, `pull-requests: write`, `security-events: write` | [42](../../../docs/workflows/42-scan-gitleaks.md) |
| `scan-sonarqube` | Qualité du code (SonarQube) | `SONAR_URL` | `SONAR_TOKEN` (requis), `SONAR_PROJECT_KEY` (requis) | `contents: read`, `issues: write`, `pull-requests: write` | [40](../../../docs/workflows/40-scan-sonarqube.md) |
| `scan-trivy` | Vulnérabilités : image (`IMAGE`), configuration (`PATH`) ou tarball | — | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD`, `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: read`, `packages: read`, `pull-requests: write`, `security-events: write` | [41](../../../docs/workflows/41-scan-trivy.md) |
| `scan-zizmor` | Audit de sécurité des workflows GitHub Actions | — | — | `contents: read` | [45](../../../docs/workflows/45-scan-zizmor.md) |
| `sync-cpin` | Déclencher la synchro vers GitLab CPiN (voir doc 72) | `GITLAB_URL`, `GIT_MIRROR_PROJECT_ID`, `REPOSITORY_NAME` | `GIT_MIRROR_TOKEN` (requis) | `{}` | [72](../../../docs/workflows/72-sync-cpin.md) |
| `sync-prerelease-branch` | Rebaser la branche de pré-release sur celle de release (dernier job) | — | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` | `contents: write` | [57](../../../docs/workflows/57-sync-prerelease-branch.md) |
| `test-docker` | Exécuter une commande dans une image (registre ou tarball) | `COMMAND` | `REGISTRY_USERNAME`, `REGISTRY_PASSWORD` | `contents: read`, `packages: read` | [24](../../../docs/workflows/24-test-docker.md) |
| `test-helm` | `ct install` dans un cluster Kind | `CT_CONF_PATH` | — | `contents: read` | [20](../../../docs/workflows/20-test-helm.md) |
| `test-python` | Tests Python (uv), couverture en artefact | — | — | `contents: read` | [22](../../../docs/workflows/22-test-python.md) |
| `update-helm-chart` | Mettre à jour `Chart.yaml` (`RUN_MODE: local` ou `called`) ; sortie `commit-sha` | `RUN_MODE` | `APP_CLIENT_ID`, `APP_PRIVATE_KEY`, `GH_PAT` | `contents: write`, `pull-requests: write` | [53](../../../docs/workflows/53-update-helm-chart.md) |
