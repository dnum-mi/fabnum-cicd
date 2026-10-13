# `scan-sonarqube.yml`

Exécute l'analyse statique SonarQube et vérifie la Quality Gate. Le workflow peut télécharger un artefact de couverture et le transmettre à SonarQube.

## Inputs

| Input                  | Type    | Description                                                                            | Requis | Défaut                |
| ---------------------- | ------- | -------------------------------------------------------------------------------------- | ------ | --------------------- |
| COVERAGE_IMPORT        | boolean | Télécharger un artefact de couverture                                                  | Non    | `false`               |
| COVERAGE_ARTIFACT_NAME | string  | Nom de l'artefact de couverture                                                        | Non    | `unit-tests-coverage` |
| COVERAGE_ARTIFACT_PATH | string  | Chemin de téléchargement de l'artefact de couverture                                   | Non    | `./coverage`          |
| SONAR_EXTRA_ARGS       | string  | Arguments supplémentaires pour le scanner SonarQube                                    | Non    | -                     |
| SOURCES_PATH           | string  | Chemins vers le code source à analyser (ex: `apps,packages`)                           | Non    | -                     |
| SONAR_URL              | string  | URL du serveur SonarQube                                                               | Oui    | -                     |
| FAIL_ON_ERROR          | boolean | Faire échouer le workflow en cas d'erreur de la Quality Gate                           | Non    | `true`                |
| RUNS_ON                | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]`    |

## Secrets

| Secret            | Description                              | Requis |
| ----------------- | ---------------------------------------- | ------ |
| SONAR_TOKEN       | Token d'authentification SonarQube       | Oui    |
| SONAR_PROJECT_KEY | Clé d'identification du projet SonarQube | Oui    |

## Permissions

| Scope         | Accès | Description                                                   |
| ------------- | ----- | ------------------------------------------------------------- |
| contents      | read  | Lire le code source pour l'analyse                            |
| issues        | write | Créer/mettre à jour les issues remontées par les intégrations |
| pull-requests | write | Publier les décorations de PR et les résumés de statut        |

## Notes

- Lorsque `COVERAGE_IMPORT` vaut `true`, le workflow télécharge l'artefact `COVERAGE_ARTIFACT_NAME` dans `COVERAGE_ARTIFACT_PATH` avant de lancer le scan SonarQube ; lorsqu'il vaut `false`, aucun téléchargement n'est tenté. Pour les pull requests, il passe les arguments de décoration de PR ; sinon il analyse la branche courante.
- `SOURCES_PATH` n'a pas de valeur par défaut et doit être fourni par l'appelant (ex: `-Dsonar.sources=apps,packages` ou `-Dsonar.sources=.`). L'omettre passe un `-Dsonar.sources=` vide.
- Nécessite `SONAR_TOKEN` et `SONAR_PROJECT_KEY` pour s'authentifier auprès de SonarQube.
- Échoue si la Quality Gate SonarQube échoue.
- Utilise `sonarsource/sonarqube-scan-action` pour l'analyse SonarQube.
- Supporte JavaScript/TypeScript, Python, Java, Go, C#, et plus encore.
- `FAIL_ON_ERROR` est appliqué par une étape explicite en fin de job, et non par `continue-on-error`. Une expression à cet endroit (<span v-pre>`${{ !inputs.FAIL_ON_ERROR }}`</span>) résout silencieusement à `true` même quand l'input est défini, ce qui rend le gate inopérant - l'étape échoue, le job rapporte un succès, et la seule trace est une annotation `failure` dans le résumé de l'exécution. Les rapports, artefacts et nettoyages s'exécutent quand même avant le déclenchement du gate.

## Exemples

Les exemples progressent d'un scan complet avec import de couverture à une exécution légère sans couverture, et montrent comment désactiver le blocage en cas d'échec de la Quality Gate.

### Exemple simple

Configuration monorepo complète avec couverture par package. `COVERAGE_IMPORT: true` télécharge l'artefact `unit-tests-coverage` produit par un job de tests en amont. La valeur de `SONAR_EXTRA_ARGS` indique à SonarQube le `lcov.info` de chaque package et exclut les fichiers de spec et les assets des métriques.

```yaml
jobs:
  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@v0
    permissions:
      contents: read
      issues: write
      pull-requests: write
    with:
      SONAR_URL: https://sonarqube.example.com
      COVERAGE_IMPORT: true
      COVERAGE_ARTIFACT_NAME: unit-tests-coverage
      COVERAGE_ARTIFACT_PATH: ./coverage
      SOURCES_PATH: apps,packages
      SONAR_EXTRA_ARGS: -Dsonar.javascript.lcov.reportPaths=./coverage/apps/api/lcov.info,./coverage/apps/client/lcov.info,./coverage/packages/shared/lcov.info -Dsonar.coverage.exclusions=**/*.spec.js,**/*.spec.ts,**/*.vue,**/assets/** -Dsonar.exclusions=**/*.spec.js,**/*.spec.ts,**/*.vue
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

### Sans import de couverture

Pour un scan plus simple lorsque la couverture n'est pas disponible :

```yaml
jobs:
  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@v0
    permissions:
      contents: read
      issues: write
      pull-requests: write
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: src
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```

#### Quality Gate non bloquante

Pour exécuter le scan comme une étape informative sans bloquer la pipeline :

```yaml
jobs:
  scan-sonarqube:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-sonarqube.yml@v0
    permissions:
      contents: read
      issues: write
      pull-requests: write
    with:
      SONAR_URL: https://sonarqube.example.com
      SOURCES_PATH: src
      FAIL_ON_ERROR: false
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
```
