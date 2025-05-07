# Fabrique Numerique - CI/CD

Ce dépôt sert d'emplacement centralisé pour les workflows GitHub réutilisables. En définissant des workflows partagés ici, nous rationalisons le processus de maintien de la cohérence et de la qualité dans tous les dépôts.

## Liste des workflows

Le dossier `.github` est utilisé pour stocker et gérer les workflows, les workflows suivants sont disponibles :

| Workflow                                                     | Description                                                          |
| ------------------------------------------------------------ | -------------------------------------------------------------------- |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml) | Scanne la base de code avec Sonarqube.                               |
| [scan-trivy.yml](./.github/workflows/scan-trivy.yml)         | Scanne la base de code avec Trivy et exporte le rapport dans Github. |

### Analyse de code Sonarqube

#### Inputs

| Inputs              | Description                                                                | Requis | Défaut                |
| ------------------- | -------------------------------------------------------------------------- | ------ | --------------------- |
| `SONAR_URL`         | URL du serveur Sonarqube.                                                  | Oui    | -                     |
| `SONAR_EXTRA_ARGS`  | Arguments supplémentaire à ajouter dans la commande de scan Sonarqube.     | Non    | -                     |
| `COV_IMPORT`        | Active / Désactive l'import d'artefact comprenant les rapport de coverage. | Non    | `false`               |
| `COV_ARTIFACT_NAME` | Nom de l'artefact de coverage à importer.                                  | Non    | `unit-tests-coverage` |
| `COV_ARTIFACT_PATH` | Chemin vers où télécharger l'artefact de coverage à importer.              | Non    | `./coverage`          |

#### Secrets

| Inputs              | Description                               | Requis | Défaut |
| ------------------- | ----------------------------------------- | ------ | ------ |
| `SONAR_TOKEN`       | Token Sonarqube.                          | Oui    | -      |
| `SONAR_PROJECT_KEY` | Clé d'identification du projet Sonarqube. | Oui    | -      |

#### Exemple

```yaml
name: CI

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
      - ready_for_review
    branches:
      - "**"

jobs:
  scan-sonarqube:
    name: Scan code (Sonarqube)
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: ${{ vars.SONAR_URL }}
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

### Analyse de code Trivy

#### Inputs

| Inputs  | Description                 | Requis | Défaut |
| ------- | --------------------------- | ------ | ------ |
| `IMAGE` | Image à analyser.           | Non    | -      |
| `PATH`  | Chemin du dépôt à analyser. | Non    | -      |

#### Exemple

```yaml
name: CI

on:
  pull_request:
    types:
      - opened
      - reopened
      - synchronize
      - ready_for_review
    branches:
      - "**"

jobs:
  scan-trivy:
    name: Scan code (Trivy)
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/org/repo/image:1.2.3
      PATH: ./
```

## Git hooks

| Nom                                                               | Type         | Description                                                                                                                             | Config                                                       |
| ----------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | *script bash pour vérifier le pattern [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) dans le message de commit.* | -                                                            |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | *lint des fichiers js, ts, json, md et yaml en utilisant [eslint](https://github.com/eslint/eslint).*                                   | [eslint.config.js](./git-hooks/configs/eslint.config.js)     |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | *lint des charts helm charts en utilisant [chart-testing](https://github.com/helm/chart-testing).*                                      | [chart-testing.yaml](./git-hooks/configs/chart-testing.yaml) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | *script bash pour vérifier si les commit sont signés.*                                                                                  | -                                                            |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | *lint des fichiers yaml en utilisant [yamllint](https://github.com/adrienverge/yamllint).*                                              | [yamllint.yaml](./git-hooks/configs/yamllint.yaml)           |

### Paramétrage

Lancer la commande suivante pour télécharger le hook depuis Github et l'installer dans le dépôt git courant:

```sh
# Define the target file and the URL to download from
TARGET_FILE=".git/hooks/<git_hook>"
URL="https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/<git_hook>"

# Check if the target file exists
if [ -f "$TARGET_FILE" ]; then
  # File exists, download the content and remove the shebang from the first line
  curl -fsSL "$URL" | sed '1 s/^#!.*//' >> "$TARGET_FILE"
else
  # File does not exist, create the file with the downloaded content
  curl -fsSL "$URL" -o "$TARGET_FILE"
fi

# Ensure the file is executable
chmod +x "$TARGET_FILE"
```

> Vérifier que les configurations associées aux différents hooks sont bien localement présentes dans le dépôt et que les hooks git pointent bien vers ces configs.
