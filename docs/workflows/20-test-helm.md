# `test-helm.yml`

Test d'installation des charts Helm dans un cluster Kind (Kubernetes in Docker). Le cluster n'est créé que lorsque `chart-testing` a un chart à installer.

## Inputs

| Input        | Type   | Description                                                                            | Requis | Défaut             |
| ------------ | ------ | -------------------------------------------------------------------------------------- | ------ | ------------------ |
| CT_CONF_PATH | string | Chemin vers le fichier de configuration chart-testing                                  | Oui    | -                  |
| RUNS_ON      | string | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description   |
| -------- | ----- | ------------- |
| contents | read  | Lire le dépôt |

## Notes

- Crée un cluster Kubernetes local avec Kind pour tester l'installation des charts.
- **Un run qui ne modifie aucun chart ne crée aucun cluster.** Le cluster représente l'essentiel du job (environ 40 secondes sur 56), et le filtre de chemins d'un appelant est généralement plus large que les répertoires de charts que `ct` examine (`ci/`, `template/`, les workflows) : de tels runs sont donc fréquents. `ct list-changed` est interrogé en premier, avec la même configuration et la même branche cible que l'installation ; s'il ne rapporte rien, le job se termine par une notice, sans cluster. Une configuration qui définit `charts:` ou `all: true` installe toujours, puisque `ct install` traite alors ces charts qu'ils aient changé ou non, ce que `ct list-changed` ne dit pas.
- Utilise chart-testing pour installer et valider les charts modifiés.
- Teste uniquement les charts qui ont été modifiés par rapport à la branche cible. Pour une pull request, c'est la branche dans laquelle elle est fusionnée (`github.base_ref`) ; hors pull request, la branche par défaut du dépôt. `ct` n'installe que les charts qui diffèrent de cette branche : prendre la branche de la pull request elle-même ne donnerait aucune différence, donc rien à installer.
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@v0
    permissions:
      contents: read
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
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: ci/configs/ct.yaml

  test:
    needs: lint
    uses: dnum-mi/fabnum-cicd/.github/workflows/test-helm.yml@v0
    permissions:
      contents: read
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
