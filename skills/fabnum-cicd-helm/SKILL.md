---
name: fabnum-cicd-helm
description: Use when linting, testing, versioning, publishing or signing Helm charts with fabnum-cicd — lint-helm, lint-helm-schema, test-helm, update-helm-chart, release-helm, release-helm-local, attest-helm, or dispatching a chart bump to a separate chart repository (dispatch-helm-chart)
allowed-tools: Bash Read Write
---

# Charts Helm avec fabnum-cicd

Aider l'utilisateur à brancher le cycle de vie d'un chart Helm : contrôle, version, publication, signature. Doc
détaillée, à lire avant d'écrire un appel : `../../docs/workflows/11-lint-helm.md`, `12`, `20`, `51` à `54`, `56`.
Les contraintes d'une plateforme de déploiement précise (règles d'admission, quotas) ne sont pas traitées ici.

## Où vit le chart ? (première question)

| Situation | Chaîne de workflows |
|-----------|--------------------|
| Chart **dans le dépôt applicatif** (monorepo) | `update-helm-chart` (`RUN_MODE: local`) → `release-helm-local` (OCI) |
| Chart dans un **dépôt séparé**, déclenché par l'app | dépôt app : `dispatch-helm-chart` ; dépôt chart : un workflow d'entrée qui appelle `update-helm-chart` (`RUN_MODE: called`) |
| **Dépôt de charts dédié**, publié sur OCI et/ou GitHub Pages | `release-helm` (chart-releaser) |

Ne pas utiliser `release-helm` dans un monorepo applicatif : les tags de l'application noient la détection de
changement de chart-releaser. Les versions du chart et de l'application sont **volontairement découplées**.

## Contrôler

- `lint-helm` : `ct lint` + vérification du README généré par helm-docs. `CT_CONF_PATH` (config `chart-testing`) est
  requis ; `CHARTS_DIR` doit correspondre aux `chart-dirs` de cette config.
- `lint-helm-schema` : valide les values contre un JSON Schema (`CHART_PATH` requis).
- `test-helm` : `ct install` dans un cluster Kind (`CT_CONF_PATH` requis).
- Tous trois : `permissions: contents: read`.

## Monorepo : bump puis publication

```yaml
  bump-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    needs: [release, build]
    if: ${{ needs.release.outputs.release-created == 'true' }}
    permissions:
      contents: write
      pull-requests: write          # exigé même en mode local (union des permissions)
    with:
      RUN_MODE: local
      CHART_NAME: <chart>
      CHART_DIR: charts
      APP_VERSION: ${{ needs.release.outputs.version }}
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}

  release-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-helm-local.yml@v0
    needs: [bump-chart]
    permissions:
      contents: read
      packages: write
    with:
      CHARTS_DIR: charts
      CHART_NAME: <chart>
      CHECKOUT_REF: ${{ needs.bump-chart.outputs.commit-sha }}
```

- `update-helm-chart` expose `chart-version`, `previous-chart-version` et `commit-sha` (mode `local` seulement).
- `release-helm-local` ne crée ni tag ni release ; il refuse d'écraser une version déjà publiée
  (`ALLOW_OVERWRITE: false`). Avec un registre autre que `ghcr.io`, `REGISTRY_USERNAME` / `REGISTRY_PASSWORD` sont requis.
- Si le dépôt a une branche de pré-release, le job de bump **commite sur `main`** : le lister dans le `needs` de
  `sync-prerelease-branch` (skill `fabnum-cicd-release`).

## Chart dans un dépôt séparé

