---
name: fabnum-cicd-release
description: Use when setting up automated releases with fabnum-cicd — release-please (release-app), Conventional Commits and lint-commits, develop/main pre-release flow and sync-prerelease-branch, publishing to npm or PyPI, monorepo releases, or triggering the CPiN mirror with sync-cpin
allowed-tools: Bash Read Write
---

# Releases avec fabnum-cicd

Aider l'utilisateur à automatiser, dans son propre dépôt, la chaîne commit → PR de release → tag → publication.
Les charts Helm ont leur propre skill : `fabnum-cicd-helm`. Doc détaillée, à lire avant d'écrire un appel :
`../../docs/workflows/50-release-app.md`, `55-release-npm.md`, `57-sync-prerelease-branch.md`,
`58-release-pypi.md`, `72-sync-cpin.md`, `90-monorepo-release.md`.

> Les liens relatifs vers `docs/` supposent le dépôt complet. Sans lui (installation par URL ou copie des seuls
> skills), les mêmes pages sont en ligne : <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

## Le principe

1. Les commits suivent **Conventional Commits** (`feat:`, `fix:`, `feat!:`…). `release-please` en déduit la version
   et le changelog : un commit `docs:` ou `chore:` ne déclenche **aucune** release.
2. `release-app` ouvre et tient à jour une **PR de release**. La fusionner crée le tag et la release GitHub.
3. Les jobs de publication (image, paquet, chart) se déclenchent sur `release-created == 'true'`.

## Mettre en place

1. **Valider les commits** : job `lint-commits` en CI (skill `fabnum-cicd-pipeline`) et, en local, le hook `commit-msg`
   (skill `fabnum-cicd-git-hooks`).
2. **Créer à la racine** `release-please-config.json` et `.release-please-manifest.json` (exemples et options :
   `../../docs/workflows/50-release-app.md`, section Configuration). Mettre dans le manifest la version **actuelle**.
   Choisir le `release-type` du projet (`node`, `python`, `simple`…).
3. **Appeler `release-app`** dans le `cd.yml`, avec la GitHub App (sans elle, la CI ne tourne pas sur la PR de
   release : skill `fabnum-cicd-auth`) :

```yaml
  release:
    uses: dnum-mi/fabnum-cicd/.github/workflows/release-app.yml@v0
    permissions:
      contents: write
      issues: write
      pull-requests: write
    with:
      TAG_MAJOR_AND_MINOR: true        # crée aussi les tags v1 et v1.2
    secrets:
      APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
      APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
```

4. **Conditionner** tout job de publication : `if: ${{ needs.release.outputs.release-created == 'true' }}`
   (`release-app` est idempotent : il tourne à chaque push). Sorties utiles : `version`, `tag-name`.
5. Gabarit complet : `../fabnum-cicd-pipeline/references/cd.yml`.

## Pré-release (`develop` → `main`)

Pour publier des release candidates (`1.2.3-rc.1`) depuis `develop` et les versions finales depuis `main` :

- `release-app` avec `ENABLE_PRERELEASE: true`. Branches par défaut : `PRERELEASE_BRANCH: develop`,
  `RELEASE_BRANCH: main`. Fichiers par défaut `release-please-config-rc.json` et `.release-please-manifest-rc.json`
  pour la pré-release (structure dans la doc 50).
- **`sync-prerelease-branch` en dernier job**, avec `needs:` = **exactement** les jobs qui commitent sur la branche de
  release (le job `release`, et un éventuel bump de chart local), rien d'autre. Sinon la branche de pré-release devient
  périmée et `release-app` échoue sur elle (« is missing N commit(s) »).
- Repasser à `sync-prerelease-branch` les **mêmes** `PRERELEASE_CONFIG_FILE` / `*_MANIFEST_FILE` que `release-app`.
- Un ruleset qui refuse `GITHUB_TOKEN` exige la paire App (le PAT n'est pas accepté ici) ; le push avec un token App
  déclenche la CD sur la branche de pré-release.

## Publier un paquet

| Cible | Workflow | À savoir |
|-------|----------|----------|
| npm / GitHub Packages | `release-npm` | `contents: read` + `id-token: write` ; publication de confiance (OIDC) possible sans token, sinon secret `NPM_TOKEN` ; `DRY_RUN` pour essayer |
| PyPI | `build-python` puis `release-pypi` | `release-pypi` consomme l'artefact de `build-python` (`ARTIFACT` requis) ; seule permission `id-token: write` ; publication de confiance OIDC, secret `PYPI_TOKEN` sinon |

## Monorepo

Une seule PR de release pour tout le dépôt : config en mode manifest, un package par répertoire, sorties
`releases-created` / `paths-released` / `release-outputs` (les sorties mono-package restent vides). Pipeline complet
(plusieurs images, un chart unique) : `../../docs/workflows/90-monorepo-release.md`.

## Synchroniser le miroir CPiN (`sync-cpin`)

Déclenche le pipeline GitLab du projet miroir. Se limiter à ce que dit `../../docs/workflows/72-sync-cpin.md` :
entrées requises `GITLAB_URL` (en `https://`, sinon le job refuse), `GIT_MIRROR_PROJECT_ID` (identifiant numérique ou
chemin encodé) et `REPOSITORY_NAME` ; `BRANCH_TO_SYNC` ou `SYNC_ALL` pour choisir quoi synchroniser ; secret requis
`GIT_MIRROR_TOKEN`. `ADDITIONAL_VARIABLES` est un objet JSON de variables de pipeline. L'agent ne manipule jamais la
valeur du token.

## Pièges

1. **Pas de release ?** Aucun commit `feat`/`fix` depuis la dernière : `docs`/`chore`/`ci` sont ignorés.
2. **Releases immuables** : `release-helm` avec `CREATE_GITHUB_RELEASE: true` est incompatible ; pour `release-app`,
   config `"draft": true` + `"force-tag-creation": true` et `PUBLISH_DRAFT_RELEASE: true`.
3. `AUTOMERGE_*` ne fusionne rien sans credential App/PAT, et échoue plutôt que de l'ignorer en silence.
4. Booléens d'`outputs` : des chaînes, comparer avec `== 'true'`.
5. `sync-prerelease-branch` dans un dépôt mono-branche : inutile, retirer `ENABLE_PRERELEASE` et ce job.

## Aller plus loin

- Docs : `../../docs/workflows/50-release-app.md` à `58-release-pypi.md`, `72-sync-cpin.md`, `90-monorepo-release.md`.
- Charts Helm : skill `fabnum-cicd-helm`.
