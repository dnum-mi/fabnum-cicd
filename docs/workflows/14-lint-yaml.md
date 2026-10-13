# `lint-yaml.yml`

Lint des fichiers YAML avec [yamllint](https://github.com/adrienverge/yamllint). Scanne un chemin configurable à la recherche de fichiers YAML et signale les problèmes de style ou de syntaxe, avec un mode strict optionnel qui traite les avertissements comme des erreurs.

## Inputs

| Input       | Type    | Description                                                                                                         | Requis | Défaut             |
| ----------- | ------- | ------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| CONFIG_FILE | string  | Chemin vers un fichier de configuration `yamllint` (la configuration par défaut de `yamllint` est utilisée si omis) | Non    | -                  |
| SCAN_PATH   | string  | Chemin à scanner pour les fichiers YAML                                                                             | Non    | `.`                |
| STRICT      | boolean | Mode strict (traite les avertissements comme des erreurs)                                                           | Non    | `false`            |
| RUNS_ON     | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                              | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description                    |
| -------- | ----- | ------------------------------ |
| contents | read  | Lire les fichiers YAML sources |

## Notes

- Utilise `yamllint` (installé via pip) pour le lint YAML.
- Lorsque `CONFIG_FILE` est fourni et que le fichier existe, il est passé via `--config-file` ; sinon `yamllint` utilise ses règles par défaut intégrées.
- `STRICT: true` ajoute `--strict` à l'appel de `yamllint`, ce qui traite les avertissements comme des erreurs.
- Scanne le chemin indiqué par `SCAN_PATH` (par défaut la racine du dépôt `.`).
- `SCAN_PATH` est **un seul chemin**, passé à `yamllint` comme un unique argument. Les espaces font partie de la valeur, ils ne servent pas de séparateur - `SCAN_PATH: "./charts ./docs"` cherche un répertoire nommé littéralement `charts ./docs`, il ne scanne pas deux chemins. Exécuter le workflow deux fois, ou le pointer vers un parent commun.

## Exemples

Les exemples couvrent le scan par défaut de l'ensemble du dépôt, la restriction du scan à un chemin précis avec le mode strict activé, et l'utilisation d'un fichier de configuration yamllint personnalisé.

### Exemple simple

Scanne tous les fichiers YAML de la racine du dépôt avec les règles par défaut intégrées de yamllint. Aucun fichier de configuration n'est requis.

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
```

### Chemin de scan personnalisé avec mode strict

`SCAN_PATH: "./charts"` restreint le scan aux seuls fichiers YAML des charts Helm. `STRICT: true` promeut les avertissements en erreurs, ce qui impose un standard de style plus strict pour les fichiers du chart.

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
    with:
      SCAN_PATH: "./charts"
      STRICT: true
```

### Avec fichier de configuration personnalisé

Charge des règles yamllint spécifiques au projet (ex: largeur d'indentation, longueur de ligne). `STRICT: false` garde les avertissements comme de simples messages informatifs non bloquants.

```yaml
jobs:
  lint-yaml:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-yaml.yml@v0
    permissions:
      contents: read
    with:
      CONFIG_FILE: ".yamllint.yml"
      SCAN_PATH: "."
      STRICT: false
```
