# Environnements de preview par Pull Request

Ce guide explique comment un dépôt applicatif se branche sur le système d'environnements de preview par Pull Request utilisé dans l'organisation **AI-Generative** : chaque PR labellisée `preview` obtient automatiquement son propre namespace Kubernetes et sa propre URL, déployés par ArgoCD à partir de l'image que la PR construit. À la fermeture de la PR (ou au retrait du label), tout est supprimé automatiquement.

La moitié CI/CD de ce pattern (build, push, commentaire de PR, nettoyage planifié) est générique et repose sur les workflows réutilisables de ce dépôt — c'est elle que ce guide détaille. La moitié infra (ApplicationSet ArgoCD, pull secret ghcr partagé, DNS, certificat) est spécifique au cluster cible et gérée par l'équipe plateforme, hors du périmètre de `fabnum-cicd` : voir [Côté infra](#côté-infra) pour ce qu'il reste à demander une fois votre dépôt prêt.

Référence vivante : `IA-Generative/mirai-api` est le premier dépôt onboardé sur ce pattern.

## Comment ça marche

1. Une PR reçoit le label `preview`.
2. Le workflow GitHub Actions de **votre dépôt** construit l'image Docker de la PR et la pousse sur **ghcr.io** (privé), avec un tag stable `pr-<numéro>` — réécrit à chaque nouveau commit sur la PR. Il commente la PR avec l'URL de preview.
3. L'`ApplicationSet` de l'ArgoCD central détecte la PR (polling GitHub, ~2 min), et crée :
   - un namespace `preview-<clé>-<numéro>`
   - une Application ArgoCD qui déploie votre **chart Helm**, à la révision de la PR, avec l'image et l'hôte de cette PR injectés dans les values
4. À la fermeture de la PR (ou au retrait du label `preview`), l'Application ArgoCD est supprimée — ce qui supprime aussi le namespace.
5. Un balayage planifié (quotidien) côté dépôt applicatif supprime de ghcr les images des PR fermées récemment.

Rien de tout ça n'est à réimplémenter par votre projet : uniquement les étapes 2 et 5 (build, push, commentaire, nettoyage) sont dans votre dépôt — et elles s'appuient sur les workflows réutilisables [`build-docker.yml`](./30-build-docker.md) et [`clean-images.yml`](./71-clean-images.md) plutôt que sur du code à écrire de zéro. Le reste (3 et 4) est déjà générique côté infra.

## Deux modèles pour déclencher le redéploiement

### Générateur `pullRequest` (ce que documente ce guide)

C'est le modèle utilisé par AI-Generative : l'`ApplicationSet` ArgoCD (générateur `pullRequest`) crée et supprime lui-même l'Application par PR, en pollant GitHub. Votre workflow n'appelle jamais l'API ArgoCD et n'a besoin d'aucun token ArgoCD — il pousse une image, ArgoCD fait le reste.

Point d'attention avec un **tag d'image stable** (`pr-<n>`, réécrit à chaque push) : ArgoCD ne resynchronise que lorsque le manifest rendu change. Le tag étant identique d'un commit à l'autre, rien ne change dans le manifest, donc rien ne force le Pod à être recréé — même avec `pullPolicy: Always`, qui ne joue qu'au moment où un Pod est (re)créé, pas sur un Pod déjà en cours d'exécution. La correction est déclarative et ne nécessite aucun appel API : faire porter au chart une annotation de Pod qui, elle, change à chaque commit — par exemple `podAnnotations: {"preview/commit": "<head_short_sha>"}`, injectée par l'ApplicationSet. Changer une annotation du **template** de Pod (`spec.template.metadata.annotations`, pas seulement les metadata de l'objet Deployment) force Kubernetes à recréer les Pods, qui re-tirent alors l'image `pr-<n>` à jour grâce à `pullPolicy: Always` — c'est le même principe que l'annotation `checksum/config` classique en Helm pour forcer un rollout sur un changement de configuration. Voir [Ce que votre dépôt doit fournir](#1-un-chart-helm) pour l'exigence côté chart.

