# `lint-helm.yml`

Validation complète des charts Helm avec deux jobs parallèles : lint de la structure des charts avec [chart-testing](https://github.com/helm/chart-testing) et validation de la documentation avec [helm-docs](https://github.com/norwoodj/helm-docs). Garantit que les charts suivent les bonnes pratiques et que la documentation reste à jour.

## Inputs

| Input             | Type    | Description                                                                                                                                                                                                                                 | Requis | Défaut             |
| ----------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------ |
| HELM_DOCS_VERSION | string  | Release de helm-docs avec laquelle les README sont vérifiés, sous forme de tag, compilée depuis les sources exactement à cette version ; `latest` est refusé                                                                                | Non    | `v1.14.2`          |
| CT_CONF_PATH      | string  | Chemin vers le fichier de configuration chart-testing                                                                                                                                                                                       | Oui    | -                  |
| CHARTS_DIR        | string  | Répertoire scanné par `helm-docs` pour le job `lint-docs`. Doit correspondre au(x) `chart-dirs` configuré(s) dans `CT_CONF_PATH`, ou les contenir - ex : le répertoire du chart lui-même pour un monorepo avec un chart unique à sa racine. | Non    | `charts`           |
| LINT_CHARTS       | boolean | Exécuter le job de lint des charts                                                                                                                                                                                                          | Non    | `true`             |
| LINT_DOCS         | boolean | Exécuter le job de validation de la documentation des charts                                                                                                                                                                                | Non    | `true`             |
| RUNS_ON           | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                                                                                                      | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope    | Accès | Description                                     |
| -------- | ----- | ----------------------------------------------- |
| contents | read  | Lire les sources et la documentation des charts |

## Notes

- **Deux jobs conditionnels pour une validation flexible :**
  - **`lint-charts`** : utilise `helm/chart-testing-action` avec `ct lint` pour valider la structure du chart, la syntaxe, les dépendances, les bonnes pratiques et l'obligation d'incrémenter la version. S'exécute uniquement si `LINT_CHARTS=true`.
  - **`lint-docs`** : compile `helm-docs` depuis les sources à la version `HELM_DOCS_VERSION` (vérifiée contre la base de données de checksums de Go), régénère les README sous `CHARTS_DIR` et échoue si l'un d'eux diffère de ce qui est commité, en affichant l'écart. Il compile avec le Go déjà fourni par le runner lorsque celui-ci est en version 1.21 ou supérieure (c'est le cas de tous les runners Ubuntu hébergés par GitHub), et installe d'abord la dernière version stable de Go dans le cas contraire. S'exécute uniquement si `LINT_DOCS=true`.
- Passer `LINT_CHARTS=false` pour ignorer la validation de la structure des charts (utile pour les changements de documentation uniquement).
- Passer `LINT_DOCS=false` pour ignorer la validation de la documentation (utile pour les changements de logique du chart sans mise à jour de la documentation).
- chart-testing nécessite un fichier de configuration (typiquement `.github/ct.yaml`) pour définir les règles de lint, la branche cible, les répertoires de charts et les options de validation.
- Les jobs s'exécutent indépendamment lorsque les deux sont activés ; le workflow réussit si tous les jobs activés réussissent.
- Lorsque `Chart.yaml`, `values.yaml` ou des templates qui impactent la documentation sont modifiés, régénérer la documentation en local :
  ```bash
  go install -ldflags "-X main.version=1.14.2" github.com/norwoodj/helm-docs/cmd/helm-docs@v1.14.2
  helm-docs --chart-search-root charts
  ```
  Le marquage de version est ce qu'affiche le pied de page du README, il doit donc rester égal à la version installée. Relire puis commiter les `README.md` mis à jour sous `charts/<chart-name>/`. Après le commit, le job `lint-docs` doit de nouveau passer.

## Exemples

Les exemples illustrent les trois modes d'usage principaux : exécuter les deux vérifications ensemble, valider uniquement la documentation Helm, et linter uniquement les charts.

### Exemple simple

```yaml
jobs:
  lint-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      HELM_DOCS_VERSION: v1.14.2
      CT_CONF_PATH: .github/ct.yaml
```

Exemple de configuration chart-testing (`.github/ct.yaml`) :

```yaml
# Voir https://github.com/helm/chart-testing/blob/main/doc/ct_lint.md
target-branch: main
chart-dirs:
- charts
helm-extra-args: --timeout 600s
check-version-increment: true
validate-maintainers: false
excluded-charts:
- unstable-chart
chart-repos:
- bitnami=https://charts.bitnami.com/bitnami
```

### Validation de la documentation uniquement

Ignore entièrement `ct lint` et vérifie seulement que la sortie de `helm-docs` correspond à la documentation commitée. Plus rapide que le lint complet, et utile pour les PRs qui ne touchent que la documentation.

```yaml
jobs:
  lint-helm-docs-only:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: .github/ct.yaml
      LINT_CHARTS: false
      LINT_DOCS: true
```

### Monorepo avec un chart unique à la racine

Pour un chart situé directement par exemple dans `helm/Chart.yaml` plutôt que sous `charts/<name>/`, faire pointer `CHARTS_DIR` dessus et définir `chart-dirs: [.]` dans la configuration chart-testing afin que `ct lint` le découvre aussi.

```yaml
jobs:
  lint-helm:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: .github/ct.yaml
      CHARTS_DIR: helm
```

### Validation des charts uniquement

Exécute `ct lint` pour la validation de la structure et du schéma des charts, mais ignore la vérification de cohérence `helm-docs`. À utiliser pour des changements de logique du chart qui n'impactent pas la documentation.

```yaml
jobs:
  lint-helm-charts-only:
    uses: dnum-mi/fabnum-cicd/.github/workflows/lint-helm.yml@v0
    permissions:
      contents: read
    with:
      CT_CONF_PATH: .github/ct.yaml
      LINT_CHARTS: true
      LINT_DOCS: false
```
