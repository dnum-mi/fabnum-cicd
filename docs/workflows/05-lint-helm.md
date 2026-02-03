# `lint-helm.yml`

Lint des charts Helm avec [chart-testing](https://github.com/helm/chart-testing) et validation de la documentation avec [helm-docs](https://github.com/norwoodj/helm-docs).

## Inputs

| Input             | Type    | Description                                           | Requis | Défaut   |
| ----------------- | ------- | ----------------------------------------------------- | ------ | -------- |
| CT_CONF_PATH      | string  | Chemin vers le fichier de configuration chart-testing | Oui    | -        |
| HELM_DOCS_VERSION | string  | Version de helm-docs à utiliser                       | Non    | `1.14.2` |
| LINT_CHARTS       | boolean | Exécuter le lint des charts                           | Non    | `true`   |
| LINT_DOCS         | boolean | Exécuter la validation de la documentation            | Non    | `true`   |

## Permissions

| Scope    | Accès | Description   |
| -------- | ----- | ------------- |
| contents | read  | Lire le dépôt |

## Notes

- Valide les charts Helm selon les meilleures pratiques.
- Vérifie que la documentation est à jour et correctement générée avec helm-docs.
- Utilise chart-testing pour détecter les changements et ne linter que les charts modifiés.
- Compare avec la branche par défaut du dépôt pour identifier les charts à tester.
- Les deux jobs (lint-charts et lint-docs) peuvent être activés/désactivés indépendamment.

## Exemples

### Exemple simple

```yaml
name: CI

on:
  pull_request:

jobs:
  lint-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
```

### Lint uniquement les charts (sans la documentation)

```yaml
jobs:
  lint-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
      LINT_CHARTS: true
      LINT_DOCS: false
```

### Avec une version spécifique de helm-docs

```yaml
jobs:
  lint-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: .github/ct.yaml
      HELM_DOCS_VERSION: "1.13.0"
```
