# `clean-cache.yml`

Suppression des caches GitHub Actions rattachés à une pull request ou à une branche.

Pour les images de conteneurs, voir [clean-images](./clean-images.md).

## Inputs

| Input       | Type   | Description                                                                            | Requis | Défaut             |
| ----------- | ------ | -------------------------------------------------------------------------------------- | ------ | ------------------ |
| PR_NUMBER   | number | Numéro de la pull request dont les caches doivent être supprimés                       | Non    | -                  |
| BRANCH_NAME | string | Nom de la branche dont les caches doivent être supprimés                               | Non    | -                  |
| RUNS_ON     | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope   | Accès | Description                    |
| ------- | ----- | ------------------------------ |
| actions | write | Supprimer les entrées de cache |

## Quand déclencher ce workflow

Un balayage planifié est le déclenchement recommandé.

Le déclencheur `pull_request: closed` paraît naturel, mais il devient inopérant dès que les pull requests sont fusionnées avec `AUTOMERGE_METHOD: admin` — le seul mode disponible lorsque `Allow auto-merge` n'est pas activable sur le dépôt (voir [update-helm-chart](./update-helm-chart.md)).

`admin` fusionne **sans attendre les checks**. Le nettoyage se déclenche donc au moment de la fusion, pendant que le build de la pull request écrit encore ses caches : il n'en trouve qu'une partie, ou aucune, et sort en 0. Le run est vert alors qu'il n'a rien fait, et les caches s'accumulent sans aucun signal d'échec.

Un balayage planifié, une fois les builds terminés, ne peut pas perdre cette course, et rattrape au passage ce que les exécutions précédentes ont laissé derrière elles. Il est idempotent : un second passage sur une pull request déjà nettoyée affiche `No cache keys found` et sort en 0.

Si le dépôt dispose de `Allow auto-merge` et utilise `AUTOMERGE_METHOD: auto`, la fusion n'a lieu qu'une fois les checks passés : un déclencheur `pull_request: closed` redevient alors pertinent, en complément du balayage planifié.

## Notes

- Au moins un des deux inputs `PR_NUMBER` ou `BRANCH_NAME` est nécessaire ; sans aucun des deux, le job est ignoré.
- Les caches d'une pull request sont rattachés à `refs/pull/<N>/merge`, jamais à `refs/heads/<branche>` — ce dernier ne contient que les caches écrits par un workflow déclenché sur `push`. Lorsque les deux inputs sont fournis, **les deux refs sont balayés**.
- Une suppression qui échoue — une clé évincée entre le listing et la suppression, par exemple par une exécution concurrente — est journalisée sans faire échouer le job : les clés suivantes sont traitées normalement.
- Le nombre de clés effectivement supprimées est affiché en fin de job.

## Exemples

### Balayage planifié (recommandé)

Réconcilie chaque jour les pull requests fermées récemment. Le job `list-closed-prs` est le seul à avoir besoin de `pull-requests: read`.

```yaml
name: Clean cache

on:
  schedule:
  - cron: '0 1 * * *'
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
          --json number,headRefName,closedAt \
          | jq -c --arg c "$CUTOFF" \
            '[.[] | select(.closedAt >= $c) | {number, headRefName}]')
        echo "prs=$PRS" >> "$GITHUB_OUTPUT"

  sweep-caches:
    needs: list-closed-prs
    # Un vecteur de matrice vide est une erreur de workflow, pas un run vide.
    if: ${{ needs.list-closed-prs.outputs.prs != '[]' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@v0
    permissions:
      actions: write
    strategy:
      fail-fast: false
      matrix:
        pr: ${{ fromJSON(needs.list-closed-prs.outputs.prs) }}
    with:
      PR_NUMBER: ${{ matrix.pr.number }}
      BRANCH_NAME: ${{ matrix.pr.headRefName }}
```

### Nettoyer les caches d'une branche supprimée

```yaml
on:
  delete:

jobs:
  cleanup:
    if: ${{ github.event.ref_type == 'branch' }}
    uses: dnum-mi/fabnum-cicd/.github/workflows/clean-cache.yml@v0
    permissions:
      actions: write
    with:
      BRANCH_NAME: ${{ github.event.ref }}
```
