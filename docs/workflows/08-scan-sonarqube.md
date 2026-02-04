# `scan-sonarqube.yml`

Analyse de la qualité du code avec [SonarQube](https://www.sonarqube.org/), incluant le support des rapports de couverture de tests.

## Inputs

| Input                  | Type    | Description                                                                            | Requis | Défaut                |
| ---------------------- | ------- | -------------------------------------------------------------------------------------- | ------ | --------------------- |
| SONAR_URL              | string  | URL du serveur SonarQube                                                               | Oui    | -                     |
| SOURCES_PATH           | string  | Chemins vers le code source à analyser (ex: `apps,packages`)                           | Non    | -                     |
| SONAR_EXTRA_ARGS       | string  | Arguments supplémentaires pour SonarQube                                               | Non    | -                     |
| COVERAGE_IMPORT        | boolean | Activer l'import d'artefact de couverture                                              | Non    | `false`               |
| COVERAGE_ARTIFACT_NAME | string  | Nom de l'artefact de couverture à importer                                             | Non    | `unit-tests-coverage` |
| COVERAGE_ARTIFACT_PATH | string  | Chemin de téléchargement de l'artefact de couverture                                   | Non    | `./coverage`          |
| RUNS_ON                | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`    |

## Secrets

| Secret            | Description                              | Requis |
| ----------------- | ---------------------------------------- | ------ |
| SONAR_TOKEN       | Token d'authentification SonarQube       | Oui    |
| SONAR_PROJECT_KEY | Clé d'identification du projet SonarQube | Oui    |

## Permissions

| Scope         | Accès | Description                                    |
| ------------- | ----- | ---------------------------------------------- |
| contents      | read  | Lire le code source                            |
| issues        | write | Créer des issues pour les problèmes détectés   |
| pull-requests | write | Commenter les PRs avec les résultats d'analyse |

## Notes

- Supporte l'analyse des pull requests et des branches.
- Peut importer des rapports de couverture de tests depuis des artefacts GitHub Actions.
- Configure automatiquement les paramètres pour les pull requests (clé, branche, base).
- Utilise `fetch-depth: 0` pour obtenir l'historique complet Git nécessaire à l'analyse.
- Les arguments supplémentaires permettent de personnaliser l'analyse selon les besoins du projet.

## Exemples

### Exemple simple

```yaml
name: CI

on:
  pull_request:

jobs:
  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: apps,packages
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

### Avec import de couverture de tests

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v5
    - name: Run tests
      run: npm test -- --coverage
    - name: Upload coverage
      uses: actions/upload-artifact@v4
      with:
        name: unit-tests-coverage
        path: ./coverage

  scan-sonarqube:
    needs: test
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: src
      COVERAGE_IMPORT: true
      COVERAGE_ARTIFACT_NAME: unit-tests-coverage
      COVERAGE_ARTIFACT_PATH: ./coverage
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

### Avec arguments supplémentaires

```yaml
jobs:
  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@main
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: src
      SONAR_EXTRA_ARGS: "-Dsonar.exclusions=**/*.test.ts -Dsonar.coverage.exclusions=**/*.test.ts"
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```
