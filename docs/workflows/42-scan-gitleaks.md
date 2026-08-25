# `scan-gitleaks.yml`

Analyse de l'historique git complet à la recherche de secrets divulgués avec [gitleaks](https://github.com/gitleaks/gitleaks), avec upload optionnel des rapports SARIF vers GitHub Security.

## Inputs

| Input               | Type    | Description                                                                              | Requis | Défaut              |
| ------------------- | ------- | ----------------------------------------------------------------------------------------- | ------ | ------------------- |
| GITLEAKS_VERSION    | string  | Version de gitleaks utilisée pour effectuer le scan                                       | Non    | `8.30.1`            |
| FORMAT              | string  | Format du rapport (`sarif`, `json`, `csv`, `junit`)                                       | Non    | `sarif`             |
| LOG_OPTS            | string  | Plage de révisions passée à `git log` pour le scan. Par défaut la ref checkout uniquement ; élargir (ex: `--all`) pour scanner toutes les branches | Non    | `HEAD`              |
| FAIL_ON_LEAKS       | boolean | Faire échouer le workflow si des secrets sont détectés                                    | Non    | `true`              |
| PR_NUMBER           | string  | Numéro de la PR pour poster le commentaire de résumé du scan                              | Non    | -                   |
| GITHUB_SECURITY_TAB | boolean | Lier l'onglet GitHub Security dans le commentaire de la PR                                | Non    | `false`             |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`)    | Non    | `["ubuntu-24.04"]`  |

## Secrets

Ce workflow ne nécessite aucun secret.

## Permissions

| Scope           | Accès | Description                        |
| --------------- | ----- | ----------------------------------- |
| contents        | read  | Lire le code source                 |
| security-events | write | Upload des résultats SARIF vers l'onglet Security |
| pull-requests   | write | Commenter les PRs avec les résultats du scan      |

## Notes

- Le dépôt est checkout avec `fetch-depth: 0` pour que gitleaks scanne **tout l'historique**, pas seulement l'arbre courant. Cela détecte les secrets committés puis supprimés, qui restent exposés dans l'historique git.
- Le scan est borné à la ref checkout (`--log-opts HEAD`). Sans cela, `gitleaks git .` parcourt **toutes** les refs récupérées par `fetch-depth: 0` : un secret présent sur une branche non mergée fait alors échouer ce job sur **toutes** les PR du dépôt, et un force-push sur cette branche change le commit de la détection - donc son fingerprint - ce qui casse au passage toute allowlist qui le neutralisait. Passer `LOG_OPTS: --all` pour retrouver l'ancien comportement.
- Complémentaire à [`scan-trivy.yml`](./41-scan-trivy.md) : Trivy couvre les vulnérabilités d'images et les erreurs de configuration, gitleaks couvre les credentials divulgués dans tout l'historique git.
- Exécute directement le CLI gitleaks (licence MIT, téléchargé depuis les releases GitHub avec vérification de checksum) plutôt que le `gitleaks-action` officiel, qui nécessite une clé `GITLEAKS_LICENSE` pour les dépôts d'organisation. Le workflow reste ainsi utilisable gratuitement par tout appelant.
- Les secrets sont toujours masqués (`--redact`) dans les logs et rapports - les valeurs détectées ne sont jamais exposées dans la sortie du workflow.
- Un fichier de configuration `.gitleaks.toml` et un fichier `.gitleaksignore` à la racine du dépôt sont pris en compte automatiquement pour ajuster les règles ou ignorer des faux positifs connus. Préférer `.gitleaks.toml` : les fingerprints de `.gitleaksignore` sont épinglés au commit (`<commit>:<fichier>:<règle>:<ligne>`) et deviennent caducs à chaque rebase, amend ou squash de la branche portant la ligne, alors qu'une allowlist `targetRules` + `paths` reste valable.
- Quand des secrets sont détectés, l'upload du rapport et le commentaire PR s'exécutent toujours avant que le workflow échoue. Mettre `FAIL_ON_LEAKS: false` pour un mode purement informatif qui ne bloque jamais le pipeline.
- Avec `GITHUB_SECURITY_TAB: true` et `FORMAT: sarif`, upload les résultats vers l'onglet Security.
- Runners Linux uniquement (x64 et arm64 supportés).

## Exemples

### Scan bloquant simple

Scanne tout l'historique git et fait échouer le workflow si un secret est détecté. Quand `PR_NUMBER` est fourni, un commentaire PR est posté avec le résultat du scan.

```yaml
jobs:
  secret-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-gitleaks.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
    with:
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Scan avec intégration à l'onglet GitHub Security

Le rapport SARIF est uploadé vers l'onglet Security → Code scanning du dépôt, et le commentaire PR y renvoie. Les constats sont dédupliqués et suivis à travers les runs.

```yaml
jobs:
  secret-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-gitleaks.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
    with:
      GITHUB_SECURITY_TAB: true
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Mode rapport uniquement

Rapporte les constats sans jamais faire échouer le workflow, utile lors de la première introduction du scan de secrets sur un dépôt à l'historique bruyant.

```yaml
jobs:
  secret-scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-gitleaks.yml@v0
    permissions:
      contents: read
      security-events: write
      pull-requests: write
    with:
      FAIL_ON_LEAKS: false
```
