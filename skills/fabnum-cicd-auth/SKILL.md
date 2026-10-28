---
name: fabnum-cicd-auth
description: Use when a fabnum-cicd workflow needs a GitHub credential beyond GITHUB_TOKEN — choosing between GITHUB_TOKEN, a GitHub App (APP_CLIENT_ID/APP_PRIVATE_KEY) and a PAT (GH_PAT), creating the App, wiring secrets into a caller workflow, or debugging "Resource not accessible", missing CI on release PRs, automerge or dispatch failures
allowed-tools: Bash Read Write
---

# Authentification des workflows fabnum-cicd

Aider l'utilisateur à choisir et câbler le credential GitHub de ses workflows. Source de vérité, à lire pour tout
détail : `../../docs/workflows/05-authentication.md`.

## Règles pour l'agent

- **Ne jamais demander, lire, écrire ni afficher la valeur** d'un secret, d'une clé `.pem` ou d'un token. L'humain les
  crée et les saisit lui-même dans GitHub. L'agent écrit le YAML qui les **référence** et indique quels **noms** poser.
- Avec `gh` authentifié, vérifier les **noms** uniquement : `gh secret list` et `gh variable list` (ajouter
  `-R <org>/<dépôt>` pour un autre dépôt). Sans `gh`, donner le chemin dans l'interface et demander confirmation.
- Ne jamais écrire `secrets: inherit` : passer chaque secret nommément.

## Quel mode choisir

Partir du haut, s'arrêter à la première ligne qui correspond.

| Le projet… | Mode | Secrets à créer |
|------------|------|-----------------|
| build, test, scan, push vers GHCR uniquement | `GITHUB_TOKEN` (automatique) | aucun |
| veut que la **PR de release** ou de chart déclenche la CI | GitHub App (ou `GH_PAT`) | `APP_CLIENT_ID`, `APP_PRIVATE_KEY` |
| veut l'**automerge** (`AUTOMERGE_*`) | GitHub App (ou `GH_PAT`) | idem |
| déclenche un workflow dans **un autre dépôt** (`dispatch-helm-chart`) | GitHub App (ou `GH_PAT`) | idem |
| a un **ruleset** qui refuse le push de `GITHUB_TOKEN` (`sync-prerelease-branch`) | GitHub App **uniquement** | idem |
| a déjà un `GH_PAT` qui marche | `GH_PAT` | `GH_PAT` |

Ordre de résolution quand plusieurs sont fournis : **token App → `GH_PAT` → `GITHUB_TOKEN`**. L'App l'emporte, ce qui
permet de vérifier une migration avant de supprimer le PAT. Recommander l'App : elle est limitée par job, expire au
bout d'une heure et n'est pas liée à une personne.

Pourquoi l'App : une PR ouverte avec `GITHUB_TOKEN` **ne déclenche pas** les workflows `pull_request`. Les PR de
release sont alors fusionnables sans qu'aucun check n'ait tourné.

## Créer l'App (une fois, par l'humain)

1. *Settings → Developer settings → GitHub Apps → New GitHub App*. Webhook **décoché**. Installable *Only on this account*.
2. Permissions : Metadata (lecture), Contents, Pull requests et Issues (lecture/écriture). Ajouter *Actions*
   (lecture/écriture) pour `dispatch-helm-chart`, *Workflows* pour `sync-prerelease-branch`.
3. *Generate a private key* : un `.pem` est téléchargé, **une seule fois**.
4. *Install App → Only select repositories* : uniquement les dépôts concernés (pour `dispatch-helm-chart`, **aussi le
   dépôt du chart**).
5. Dans chaque dépôt, *Settings → Secrets and variables → Actions* : `APP_CLIENT_ID` (le **Client ID** `Iv23li…`, pas
   l'App ID numérique) et `APP_PRIVATE_KEY` (le `.pem` complet, lignes `BEGIN`/`END` comprises).

## Câbler dans le workflow appelant

```yaml
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

Avec un PAT fine-grained à la place : `GH_PAT: ${{ secrets.GH_PAT }}` (jamais un token classique là où une App est
possible). `sync-prerelease-branch` n'accepte pas de PAT, seulement la paire App.

Vérifier : la PR de release est ouverte par `<app>[bot]` (pas `github-actions[bot]`), elle **a des checks**, et l'étape
« Generate GitHub App token » a tourné dans les logs. La première release peut faire remonter des checks cassés depuis
longtemps : c'est attendu.

## Pièges

1. **Les deux secrets App, ou aucun.** En fournir un seul fait échouer le job (`APP_CLIENT_ID and APP_PRIVATE_KEY must
   be supplied together`) au lieu de retomber sur un mode moins privilégié.
2. **`Client ID` ≠ `App ID`.** Seul le Client ID fonctionne.
3. **Le bloc `permissions:` d'un job ne gouverne que `GITHUB_TOKEN`.** Une erreur `Resource not accessible by
   integration` avec un token App se corrige dans les réglages d'**installation** de l'App, pas dans le YAML.
4. **L'automerge dépend des entrées `AUTOMERGE_*`**, pas des credentials. `AUTOMERGE_METHOD: auto` exige *Allow
   auto-merge* dans *Settings → General* ; `admin` contourne la protection de branche et les checks requis.
5. **Les workflows réutilisables n'héritent pas des secrets** : les passer explicitement dans `secrets:`.
6. **`dispatch-helm-chart`** : l'App doit être installée sur le dépôt du chart ; `CHART_REPO` s'écrit `owner/repo`.
7. Un token d'installation expire après une heure : ne jamais en passer un entre jobs.
8. **`build-docker` avec `BUILD_SECRET_GITHUB_TOKEN`** : la valeur est lisible par tout ce que le Dockerfile exécute ;
   n'utiliser qu'un token en lecture seule (`contents: read`).

## Aller plus loin

- Dépannage complet, deux Apps, migration depuis un PAT : `../../docs/workflows/05-authentication.md`.
- Utiliser ces credentials dans une pipeline : skill `fabnum-cicd-pipeline`.