Côté **dépôt applicatif** (l'App doit être installée sur le dépôt du chart, skill `fabnum-cicd-auth`) :

```yaml
  dispatch-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/dispatch-helm-chart.yml@v0
    needs: [release]
    if: ${{ needs.release.outputs.release-created == 'true' }}
    permissions: {}
    with:
      CHART_REPO: <org>/<chart-repo>          # forme owner/repo obligatoire
      CHART_NAME: <chart>
      CHART_DIR: charts
      APP_VERSION: ${{ needs.release.outputs.version }}
      # BASE_BRANCH: develop                  # si la branche par défaut du dépôt chart n'est pas main
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Côté **dépôt du chart**, `.github/workflows/update-app-version.yml` (nom attendu par défaut ; sinon passer
`WORKFLOW_NAME`) doit déclarer **tous** les inputs que le dispatch envoie, sinon l'API rejette le dispatch (422) :

```yaml
name: Update app version

on:
  workflow_dispatch:
    inputs:
      RUN_MODE: { required: false, default: called }
      APP_VERSION: { required: false }
      CHART_NAME: { required: true }
      CHART_DIR: { required: false, default: charts }
      UPGRADE_TYPE: { required: false, default: auto }
      PRERELEASE_IDENTIFIER: { required: false, default: rc }
      AUTOMERGE_PRERELEASE: { required: false, default: "false" }
      AUTOMERGE_RELEASE: { required: false, default: "false" }
      AUTOMERGE_METHOD: { required: false, default: auto }

jobs:
  update-chart:
    uses: dnum-mi/fabnum-cicd/.github/workflows/update-helm-chart.yml@v0
    permissions:
      contents: write
      pull-requests: write
    with:
      RUN_MODE: called
      CHART_NAME: ${{ inputs.CHART_NAME }}
      CHART_DIR: ${{ inputs.CHART_DIR }}
      APP_VERSION: ${{ inputs.APP_VERSION }}
      UPGRADE_TYPE: ${{ inputs.UPGRADE_TYPE }}
      PRERELEASE_IDENTIFIER: ${{ inputs.PRERELEASE_IDENTIFIER }}
      AUTOMERGE_PRERELEASE: ${{ inputs.AUTOMERGE_PRERELEASE == 'true' }}
      AUTOMERGE_RELEASE: ${{ inputs.AUTOMERGE_RELEASE == 'true' }}
      AUTOMERGE_METHOD: ${{ inputs.AUTOMERGE_METHOD }}
      BASE_BRANCH: ${{ github.ref_name }}
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

- Le dispatch est **asynchrone** : le job applicatif est vert dès que le dispatch est accepté. Vérifier le run côté
  chart (`gh run list -R <org>/<chart-repo>` si `gh` est disponible).
- Avec un token App, la PR de bump déclenche la CI du dépôt chart (avec `GITHUB_TOKEN`, non).

## Dépôt de charts dédié

`release-helm` : au moins un canal actif parmi `CREATE_GITHUB_RELEASE` (défaut `true` : release GitHub par chart + `index.yaml`
sur `PAGES_BRANCH`, qui doit **déjà exister**) et `PUBLISH_OCI`. Pièges documentés :

1. **GitHub Pages est public même sur un dépôt privé** : `index.yaml` y expose les noms et versions des charts. Préférer OCI seul.
2. `CREATE_GITHUB_RELEASE: true` est **incompatible avec les releases immuables** : utiliser `PUBLISH_OCI: true` seul.
3. `SIGN_CHART` (GPG) exige `CREATE_GITHUB_RELEASE`, `SIGNING_KEY_ID`, `GPG_PRIVATE_KEY` et `GPG_PASSPHRASE`.

## Signer et attester (OCI)

`attest-helm` : signature cosign et provenance SLSA des charts déjà publiés sur un registre OCI. `CHARTS` requis ;
permissions `packages: write`, `id-token: write`, `attestations: write`. À appeler après la publication, avec la
sortie `published-charts` de `release-helm` ou `release-helm-local`.

## Aller plus loin

- Docs : `../../docs/workflows/51-release-helm.md` à `54-dispatch-helm-chart.md`, `56-attest-helm.md`.
- Entrées, secrets et permissions de chaque workflow : `../fabnum-cicd-pipeline/references/workflows.md`.
