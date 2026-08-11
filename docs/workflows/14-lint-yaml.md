# `lint-yaml.yml`

Lint des fichiers YAML avec [yamllint](https://github.com/adrienverge/yamllint).

## Inputs

| Input       | Type    | Description                                                                            | Requis | Défaut             |
| ----------- | ------- | -------------------------------------------------------------------------------------- | ------ | ------------------ |
| CONFIG_FILE | string  | Chemin vers le fichier de configuration yamllint                                       | Non    |                    |
| SCAN_PATH   | string  | Chemin à scanner pour les fichiers YAML                                                | Non    | `.`                |
| STRICT      | boolean | Mode strict (traite les avertissements comme des erreurs)                              | Non    | `false`            |
| RUNS_ON     | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description                |
| -------- | ----- | -------------------------- |
| contents | read  | Lire les fichiers du dépôt |

## Exemples

### Exemple simple

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
```

### Avec fichier de configuration personnalisé

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
    with:
      CONFIG_FILE: .yamllint.yml
```

### Mode strict sur un sous-dossier

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
    with:
      CONFIG_FILE: .yamllint.yml
      SCAN_PATH: charts/
      STRICT: true
```
