---
name: fabnum-cicd-pipeline
description: Use when writing, extending or reviewing a GitHub Actions ci.yml/cd.yml that calls the reusable workflows of dnum-mi/fabnum-cicd — lint, tests, Docker/Python build, Trivy/Gitleaks/SonarQube/zizmor scans, check-jobs gate, cache and image cleanup
allowed-tools: Bash Read Write
---

# Assembler une pipeline avec fabnum-cicd

Aider l'utilisateur à brancher, **dans son propre dépôt**, les workflows réutilisables de
[`dnum-mi/fabnum-cicd`](https://github.com/dnum-mi/fabnum-cicd) : un `ci.yml` (pull request) et un `cd.yml`
(release, livraison). Ce skill ne lance rien : il écrit ou relit du YAML, GitHub l'exécute.

> Les liens relatifs vers `docs/` supposent le dépôt complet. Sans lui (installation par URL ou copie des seuls
> skills), les mêmes pages sont en ligne : <https://github.com/dnum-mi/fabnum-cicd/tree/main/docs>.

Les détails exacts (entrées, valeurs par défaut) sont dans la doc livrée avec le plugin, à lire avant d'écrire un
appel : `../../docs/workflows/NN-<nom>.md`. Le catalogue complet est dans
[`references/workflows.md`](references/workflows.md).

## Avant d'écrire : poser ces questions

| Question | Conséquence |
|----------|-------------|
| Quel langage / quels artefacts (image Docker, paquet Python, paquet npm, chart Helm) ? | choisit les workflows de lint, test et build (catalogue) |
| Une seule image ou plusieurs (monorepo) ? | plusieurs : une paire `build-docker` / `attest-docker` par composant, jamais de matrice pour `attest-docker` ; voir le skill `fabnum-cicd-release` pour le monorepo |
| Branches `develop` (rc) et `main` (stable) ? | pré-release : voir le skill `fabnum-cicd-release` |
| Le dépôt exige-t-il une PR pour tout push (ruleset) ? | oui : GitHub App obligatoire pour tout job qui pousse ; voir le skill `fabnum-cicd-auth` |
| `gh` est-il installé et authentifié ? | oui : l'agent peut vérifier les **noms** des secrets (`gh secret list`) ; non : l'humain les vérifie dans l'UI |

## Démarrer

1. Partir de [`references/ci.yml`](references/ci.yml) (pull request) et, pour les releases,
   [`references/cd.yml`](references/cd.yml). Retirer les jobs sans objet, adapter les `<…>`.
2. Pour chaque workflow retenu, **ouvrir sa doc** et le catalogue : entrées requises, secrets, permissions.
3. **Tenir `all-jobs-passed` à jour** : tout job ajouté ou retiré se répercute dans son `needs` (voir plus bas).
4. Créer les secrets nécessaires (skill `fabnum-cicd-auth`) ; l'agent n'en lit ni n'en écrit jamais la valeur.
5. Vérifier avec `actionlint` si disponible, puis ouvrir une PR de test.

## Règles

- **Version** : `@v0` (tag flottant : le dépôt est en `0.x`, un bump mineur peut changer un comportement). Pour figer :
  `@v0.25` (ou le SHA du commit). **Jamais `@main`**. Côté Renovate, un `@v0` n'a rien à mettre à jour ; un pin
  précis est remonté par Renovate comme n'importe quelle dépendance GitHub Actions.
- **Permissions** : déclarées **par job**, jamais au niveau workflow. L'appelant accorde l'**union** des permissions
  du workflow appelé, même pour un job qui ne tourne pas (colonne « Permissions » du catalogue). Un scope manquant
  fait échouer le parsing, pas un job.
- **Jamais `secrets: inherit`** : passer chaque secret nommément.
- **Credentials** : `GITHUB_TOKEN` suffit pour lint, test, build, scan. Dès qu'une PR automatisée doit déclencher la
  CI, ou pour l'automerge ou un dispatch inter-dépôts : GitHub App (skill `fabnum-cicd-auth`).
- **Actions tierces** que l'utilisateur ajoute lui-même : épinglées par SHA complet avec commentaire de version.
- **Image en minuscules** : `ghcr.io/${GITHUB_REPOSITORY,,}` calculé une fois puis propagé.
- **Booléens** issus d'`env` ou d'outputs : ce sont des chaînes, comparer avec `== 'true'`.
- **Concurrence** : `cancel-in-progress: true` en CI, `false` en CD.
- **Runner** : `RUNS_ON` est une chaîne JSON (`'["ubuntu-24.04"]'`, `'["self-hosted", "linux"]'`).

## La porte unique `check-jobs`

Les jobs filtrés par chemin ou en matrice ne peuvent pas être exigés un par un par un ruleset : un check requis qui
ne remonte jamais bloque la PR. Ajouter un job final qui les agrège (doc `80-check-jobs.md`) :

```yaml
  all-jobs-passed:
    name: Check jobs status
    if: ${{ always() }}
    needs: [lint-commits, lint-yaml, build]   # TOUS les jobs, filtre de chemins compris
    uses: dnum-mi/fabnum-cicd/.github/workflows/check-jobs.yml@v0
    permissions: {}
    with:
      NEEDS: ${{ toJson(needs) }}
```

- Lister **tous** les jobs dans `needs`, pas seulement les derniers : un job ignoré compte pour un succès, y compris
  quand il est ignoré parce que son prérequis a échoué.
- Le check remonte sous le nom **`<job appelant> / Required jobs`**. Remplacer un gate maison par celui-ci renomme le
  check : fusionner d'abord, laisser tourner une PR, puis mettre à jour le ruleset (sinon toutes les PR sont bloquées).

## Pièges fréquents

1. Matrice vide (`fromJSON('[]')`) = erreur : garder avec `if: … != '[]'`.
2. `build-docker` construit le **dernier** stage du Dockerfile par défaut : fixer `IMAGE_TARGET` si ce dernier stage
   n'est pas celui à livrer (par exemple un stage de test).
3. `scan-trivy` : `CATEGORY` distinct par scan en matrice, `TIMEOUT` pour les grosses images ; `FAIL_ON_ERROR` vaut
   `false` par défaut (le scan informe sans bloquer) ; `SEVERITY` restreint le périmètre qui bloque.
   L'image doit exister avant d'être scannée.
4. `attest-docker` s'appelle **après** `build-docker` avec ses sorties `digest` et `image` (le `digest` est vide si
   `PUSH: false`, donc rien à attester) ; ne pas le mettre en
   matrice (les sorties d'un job matricé s'effondrent en une seule valeur).
