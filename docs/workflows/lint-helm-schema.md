# `lint-helm-schema.yml`

Validation des fichiers values Helm contre un JSON schema existant avec [check-jsonschema](https://github.com/python-jsonschema/check-jsonschema).

## Inputs

| Input        | Type   | Description                                                                            | Requis | Défaut               |
| ------------ | ------ | -------------------------------------------------------------------------------------- | ------ | -------------------- |
| CHART_PATH   | string | Chemin vers le répertoire du chart Helm contenant le JSON schema                       | Oui    |                      |
| SCHEMA_FILE  | string | Nom du fichier JSON schema relatif à `CHART_PATH`                                      | Non    | `values.schema.json` |
| VALUES_FILES | string | Liste de fichiers values séparés par des virgules, relatifs à `CHART_PATH`             | Non    | `values.yaml`        |
| RUNS_ON      | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`   |

## Permissions

| Scope    | Accès | Description                |
| -------- | ----- | -------------------------- |
| contents | read  | Lire les fichiers du dépôt |

## Notes

- Le workflow suppose qu'un fichier `values.schema.json` est déjà commité dans le chart. Il peut être généré avec le plugin [helm-values-schema-json](https://github.com/losisin/helm-values-schema-json) via `helm schema`.
- Utilise [check-jsonschema](https://github.com/python-jsonschema/check-jsonschema) (Python) pour la validation, choisi pour sa lisibilité d'erreurs (JSON paths `$` clairs, toutes les erreurs affichées par défaut).
- Supporte les JSON Schema drafts 4, 6, 7, 2019-09 et 2020-12.
- `VALUES_FILES` permet de valider tous les fichiers voulus, qu'ils soient à la racine du chart ou dans des sous-répertoires (ex: `values.yaml,test-values.yaml,values/dev.yaml,values/prod.yaml`).

## Exemples

### Validation simple

```yaml
jobs:
  lint-helm-schema:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v1
    permissions:
      contents: read
    with:
      CHART_PATH: charts/my-app
```

### Validation avec fichiers d'environnement

```yaml
jobs:
  lint-helm-schema:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v1
    permissions:
      contents: read
    with:
      CHART_PATH: charts/my-app
      VALUES_FILES: values.yaml,test-values.yaml,values/dev.yaml,values/prod.yaml
```

### Validation de plusieurs charts

```yaml
jobs:
  lint-schema-app-a:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v1
    permissions:
      contents: read
    with:
      CHART_PATH: charts/app-a
      VALUES_FILES: values.yaml,values/dev.yaml,values/prod.yaml

  lint-schema-app-b:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm-schema.yml@v1
    permissions:
      contents: read
    with:
      CHART_PATH: charts/app-b
      VALUES_FILES: values.yaml,values/dev.yaml,values/prod.yaml
```
