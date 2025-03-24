# Fabrique Numerique - CI/CD

Ce dépôt sert d'emplacement centralisé pour les workflows GitHub réutilisables. En définissant des workflows partagés ici, nous rationalisons le processus de maintien de la cohérence et de la qualité dans tous les dépôts.

## Liste des workflows

Le dossier `.github` est utilisé pour stocker et gérer les workflows, les workflows suivants sont disponibles :

| Workflow                                                     | Description                                                          |
| ------------------------------------------------------------ | -------------------------------------------------------------------- |
| [scan-sonarqube.yml](./.github/workflows/scan-sonarqube.yml) | Scanne la base de code avec Sonarqube et attend la porte de qualité. |

## Specifications

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
