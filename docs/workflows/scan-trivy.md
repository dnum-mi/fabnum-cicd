# `scan-trivy.yml`

Analyse de vulnérabilités avec [Trivy](https://github.com/aquasecurity/trivy) pour les images Docker et les fichiers système.

## Inputs

| Input               | Type    | Description                                                                            | Requis | Défaut             |
| ------------------- | ------- | -------------------------------------------------------------------------------------- | ------ | ------------------ |
| IMAGE               | string  | Image utilisée pour effectuer le scan (ex: `docker.io/debian:latest`)                  | Non    | -                  |
| REGISTRY_USERNAME   | string  | Nom d'utilisateur pour se connecter au registre                                        | Non    | -                  |
| REGISTRY_PASSWORD   | string  | Mot de passe pour se connecter au registre                                             | Non    | -                  |
| PATH                | string  | Chemin utilisé pour effectuer le scan                                                  | Non    | -                  |
| FORMAT              | string  | Format du rapport (`sarif`, `table`, `json`, etc.)                                     | Non    | `table`            |
| PR_NUMBER           | string  | Numéro de la PR si le workflow est déclenché par une pull request                      | Non    | -                  |
| GITHUB_SECURITY_TAB | boolean | Lier l'onglet GitHub Security dans le commentaire de la PR                             | Non    | `false`            |
| RUNS_ON             | string  | Labels des runners au format JSON (ex: `["ubuntu-24.04"]`, `["self-hosted", "linux"]`) | Non    | `["ubuntu-24.04"]` |

## Permissions

| Scope           | Accès | Description                                       |
| --------------- | ----- | ------------------------------------------------- |
| contents        | read  | Lire le code source                               |
| security-events | write | Upload des résultats SARIF vers l'onglet Security |
| pull-requests   | write | Commenter les PRs avec les résultats du scan      |
| packages        | read  | Lire les images depuis GHCR                       |

## Notes

- Peut scanner à la fois des images Docker et des systèmes de fichiers.
- Supporte plusieurs formats de sortie (table, SARIF, JSON, etc.).
- Les résultats SARIF peuvent être uploadés vers l'onglet GitHub Security.
- Ignore les vulnérabilités non corrigées par défaut (`ignore-unfixed: true`).
- Pour les images GHCR (ghcr.io), utilise automatiquement les credentials GitHub.
- Affiche les résultats dans le résumé du workflow GitHub Actions.
- Continue même en cas d'erreur pour permettre la revue des résultats.

## Exemples

### Scan d'une image Docker

```yaml
name: Security Scan

on:
  pull_request:

jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/my-org/my-app:latest
      FORMAT: table
```

### Scan avec upload vers GitHub Security

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: ghcr.io/my-org/my-app:${{ github.sha }}
      FORMAT: sarif
      GITHUB_SECURITY_TAB: true
      PR_NUMBER: ${{ github.event.pull_request.number }}
```

### Scan d'un système de fichiers

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      PATH: ./
      FORMAT: table
```

### Scan avec registre personnalisé

```yaml
jobs:
  scan:
    uses: dnum-mi/fabnum-cicd/.github/workflows/scan-trivy.yml@main
    with:
      IMAGE: docker.io/my-org/my-app:latest
      FORMAT: json
      REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
```
