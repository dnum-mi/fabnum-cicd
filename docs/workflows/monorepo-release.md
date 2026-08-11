# Release d'un monorepo

Ce document explique comment publier **plusieurs applications** (ex: une API et un frontend) hébergées dans le **même dépôt**, avec un **chart Helm unique** qui déploie les deux services.

Le pipeline suit le flux git à deux branches : les pushes sur `develop` publient des release candidates (`1.2.3-rc.4`, chart `0.4.2-rc.1`), la promotion `develop` → `main` publie les versions finales. Pour un dépôt mono-branche, retirez `develop` du trigger, `ENABLE_PRERELEASE` et le job `sync-prerelease-branch`.

## Pourquoi un orchestrateur dédié ?

- Construire et pousser chaque image Docker en parallèle.
- Générer la provenance et le SBOM pour chaque image via [`attest-docker.yml`](./attest-docker.md).
- Créer **une seule** version / PR release-please pour tout le dépôt, afin que le chart et les images partagent la même version.
- Publier le chart Helm via [`release-helm-local.yml`](./release-helm-local.md) (le partage de l'espace de tags entre les applications et le chart rend la détection automatique de chart-releaser peu fiable dans un monorepo) - voir aussi [`update-helm-chart.yml`](./update-helm-chart.md).

## Workflow orchestrateur (`.github/workflows/cd.yml`)

```yaml
name: Release monorepo (API + Frontend)

on:
  push:
    branches:
    - develop
    - main

jobs:
  # -------------------------------------------------
  # 1. Release-please : une seule version pour tout le dépôt
  # -------------------------------------------------
  # Sur `develop`, release-please publie des release candidates ; sur `main`,
  # les versions finales. La branche courante sélectionne le couple
  # config/manifest correspondant.
  release:
    uses: ./.github/workflows/release-app.yml
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      TAG_MAJOR_AND_MINOR: true
      ENABLE_PRERELEASE: true
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}

  # -------------------------------------------------
  # 2. Build + attestation de chaque image
  # -------------------------------------------------
  # Une matrice ne convient pas ici : `needs.<job>.outputs.<name>` s'effondre
  # en une seule valeur à travers toutes les combinaisons d'une matrice
  # (comportement documenté de GitHub), donc un job `attest` matricé de la
  # même façon attesterait silencieusement la mauvaise image pour tous les
  # composants sauf le dernier. Une paire build/attest explicite par
  # composant est plus verbeuse mais indépendamment correcte - voir
  # build-docker.yml > Builds en matrice.
  build-api:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: ./.github/workflows/build-docker.yml
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository }}/api
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      LATEST_TAG: true
      IMAGE_DOCKERFILE: apps/api/Dockerfile
      IMAGE_CONTEXT: apps/api

  attest-api:
    needs: build-api
    uses: ./.github/workflows/attest-docker.yml
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ${{ needs.build-api.outputs.image }}
      DIGEST: ${{ needs.build-api.outputs.digest }}
      PROVENANCE: true
      SBOM: true

  build-front:
    needs: release
    if: ${{ needs.release.outputs.release-created }}
    uses: ./.github/workflows/build-docker.yml
    permissions:
      packages: write
      contents: read
    with:
      IMAGE_NAME: ghcr.io/${{ github.repository }}/front
      IMAGE_TAG: ${{ needs.release.outputs.version }}
      LATEST_TAG: true
      IMAGE_DOCKERFILE: apps/front/Dockerfile
      IMAGE_CONTEXT: apps/front

  attest-front:
    needs: build-front
    uses: ./.github/workflows/attest-docker.yml
    permissions:
      packages: write
      id-token: write
      attestations: write
    with:
      IMAGE_NAME: ${{ needs.build-front.outputs.image }}
      DIGEST: ${{ needs.build-front.outputs.digest }}
      PROVENANCE: true
      SBOM: true

  # -------------------------------------------------
  # 3. Mise à jour du chart (commit direct, mode local)
  # -------------------------------------------------
  update-chart:
    needs:
    - release
    - build-api
    - build-front
    uses: ./.github/workflows/update-helm-chart.yml
    permissions:
      contents: write
    with:
      RUN_MODE: local
      CHART_NAME: my-app
      APP_VERSION: ${{ needs.release.outputs.version }}
      # 'auto' fait refléter au chart le bump de l'application (delta
      # d'appVersion) et choisit le flux d'après la forme d'APP_VERSION :
      # cycle rc sur develop, version finale sur main - une seule valeur pour
      # les deux branches.
      UPGRADE_TYPE: auto
      PRERELEASE_IDENTIFIER: rc

  # -------------------------------------------------
  # 4. Publication du chart
  # -------------------------------------------------
  release-chart:
    needs:
    - update-chart
    uses: ./.github/workflows/release-helm-local.yml
    permissions:
      contents: read
      packages: write
    with:
      CHART_NAME: my-app
      # Package exactement le commit de bump poussé par update-helm-chart
      CHECKOUT_REF: ${{ needs.update-chart.outputs.commit-sha }}

  # -------------------------------------------------
  # 5. Resynchronisation de la branche de pré-release
  # -------------------------------------------------
  # C'est la forme de dépôt qui rend ce job obligatoire : `update-chart`
  # commite la version publiée du chart sur `main` APRÈS le job de release, il
  # doit donc figurer dans `needs:` - sinon `develop` conserve un Chart.yaml
  # figé au dernier release candidate et son prochain bump passe SOUS ce que
  # `main` vient de publier.
  #
  # `release-chart` est volontairement absent : il publie, il ne commite pas,
  # et le lister laisserait une publication en échec sauter la synchronisation.
  sync-prerelease-branch:
    needs:
    - release
    - update-chart
    uses: ./.github/workflows/sync-prerelease-branch.yml
    if: ${{ github.ref_name == 'main' && needs.release.outputs.release-created == 'true' }}
    permissions:
      contents: write
    with:
      RELEASE_BRANCH: main
      PRERELEASE_BRANCH: develop
```

### Fonctionnement

1. **Release-please** – [`release-app.yml`](./release-app.md) crée une unique version/tag/PR pour tout le dépôt, garantissant que le chart Helm et les images applicatives partagent la même version. Avec `ENABLE_PRERELEASE`, le dépôt porte deux couples config/manifest release-please : `release-please-config.json` + `.release-please-manifest.json` pour `main`, `release-please-config-rc.json` + `.release-please-manifest-rc.json` pour `develop` (voir [release-app.md](./release-app.md) pour leur contenu).
2. **Build + attest** – [`build-docker.yml`](./build-docker.md) construit et pousse chaque image, puis [`attest-docker.yml`](./attest-docker.md) génère la provenance SLSA et le SBOM pour cette image précise - une paire de jobs par composant, pas une matrice (voir l'encart dans le YAML ci-dessus).
3. **Update chart** – [`update-helm-chart.yml`](./update-helm-chart.md) en mode `local` incrémente la version du chart, met à jour `appVersion`, régénère la doc, puis commit et pousse directement sur la branche courante (aucune PR). Expose `chart-version` et `commit-sha`.
4. **Release chart** – [`release-helm-local.yml`](./release-helm-local.md) package le chart au commit produit à l'étape précédente (`CHECKOUT_REF`) et le pousse sur le registre OCI.
5. **Sync pré-release** – [`sync-prerelease-branch.yml`](./sync-prerelease-branch.md) rebase `develop` sur `main` une fois que celle-ci a cessé de bouger, pour que la prochaine pré-release parte de l'état publié. [`release-app.yml`](./release-app.md#assertion-de-synchronisation) assère le résultat au run suivant sur `develop` : oublier ce job échoue là, plutôt que de produire silencieusement une version trop basse.

### Avantages

- **Releases atomiques** – Les applications et le chart sont publiés ensemble, sans dérive de version.
- **Réutilisation des workflows existants** – Aucune logique dupliquée, uniquement de l'orchestration.
- **Adapté au monorepo** – Le mode `local` de `update-helm-chart.yml` et [`release-helm-local.yml`](./release-helm-local.md) s'affranchissent des tags git partagés entre applications et chart, contrairement à `chart-releaser`.
- **Extensible** – Ajouter un nouveau composant revient à ajouter sa paire de jobs `build-<composant>`/`attest-<composant>` (copier-coller, pas une ligne de matrice, mais chaque paire reste indépendamment correcte).

### Variante : monorepo sans chart Helm

Supprimez les jobs `update-chart` et `release-chart`, et réduisez le `needs:` de `sync-prerelease-branch` à `[release]` — plus rien d'autre ne commite sur `main` après la release. Le reste du pipeline est inchangé.
