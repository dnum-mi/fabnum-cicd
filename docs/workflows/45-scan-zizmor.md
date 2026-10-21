# `scan-zizmor.yml`

Audit des workflows et actions GitHub Actions avec [zizmor](https://github.com/zizmorcore/zizmor) : injection de template, permissions excessives, identifiants persistés, références non épinglées, déclencheurs dangereux, actions connues pour être vulnérables, etc. Les résultats apparaissent en annotations sur le fichier et la ligne concernés.

## Inputs

| Input            | Type    | Description                                                                                                                                                         | Requis | Défaut           |
| ---------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ---------------- |
| ZIZMOR_VERSION   | string  | Version de zizmor utilisée pour l'audit                                                                                                                             | Non    | 1.31.1           |
| CONFIG_FILE      | string  | Chemin d'un fichier de configuration zizmor. Par défaut celui que zizmor trouve lui-même (`.github/zizmor.yml` ou `zizmor.yml`), s'il existe                       | Non    | ""               |
| SCAN_PATH        | string  | Chemin à auditer : la racine d'un dépôt, un répertoire `.github/workflows` ou un workflow ou une action                                                             | Non    | .                |
| PERSONA          | string  | Niveau de bruit accepté : `regular` (peu de faux positifs), `pedantic` (ajoute les mauvaises pratiques) ou `auditor` (ajoute des résultats pouvant être de faux positifs) | Non    | regular          |
| MIN_SEVERITY     | string  | Ignore les résultats sous cette sévérité (`informational`, `low`, `medium` ou `high`)                                                                               | Non    | ""               |
| MIN_CONFIDENCE   | string  | Ignore les résultats sous cette confiance (`low`, `medium` ou `high`)                                                                                               | Non    | ""               |
| ONLINE_AUDITS    | boolean | Lance les audits qui interrogent l'API GitHub, avec le jeton du job                                                                                                 | Non    | true             |
| FAIL_ON_FINDINGS | boolean | Fait échouer le workflow quand des résultats sont remontés                                                                                                          | Non    | true             |
| RUNS_ON          | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)                                                                             | Non    | ["ubuntu-24.04"] |

## Secrets

Ce workflow ne requiert aucun secret.

## Permissions

| Scope    | Accès | Description                                                                |
| -------- | ----- | -------------------------------------------------------------------------- |
| contents | read  | Lecture des fichiers de workflow et interrogation de l'API pour les audits en ligne |

## Notes

- zizmor est installé via pip à la version **exacte** `ZIZMOR_VERSION`, jamais en version flottante : une nouvelle version ajoute des audits, et un audit qui n'existait pas hier fait passer un run du vert au rouge pendant la nuit. Montez la version délibérément : le défaut porte un marqueur Renovate, et un appelant qui le fixe via `with:` peut faire de même.
- `SCAN_PATH` est **un seul chemin**, passé à zizmor comme un unique argument. Un espace fait partie de la valeur, pas d'un séparateur.
- Le jeton du job est transmis à zizmor en `GH_TOKEN` avec `ONLINE_AUDITS: true`, ce qui active les audits qui appellent l'API GitHub : actions connues pour être vulnérables, commits imposteurs, références en désaccord avec leur commentaire de version. Avec `ONLINE_AUDITS: false` le jeton est retenu et `--no-online-audits` est passé : seuls restent les audits qui lisent les fichiers.
- L'audit `ref-version-mismatch` compare le commentaire de version à côté d'un épinglage par SHA avec les tags qui pointent sur ce commit. Un épinglage écrit contre un **tag mobile** (`@<sha> # v0`) devient périmé dès que ce tag bouge, et l'audit le signale jusqu'à ce que l'épinglage soit mis à jour : gardez la mise à jour de ces digests par le bot de dépendances libre de tout délai de maturité.
- Le code de sortie de zizmor est le verdict : il sort en 11-14 selon le pire résultat. `FAIL_ON_FINDINGS: false` ajoute `--no-exit-codes`, un mode rapport seul où les résultats restent visibles en annotations sans jamais bloquer le pipeline. Un run qui ne peut pas aboutir (chemin illisible, `CONFIG_FILE` absent) échoue dans les deux cas.
- Les résultats acceptés se déclarent dans `.github/zizmor.yml`, une entrée par règle avec la raison pour laquelle elle n'est pas corrigée, ou dans un commentaire `# zizmor: ignore[règle]` pour une seule ligne. Les deux sont pris en compte sans input.
- Complémentaire de `scan-trivy.yml`, qui analyse images et configuration à la recherche de vulnérabilités : zizmor lit les workflows eux-mêmes.
- Runners Linux uniquement.

## Exemples

### Audit bloquant simple

Audite tous les workflows et actions du dépôt avec la persona `regular` et les audits en ligne, et échoue au moindre résultat.

```yaml
jobs:
  scan-zizmor:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-zizmor.yml@v0
    permissions:
      contents: read
```

### Seulement ce qui compte, avec une configuration personnalisée

Garde les résultats `medium` et `high`, charge la configuration depuis un emplacement non standard et n'audite que le répertoire des workflows.

```yaml
jobs:
  scan-zizmor:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-zizmor.yml@v0
    permissions:
      contents: read
    with:
      CONFIG_FILE: ".config/zizmor.yml"
      SCAN_PATH: ".github/workflows"
      MIN_SEVERITY: medium
```

### Rapport seul sans accès à l'API

N'exécute que les audits hors ligne et n'échoue jamais : pour un runner auto-hébergé sans route vers `api.github.com`, ou pour un premier passage sur un dépôt qui a un arriéré de résultats.

```yaml
jobs:
  scan-zizmor:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-zizmor.yml@v0
    permissions:
      contents: read
    with:
      ONLINE_AUDITS: false
      FAIL_ON_FINDINGS: false
      RUNS_ON: '["self-hosted", "linux"]'
```
