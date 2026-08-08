# `clean-images.yml`

Suppression d'images de conteneurs sur GHCR (GitHub Container Registry) : une version précise désignée par son tag, et/ou les versions devenues orphelines.

Pour les caches GitHub Actions, voir [clean-cache](./clean-cache.md).

## Inputs

| Input          | Type    | Description                                                                            | Requis | Défaut                |
| -------------- | ------- | -------------------------------------------------------------------------------------- | ------ | --------------------- |
| IMAGE          | string  | Image ciblée (ex: `ghcr.io/owner/repo/service:pr-123`)                                 | Oui    | -                     |
| CLEAN_TAGGED   | boolean | Supprimer la version portant exactement le tag présent dans `IMAGE`                    | Non    | `true`                |
| CLEAN_ORPHANED | boolean | Supprimer les versions dont tous les tags sont des SHA git                             | Non    | `false`               |
| PROTECTED_TAGS | string  | Tags à ne jamais supprimer, séparés par des virgules, en plus des tags de type version | Non    | `latest,main,develop` |
| RUNS_ON        | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`    |

## Permissions

| Scope    | Accès | Description                  |
| -------- | ----- | ---------------------------- |
| packages | write | Supprimer les images de GHCR |

## Ce qui n'est jamais supprimé

Une version GHCR porte **tous** les tags poussés sur son digest. La supprimer via l'un d'eux les supprime donc tous : si un tag éphémère et un tag de release partagent le même digest, supprimer le premier emporterait le second.

Une version est conservée dès qu'elle porte au moins :

- un tag de type version — `0.2.0`, `0.2.0-rc.1`, `v1.2.3` : toutes les releases et prereleases sont conservées indéfiniment ;
- un tag listé dans `PROTECTED_TAGS` — par défaut `latest`, `main`, `develop`.

Le refus est explicite : le job affiche un avertissement nommant les tags protégés rencontrés, et sort en 0 sans rien supprimer.

Ce garde-fou porte sur le **contenu de la version**, pas sur l'état de la pull request : `CLEAN_TAGGED` supprime le tag qu'on lui désigne, y compris `pr-<N>` d'une pull request encore ouverte. C'est à l'appelant de ne cibler que des pull requests fermées — voir l'exemple ci-dessous.

## Notes

- `IMAGE` doit comporter un tag lorsque `CLEAN_TAGGED` est actif ; le job échoue explicitement sinon, plutôt que de chercher un tag inexistant et de sortir en 0.
- `CLEAN_ORPHANED` ne lit que le nom du package : le tag de `IMAGE` est ignoré et peut être omis.
- Une version est considérée comme orpheline lorsque **tous** ses tags restants ressemblent à un SHA git (7 à 40 caractères hexadécimaux) : un tag mobile comme `pr-<N>` ou un nom de branche a été réassigné à un build plus récent, et plus rien de significatif ne la maintient en vie.
- Si la version supprimée est une manifest list multi-arch, les images par plateforme qu'elle référence — jamais taguées elles-mêmes — sont supprimées avec elle, sinon plus rien ne permettrait de les retrouver.
- Les versions sans aucun tag ne sont jamais supprimées directement : ce sont les images par plateforme d'une manifest list, et les supprimer isolément casserait l'image qui les référence.
- Une suppression qui échoue — version déjà supprimée, par exemple — est journalisée sans faire échouer le job.

## Exemples

### Balayage planifié (recommandé)

Réconcilie chaque jour les pull requests fermées récemment, puis collecte les orphelines. Le job `list-closed-prs` est le seul à avoir besoin de `pull-requests: read` ; c'est aussi lui qui garantit qu'aucune pull request ouverte n'est ciblée.

Le déclencheur `pull_request: closed` n'est pas fiable ici : avec `AUTOMERGE_METHOD: admin`, la fusion n'attend pas les checks, donc le nettoyage se déclenche pendant que le build pousse encore son image. Il ne trouve rien, sort en 0, et l'image arrive quelques secondes plus tard sans plus rien pour la supprimer.

```yaml
name: Clean images

on:
  schedule:
  - cron: "0 1 * * *"
  workflow_dispatch:
    inputs:
      LOOKBACK_DAYS:
        description: Profondeur de réconciliation, en jours
        required: false
        type: number
        default: 3

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
        # Le déclencheur `schedule` n'a pas de contexte `inputs`.
        LOOKBACK_DAYS: ${{ inputs.LOOKBACK_DAYS || 3 }}
      run: |
        set -euo pipefail
        CUTOFF=$(date -u -d "$LOOKBACK_DAYS days ago" +%Y-%m-%dT%H:%M:%SZ)
        PRS=$(gh pr list -R "$REPO" --state closed --limit 100 \
          --json number,closedAt \
          | jq -c --arg c "$CUTOFF" \
            '[.[] | select(.closedAt >= $c) | {number}]')
        echo "prs=$PRS" >> "$GITHUB_OUTPUT"

  sweep-images:
    needs: list-closed-prs
    # Un vecteur de matrice vide est une erreur de workflow, pas un run vide.
    if: ${{ needs.list-closed-prs.outputs.prs != '[]' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-images.yml@v0
    permissions:
      packages: write
    strategy:
      fail-fast: false
      matrix:
        pr: ${{ fromJSON(needs.list-closed-prs.outputs.prs) }}
        service: [server, client]
    with:
      IMAGE: ghcr.io/${{ github.repository }}/${{ matrix.service }}:pr-${{ matrix.pr.number }}

  sweep-orphans:
    # Indépendant des pull requests : collecte les versions qui ne portent plus
    # qu'un SHA, après réassignation d'un tag mobile à un build plus récent.
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-images.yml@v0
    permissions:
      packages: write
    strategy:
      fail-fast: false
      matrix:
        service: [server, client]
    with:
      IMAGE: ghcr.io/${{ github.repository }}/${{ matrix.service }}
      CLEAN_TAGGED: false
      CLEAN_ORPHANED: true
```

### Supprimer une image précise

```yaml
jobs:
  cleanup:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-images.yml@v0
    permissions:
      packages: write
    with:
      IMAGE: ghcr.io/${{ github.repository }}/app:pr-123
```

### Collecter uniquement les orphelines

Le tag est omis : `CLEAN_ORPHANED` ne lit que le nom du package.

```yaml
jobs:
  cleanup-orphaned:
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-images.yml@v0
    permissions:
      packages: write
    with:
      IMAGE: ghcr.io/${{ github.repository }}/app
      CLEAN_TAGGED: false
      CLEAN_ORPHANED: true
```