5. `scan-sonarqube` : `SONAR_URL` est une **entrée** requise ; `SONAR_TOKEN` et `SONAR_PROJECT_KEY` sont des secrets
   requis. Une URL ne se passe pas via un secret dans `with:`: utiliser une variable (`vars.`).
6. `scan-gitleaks` analyse tout l'historique git : le premier run sur un dépôt ancien peut remonter d'anciens secrets.
7. `lint-helm` exige `CT_CONF_PATH` (configuration `chart-testing`).
8. `clean-images` supprime tout tag qu'on lui donne : ne lui passer que des PR fermées.
9. Cache de build : `CACHE: true` active le cache GitHub Actions ; `CACHE_MODE: min` n'exporte que l'image finale
   (utile pour des couches lourdes).

## Relire une pipeline existante

Parcourir dans l'ordre et signaler chaque écart avec le fichier et la ligne :

1. `@main` / `@master` / `@latest` sur une action ou un workflow réutilisable.
2. `secrets: inherit`, ou un secret passé à un workflow qui ne le déclare pas.
3. Permissions déclarées au niveau workflow, ou qui ne couvrent pas l'union du workflow appelé.
4. `${{ … }}` interpolé directement dans un bloc `run:` (passer par `env:`).
5. Actions tierces non épinglées par SHA.
6. `all-jobs-passed` absent, ou `needs` incomplet.
7. Une paire `APP_CLIENT_ID` / `APP_PRIVATE_KEY` incomplète, ou un `GH_PAT` classique là où une App est possible.
8. `scan-zizmor` absent : il détecte les injections, les permissions excessives et les identifiants persistés.

## Aller plus loin

- Catalogue, entrées requises et permissions : [`references/workflows.md`](references/workflows.md).
- Exemples complets (CI, CD, Helm) : `../../docs/workflows/01-introduction.md`.
- Authentification : skill `fabnum-cicd-auth`. Release et charts : skills `fabnum-cicd-release` et `fabnum-cicd-helm`.
- Hooks locaux (lint avant commit) : skill `fabnum-cicd-git-hooks`.