### Alternative : sync explicite via l'API ArgoCD

Si vos Applications de preview ne sont pas créées par un générateur `pullRequest` (par exemple une seule Application par dépôt, dont les manifests ciblés changent par PR), la CI peut déclencher elle-même un `sync` ArgoCD après chaque push, via [`argocd-preview.yml`](https://github.com/this-is-tobi/github-workflows/blob/main/docs/60-argocd-preview.md) (`this-is-tobi/github-workflows`) :

```yaml
jobs:
  preview:
    uses: this-is-tobi/github-workflows/.github/workflows/argocd-preview.yml@v0
    permissions:
      pull-requests: write
    with:
      APP_URL_TEMPLATE: https://<votre-clé>-pr-<pr_number>.preview.<domaine-cluster>
      PR_NUMBER: ${{ github.event.pull_request.number }}
      ARGOCD_APP_NAME_TEMPLATE: <votre-clé>-pr-<pr_number>
      ARGOCD_SYNC_PAYLOAD_TEMPLATE: '{"appNamespace":"argocd","prune":true,"dryRun":false,"strategy":{"hook":{"force":true}},"syncOptions":{"items":["Replace=true"]}}'
      ARGOCD_URL: https://argo-cd.example.com
    secrets:
      ARGOCD_TOKEN: ${{ secrets.ARGOCD_TOKEN }}
```

Différences avec le générateur `pullRequest` :

- L'Application `<votre-clé>-pr-<pr_number>` doit déjà exister au moment du `sync` — ce workflow ne la crée pas, il la resynchronise. Sa création (et sa suppression à la fermeture de la PR) reste à assurer par ailleurs.
- La CI a besoin d'un accès réseau au serveur ArgoCD et d'un token (`ARGOCD_TOKEN`) avec droit de `sync` — un couplage que le générateur `pullRequest` évite entièrement.
- En contrepartie, le redéploiement est immédiat après le push (pas de dépendance au polling GitHub d'ArgoCD, ni au détour par une annotation de Pod) : `syncOptions: ["Replace=true"]` force le remplacement des ressources même sans changement de manifest détecté.
- Le même dépôt fournit aussi [`preview-comment.yml`](https://github.com/this-is-tobi/github-workflows/blob/main/docs/61-preview-comment.md), équivalent à `sticky-pull-request-comment` utilisé ci-dessous.

Les deux modèles ne se combinent pas sans changer la façon dont les Applications de preview sont provisionnées côté infra — choisissez-en un.

## Ce que votre dépôt doit fournir

### 1. Un chart Helm

Par défaut, le chart est attendu au chemin **`helm/`** à la racine du dépôt (indiquez-le si votre convention diffère — voir [Côté infra](#côté-infra)). Deux attentes sur le chart lui-même :

- **`image.repository` et `image.tag` surchargeables** dans les values (ce sont eux que l'ApplicationSet injecte par PR).
- **`imagePullSecrets` avec un secret nommé `registry-pull-secret` en valeur par défaut**, pour que le chart utilise sans rien à faire le secret de pull déposé automatiquement dans chaque namespace de preview :

  ```yaml
  # values.yaml
  imagePullSecrets:
    - name: registry-pull-secret
  ```

- **`image.pullPolicy: Always`** pour le déploiement de preview (le tag `pr-<n>` est stable et réutilisé à chaque commit ; avec `IfNotPresent`, un nouveau commit ne serait pas re-tiré).
- **Un `podAnnotations` (ou équivalent) propagé au template du Pod** (`spec.template.metadata.annotations`, pas seulement les metadata du Deployment), surchargeable dans les values — c'est ce qui force un rollout à chaque commit avec un tag stable. Voir [Générateur `pullRequest`](#générateur-pullrequest-ce-que-documente-ce-guide) pour le détail.

Le reste (ingress, service, resources…) suit vos conventions habituelles ; seuls les champs `image`, `ingress.hosts`/`ingress.tls` et `podAnnotations` seront surchargés par PR.

### 2. Une image publiée sur ghcr.io (privé)

Le registre par défaut est `ghcr.io/<votre-org>/<votre-image>`, en **privé**. Le tag doit être `pr-<numéro de PR>` — stable pour toute la durée de vie de la PR, réécrit à chaque push.

### 3. Un label `preview` sur le dépôt

```bash
gh label create preview --repo <votre-org>/<votre-repo> \
  --color 1d76db --description "Deploy a temporary preview environment for this PR"
```

Seules les PR portant ce label déclenchent un build et un déploiement. Ça évite de consommer des ressources sur chaque PR ouverte.

### 4. Deux workflows GitHub Actions

Construits sur [`build-docker.yml`](./30-build-docker.md) et [`clean-images.yml`](./71-clean-images.md) plutôt que sur des étapes `docker build`/`docker push` écrites à la main : même comportement de cache, de métadonnées d'image et de nettoyage d'un dépôt à l'autre.

#### `preview.yml` — build et commentaire

```yaml
name: Preview

on:
  pull_request:
    types: [opened, synchronize, reopened, labeled]

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  build:
    # Seulement les PR labellisées "preview", jamais une PR de fork (pas d'accès aux secrets/packages).
    if: >-
      contains(github.event.pull_request.labels.*.name, 'preview') &&
      github.event.pull_request.head.repo.full_name == github.repository
    uses: dnum-mi/fabnum-cicd/.github/workflows/build-docker.yml@v0
    permissions:
      contents: read
      packages: write
    with:
      IMAGE_NAME: ghcr.io/<votre-org>/<votre-image>
      IMAGE_TAG: pr-${{ github.event.pull_request.number }}
      IMAGE_DOCKERFILE: ./Dockerfile
      IMAGE_CONTEXT: .
      # IMAGE_TARGET: prod   # si votre Dockerfile a un stage de prod dédié
      BUILD_AMD64: true
      BUILD_ARM64: false

  comment:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - name: Comment preview URL
        uses: marocchino/sticky-pull-request-comment@5770ad5eb8f42dd2c4f34da00c94c5381e49af88 # v3.0.5
        with:
          header: preview
          message: |
            🔍 Preview: https://<votre-clé>-pr-${{ github.event.pull_request.number }}.preview.<domaine-cluster>

            *Déployée par ArgoCD, la mise à jour peut prendre quelques minutes.*
```

`comment` hérite du `if` de `build` via `needs:` : si `build` est ignoré (PR non labellisée, ou fork), `comment` l'est aussi, sans avoir à répéter la condition. [`sticky-pull-request-comment`](https://github.com/marocchino/sticky-pull-request-comment) maintient un unique commentaire (identifié par `header`) plutôt que d'en empiler un par push.

#### `clean-preview-images.yml` — nettoyage planifié

Un balayage quotidien plutôt qu'un déclenchement sur `pull_request: closed` : fermer une PR et finir de pousser son image sont deux événements qui peuvent se chevaucher, le déclencheur `closed` n'est donc pas fiable pour ce nettoyage — voir [Balayage planifié](./71-clean-images.md#balayage-planifié-recommandé) pour le détail.

```yaml
name: Clean preview images

on:
  schedule:
    - cron: "0 1 * * *"
  workflow_dispatch:

jobs:
  list-closed-prs:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: read
    outputs:
      prs: ${{ steps.list.outputs.prs }}
    steps:
      - id: list
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
        run: |
          set -euo pipefail
          CUTOFF=$(date -u -d "3 days ago" +%Y-%m-%dT%H:%M:%SZ)
          PRS=$(gh pr list -R "$REPO" --state closed --limit 100 \
            --json number,closedAt \
            | jq -c --arg c "$CUTOFF" '[.[] | select(.closedAt >= $c) | {number}]')
          echo "prs=$PRS" >> "$GITHUB_OUTPUT"

  sweep-images:
    needs: list-closed-prs
    if: ${{ needs.list-closed-prs.outputs.prs != '[]' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-images.yml@v0
    permissions:
      packages: write
    strategy:
      fail-fast: false
      matrix:
        pr: ${{ fromJSON(needs.list-closed-prs.outputs.prs) }}
    with:
      IMAGE: ghcr.io/<votre-org>/<votre-image>:pr-${{ matrix.pr.number }}
```

Référence vivante : `.github/workflows/preview.yml` et `.github/workflows/clean-preview-images.yml` sur `IA-Generative/mirai-api`.

## Côté infra

L'onboarding sur l'ApplicationSet, le pull secret ghcr partagé, le DNS et le certificat ne sont **pas self-service** — inutile de chercher à les configurer vous-même, et cette partie n'est pas détaillée ici puisqu'elle est spécifique au cluster cible, pas à `fabnum-cicd`.

**Une fois votre chart Helm et vos deux workflows prêts et testés (build local d'une image, `helm template`/`helm lint` sans erreur), ouvrez un ticket auprès de l'équipe plateforme** pour demander l'onboarding de votre dépôt sur le système de preview. Précisez :

- le dépôt (`<org>/<repo>`) et le chemin du chart s'il diffère de `helm/`
- le nom de l'image ghcr (`ghcr.io/<org>/<image>`)
- l'hôte de preview souhaité (voir [Conventions de nommage](#conventions-de-nommage))

L'équipe plateforme s'occupe du reste : entrée dans l'ApplicationSet, autorisation du compte de pull partagé sur votre package ghcr, DNS et certificat.

## Conventions de nommage

| Élément                      | Motif                                                |
| ------------------------------ | ------------------------------------------------------ |
| Namespace                      | `preview-<clé>-<numéro de PR>`                        |
| Application ArgoCD             | `preview-<clé>-<numéro de PR>`                        |
| Tag d'image                    | `pr-<numéro de PR>` (stable, réécrit à chaque commit) |
| Hôte de preview                 | `<clé>-pr-<numéro de PR>.preview.<domaine-cluster>`   |
| Secret TLS                     | `<clé>-pr-<numéro de PR>-tls`                         |
| Label Kubernetes des namespaces | `app.kubernetes.io/part-of: preview`                  |

`<clé>` est la clé choisie côté infra pour votre dépôt — en général le nom du dépôt.

## Limites connues

- **Polling GitHub, ~2 min de latence** par défaut avant qu'une PR labellisée soit détectée côté ArgoCD (pas de webhook configuré à ce jour).
- **Nettoyage des images ghcr non instantané** : le balayage planifié tourne une fois par jour, pas à la fermeture de la PR. Le namespace, lui, est supprimé immédiatement par ArgoCD quel que soit l'état de ce nettoyage.
- **Compte de pull ghcr partagé** entre tous les dépôts onboardés : un nouveau projet nécessite une autorisation ajoutée sur ce compte côté infra, pas un nouveau secret.

## Checklist d'onboarding

- [ ] Chart Helm accessible au chemin déclaré (`helm/` par défaut), avec `imagePullSecrets` (`registry-pull-secret`), `image.pullPolicy: Always` et un `podAnnotations` propagé au template du Pod, en valeurs par défaut
- [ ] Image buildable et poussable en local vers `ghcr.io/<org>/<image>`
- [ ] Label `preview` créé sur le dépôt GitHub
- [ ] `preview.yml` (build + commentaire) et `clean-preview-images.yml` (nettoyage planifié) ajoutés, basés sur les workflows réutilisables ci-dessus, testés sur une PR labellisée
- [ ] Ticket ouvert auprès de l'équipe plateforme pour l'onboarding (dépôt, chemin du chart, nom de l'image, hôte de preview souhaité)
