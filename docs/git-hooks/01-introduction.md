# Introduction aux Git Hooks

Les git hooks permettent d'automatiser des vérifications de qualité localement avant de pousser du code. Ce dossier contient des hooks Git réutilisables pour automatiser des vérifications de qualité de code et de format.

## Liste des hooks disponibles

- [**02 - Hooks commit-msg**](./02-commit-msg.md) - Validation des messages de commit (Conventional Commits)
- [**03 - Hooks pre-commit**](./03-pre-commit.md) - Vérifications avant commit (lint ESLint, Helm, YAML)
- [**04 - Hooks pre-push**](./04-pre-push.md) - Vérifications avant push (signatures GPG)

## Installation

Pour utiliser ces hooks dans votre projet :

### 1. Copier les hooks

Copiez les hooks souhaités dans le dossier `.git/hooks/` de votre projet :

```bash
cp git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
cp git-hooks/pre-commit/eslint-lint .git/hooks/pre-commit
cp git-hooks/pre-push/signed-commit .git/hooks/pre-push
```

### 2. Rendre les hooks exécutables

```bash
chmod +x .git/hooks/commit-msg
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/pre-push
```

### 3. Alternative avec liens symboliques

```bash
ln -s ../../git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
ln -s ../../git-hooks/pre-commit/eslint-lint .git/hooks/pre-commit
ln -s ../../git-hooks/pre-push/signed-commit .git/hooks/pre-push
chmod +x .git/hooks/*
```

### 4. Configuration Git globale (optionnel)

Pour utiliser ces hooks pour tous vos projets :

```bash
git config --global core.hooksPath /path/to/fabnum-cicd/git-hooks
```

## Hooks disponibles

### commit-msg

Hooks exécutés après la rédaction du message de commit mais avant la création du commit.

| Hook                                                          | Description                                                          | Dépendances |
| ------------------------------------------------------------- | -------------------------------------------------------------------- | ----------- |
| [conventional-commit](./02-commit-msg.md#conventional-commit) | Vérifie que le message de commit suit le format Conventional Commits | Aucune      |

### pre-commit

Hooks exécutés avant la création d'un commit pour valider le code.

| Hook                                          | Description                                     | Dépendances                                                                                                 |
| --------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| [eslint-lint](./03-pre-commit.md#eslint-lint) | Vérifie le lint des fichiers JS/TS/JSON/MD/YAML | [ESLint](https://github.com/eslint/eslint)                                                                  |
| [helm-lint](./03-pre-commit.md#helm-lint)     | Vérifie le lint des charts Helm                 | [chart-testing](https://github.com/helm/chart-testing), [yamllint](https://github.com/adrienverge/yamllint) |
| [yaml-lint](./03-pre-commit.md#yaml-lint)     | Vérifie le lint des fichiers YAML               | [yamllint](https://github.com/adrienverge/yamllint)                                                         |

### pre-push

Hooks exécutés avant de pousser les commits vers le dépôt distant.

| Hook                                            | Description                                  | Dépendances |
| ----------------------------------------------- | -------------------------------------------- | ----------- |
| [signed-commit](./04-pre-push.md#signed-commit) | Vérifie que tous les commits sont signés GPP | GPG         |

## Configuration

Chaque hook peut nécessiter un fichier de configuration spécifique :

- **ESLint** : Créez un fichier de configuration ESLint (ex: `eslint.config.js`) dans le dossier `git-hooks/configs/`
- **Helm/YAML lint** : Créez un fichier de configuration yamllint (ex: `yamllint.yaml`) dans le dossier `git-hooks/configs/`
- **Chart-testing** : Créez un fichier de configuration chart-testing (ex: `chart-testing.yaml`) dans le dossier `git-hooks/configs/`

Référez-vous à la documentation de chaque hook pour plus de détails sur la configuration.

## Désactivation temporaire

Pour désactiver temporairement les hooks lors d'un commit ou push :

```bash
git commit --no-verify -m "message"
git push --no-verify
```

Attention : Utiliser `--no-verify` contourne les vérifications de qualité. À utiliser avec précaution.
