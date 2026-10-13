# `check-jobs.yml`

Agrège les résultats de tous les jobs d'un workflow en un seul check de statut qu'un ruleset peut exiger.

## Inputs

| Input         | Type    | Description                                                                                       | Requis | Défaut             |
| ------------- | ------- | ------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| NEEDS         | string  | Le contexte `needs` du job appelant, sérialisé avec `toJson`                                      | Oui    | -                  |
| ALLOW_SKIPPED | boolean | Un job ignoré (skipped) compte comme un succès - requis pour une pipeline avec filtres de chemins | Non    | `true`             |
| RUNS_ON       | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)            | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope | Accès | Description                                                           |
| ----- | ----- | --------------------------------------------------------------------- |
| -     | -     | Aucune. Le job lit les résultats qui lui sont fournis et rien d'autre |

## Notes

- **Pourquoi ce workflow existe.** La protection de branche nomme les checks qu'elle exige, et un check requis qui ne remonte jamais bloque la fusion indéfiniment. Une pipeline avec des filtres de chemins, une matrice ou un job derrière un `if` ne peut donc pas voir ses vrais jobs exigés individuellement - l'ensemble de ceux qui s'exécutent varie d'une pull request à l'autre. Un job qui s'exécute toujours, et qui représente tous les autres, est la solution.
- **Le job appelant garde les deux moitiés que lui seul peut connaître** : `if: ${{ always() }}`, pour que le gate s'exécute même si un job en amont a échoué, et une liste `needs` nommant les jobs. Un workflow réutilisable ne peut pas voir le workflow qui l'a appelé, encore moins le graphe de jobs de celui-ci, c'est pourquoi le contexte arrive sous forme d'input.
- **Lister tous les jobs dans `needs`, pas seulement les derniers.** Un job ignoré compte comme un succès, et un job ignoré *parce qu'un de ses prérequis a échoué* remonte lui aussi `skipped` - les deux sont indiscernables depuis ce workflow. Ce n'est sûr que tant que la dépendance en échec figure aussi dans la liste et échoue pour son propre compte. Omettre un job, et son échec peut atteindre le gate sous la forme d'un skip.
- **Un contexte vide est un échec, pas un succès.** Un job appelant qui omet `needs:` transmet `{}`, ce qui rapporterait sinon un succès sans rien avoir vérifié. Le gate le refuse et le dit.
- Le résultat de chaque job est affiché, et chaque job en échec est nommé avant que l'étape ne se termine - une exécution avec trois jobs cassés en annonce trois au lieu de s'arrêter au premier. `failure`, `cancelled` et `timed_out` sont rapportés par leur nom, car une annulation et un timeout ne se lisent pas comme un échec.
- `ALLOW_SKIPPED: false` convient à une pipeline où tous les jobs sont censés s'exécuter ; un skip fait alors échouer le gate au lieu de passer.
- Utilise `jq`, présent sur les runners hébergés par GitHub. Un runner self-hosted désigné via `RUNS_ON` doit l'avoir installé.

## Migrer un gate inline

Le check de statut rapporté se nomme **`<nom du job appelant> / Required jobs`** - les checks d'un workflow réutilisable sont toujours préfixés par le nom du job appelant. Un job de gate écrit à la main remonte sous son seul nom, donc passer à ce workflow **renomme le check**, et un ruleset qui exige encore l'ancien nom bloquera toutes les pull requests en attente d'un check qui ne remonte plus.

Modifier le workflow et le ruleset ensemble, dans cet ordre :

1. Fusionner la modification du workflow, et laisser tourner une pull request pour que le nouveau nom de check soit enregistré.
2. Mettre à jour les checks de statut requis du ruleset avec le nouveau nom.

## Exemples

### Exemple simple

```yaml
jobs:
  lint:
    # ...
  test:
    # ...
  build:
    # ...

  all-jobs-passed:
    name: Check jobs status
    if: ${{ always() }}
    needs:
    - lint
    - test
    - build
    uses: dnum-mi/fabnum-cicd/.github/workflows/check-jobs.yml@v0
    with:
      NEEDS: ${{ toJson(needs) }}
```

Le check de statut requis est alors `Check jobs status / Required jobs`.

### Tous les jobs sont censés s'exécuter

Sans filtres de chemins et sans job derrière un `if`, un skip est une surprise plutôt que la réponse ordinaire :

```yaml
  all-jobs-passed:
    name: Check jobs status
    if: ${{ always() }}
    needs:
    - lint
    - test
    uses: dnum-mi/fabnum-cicd/.github/workflows/check-jobs.yml@v0
    with:
      NEEDS: ${{ toJson(needs) }}
      ALLOW_SKIPPED: false
```
