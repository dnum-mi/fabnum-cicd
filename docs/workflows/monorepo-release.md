# Release d'un monorepo

Ce document explique comment publier **plusieurs applications** (ex: une API et un frontend) hébergées dans le **même dépôt**, avec un **chart Helm unique** qui déploie les deux services.

## Pourquoi un orchestrateur dédié ?

- Construire et pousser chaque image Docker en parallèle.
- Générer la provenance et le SBOM pour chaque image via [`attest-docker.yml`](./attest-docker.md).
- Créer **une seule** version / PR release-please pour tout le dépôt, afin que le chart et les images partagent la même version.
- Publier le chart Helm en mode `local` (le partage de l'espace de tags entre les applications et le chart rend la détection automatique de chart-releaser peu fiable dans un monorepo) - voir [`release-helm.yml`](./release-helm.md) et [`update-helm-chart.yml`](./update-helm-chart.md).

## Workflow orchestrateur (`.github/workflows/cd.yml`)

```yaml
name: Release monorepo (API + Frontend)

on:
  push:
    branches:
    - main

jobs:
  # -------------------------------------------------
  # 1. Release-please : une seule version pour tout le dépôt
  # -------------------------------------------------
  release:
    uses: ./.github/workflows/release-app.yml
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      TAG_MAJOR_AND_MINOR: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  # -------------------------------------------------
  # 2. Build des deux images Docker (matrice)
  # -------------------------------------------------
  build:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    strategy:
      matrix:
        component: [api, front]
    uses: ./.github/workflows/build-docker.yml
    permissions:
      packages: write
      contents: read
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository }}/${{ matrix.component }}
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      LATEST_TAG: true
      IMAGE_DOCKERFILE: apps/${{ matrix.component }}/Dockerfile
      IMAGE_CONTEXT: apps/${{ matrix.component }}
      PROVENANCE: true
      SBOM: true

  # -------------------------------------------------
  # 3. Mise à jour du chart (commit direct, mode local)
  # -------------------------------------------------
  update-chart:
    needs:
    - release
    - build
    uses: ./.github/workflows/update-helm-chart.yml
    permissions:
      contents: write
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      UPGRADE_TYPE: minor

  # -------------------------------------------------
  # 4. Publication du chart (mode local)
  # -------------------------------------------------
  release-chart:
    needs:
    - release
    - update-chart
    uses: ./.github/workflows/release-helm.yml
    permissions:
      packages: write
    with:
      MODE: local
      CHART_NAME: my-app
      CHART_VERSION: ${{ needs.update-chart.outputs.chart-version }}
      APP_VERSION: ${{ needs.release.outputs.version }}
      CHECKOUT_REF: ${{ needs.update-chart.outputs.commit-sha }}
```

### Fonctionnement

1. **Release-please** – [`release-app.yml`](./release-app.md) crée une unique version/tag/PR pour tout le dépôt, garantissant que le chart Helm et les images applicatives partagent la même version.
2. **Build** – [`build-docker.yml`](./build-docker.md) construit et pousse les images `api` et `front` en parallèle (matrice), avec attestation SLSA + SBOM intégrée (`PROVENANCE`/`SBOM`).
3. **Update chart** – [`update-helm-chart.yml`](./update-helm-chart.md) en mode `local` incrémente la version du chart, met à jour `appVersion`, régénère la doc, puis commit et pousse directement sur la branche courante (aucune PR). Expose `chart-version` et `commit-sha`.
4. **Release chart** – [`release-helm.yml`](./release-helm.md) en mode `local` package le chart au commit produit à l'étape précédente (`CHECKOUT_REF`) et le pousse sur le registre OCI.

### Avantages

- **Releases atomiques** – Les applications et le chart sont publiés ensemble, sans dérive de version.
- **Réutilisation des workflows existants** – Aucune logique dupliquée, uniquement de l'orchestration.
- **Adapté au monorepo** – Les modes `local` de `update-helm-chart.yml` et `release-helm.yml` s'affranchissent des tags git partagés entre applications et chart, contrairement à `chart-releaser`.
- **Extensible** – Ajouter un nouveau composant revient à étendre la liste `matrix.component`.
