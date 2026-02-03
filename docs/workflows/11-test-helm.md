# `test-helm.yml`

Test d'installation des charts Helm dans un cluster Kind (Kubernetes in Docker).

## Inputs

| Input        | Type   | Description                                           | Requis | Défaut |
| ------------ | ------ | ----------------------------------------------------- | ------ | ------ |
| CT_CONF_PATH | string | Chemin vers le fichier de configuration chart-testing | Oui    | -      |

## Permissions

| Scope    | Accès | Description   |
| -------- | ----- | ------------- |
| contents | read  | Lire le dépôt |

## Notes

- Crée un cluster Kubernetes local avec Kind pour tester l'installation des charts.
- Utilise chart-testing pour installer et valider les charts modifiés.
- Teste uniquement les charts qui ont été modifiés par rapport à la branche par défaut.
- Vérifie que les charts peuvent être installés correctement et que les ressources sont créées.
- Utile pour valider les charts avant de les fusionner ou de les publier.
- Le cluster Kind est automatiquement nettoyé après les tests.

## Exemples

### Exemple simple

```yaml
name: CI

on:
  pull_request:

jobs:
  test-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
```

### Test complet avec lint et installation

```yaml
name: Helm CI

on:
  pull_request:
    paths:
    - 'charts/**'

jobs:
  lint:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml

  test:
    needs: lint
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@main
    with:
      CT_CONF_PATH: ci/configs/ct.yaml
```

### Configuration chart-testing exemple

```yaml
# ci/configs/ct.yaml
remote: origin
target-branch: main
chart-dirs:
  - charts
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
helm-extra-args: --timeout 600s
```
