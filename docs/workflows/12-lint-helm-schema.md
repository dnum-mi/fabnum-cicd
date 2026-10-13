# `lint-helm-schema.yml`

Valide les fichiers values d'un chart Helm contre un JSON schema avec [check-jsonschema](https://github.com/python-jsonschema/check-jsonschema). Garantit que `values.yaml` et tout fichier values supplémentaire respectent le schéma déclaré par le chart.

## Inputs

| Input        | Type   | Description                                                                                                                                                 | Requis | Défaut               |
| ------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | -------------------- |
| CHART_PATH   | string | Chemin vers le répertoire du chart Helm contenant le JSON schema                                                                                            | Oui    | -                    |
| SCHEMA_FILE  | string | Nom du fichier JSON schema relatif à `CHART_PATH`                                                                                                           | Non    | `values.schema.json` |
| VALUES_FILES | string | Liste de fichiers values séparés par des virgules, à valider contre le schéma, relatifs à `CHART_PATH` (ex: `values.yaml,test-values.yaml,values/dev.yaml`) | Non    | `values.yaml`        |
| RUNS_ON      | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                      | Non    | `["ubuntu-24.04"]`   |

## Permissions

| Scope    | Accès | Description               |
| -------- | ----- | ------------------------- |
| contents | read  | Lire les sources du chart |

## Notes

- Utilise `check-jsonschema` (installé via pip) pour valider les fichiers values contre le JSON schema du chart.
- Échoue si le fichier de schéma (`SCHEMA_FILE`) n'existe pas sous `CHART_PATH`.
- Ignore les fichiers values introuvables (avec un avertissement) au lieu d'échouer, sauf s'il ne reste plus aucun fichier à valider.
- Plusieurs fichiers values peuvent être validés en une seule exécution via une liste séparée par des virgules dans `VALUES_FILES`.
- Utile pour détecter les valeurs qui ne respectent pas la structure attendue avant le déploiement.
- Le schéma doit déjà être commité dans le chart. Il peut être généré avec le plugin [helm-values-schema-json](https://github.com/losisin/helm-values-schema-json) via `helm schema`.

## Exemples

Les exemples montrent la validation d'un chart avec un seul fichier values, la validation de plusieurs fichiers values pour une couverture plus large du schéma, et l'utilisation d'un JSON schema personnalisé à la place de `values.schema.json`.

### Exemple simple

Valide `values.yaml` contre `values.schema.json` dans `charts/my-chart`. Échoue immédiatement si le fichier de schéma n'existe pas ou si une valeur ne respecte pas son type ou sa contrainte déclarés.

```yaml
jobs:
  lint-helm-schema:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v0
    permissions:
      contents: read
    with:
      CHART_PATH: charts/my-chart
```

### Plusieurs fichiers values

Valide trois fichiers values en une seule exécution - utile pour les projets avec des surcharges par environnement. Les fichiers introuvables sont ignorés avec un avertissement au lieu de provoquer un échec.

```yaml
jobs:
  lint-helm-schema:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v0
    permissions:
      contents: read
    with:
      CHART_PATH: charts/my-chart
      VALUES_FILES: "values.yaml,values/dev.yaml,values/prod.yaml"
```

### Fichier de schéma personnalisé

Utilise `custom-schema.json` à la place de `values.schema.json` par défaut. Utile lorsqu'une convention de nommage non standard est en place, ou pour appliquer un schéma spécifique à un sous-ensemble de fichiers values.

```yaml
jobs:
  lint-helm-schema:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v0
    permissions:
      contents: read
    with:
      CHART_PATH: charts/my-chart
      SCHEMA_FILE: custom-schema.json
      VALUES_FILES: "values.yaml,ci-values.yaml"
```
