# Hooks pre-commit

Les hooks `pre-commit` sont exécutés avant la création d'un commit. Ils permettent de valider le code, le formatage et les standards avant que les changements ne soient commitées.

## eslint-lint

Vérifie que les fichiers JavaScript, TypeScript, JSON, Markdown et YAML respectent les règles de linting ESLint.

### Description

Ce hook exécute ESLint sur l'ensemble du projet pour s'assurer que le code respecte les standards de qualité définis dans la configuration.

### Prérequis

- [ESLint](https://github.com/eslint/eslint) doit être installé
- [eslint-config](https://github.com/antfu/eslint-config) (recommandé)

### Installation des dépendances

```bash
# Avec npm
npm install -D eslint @antfu/eslint-config

# Avec pnpm
pnpm add -D eslint @antfu/eslint-config

# Avec yarn
yarn add -D eslint @antfu/eslint-config
```

### Configuration

1. Créez un fichier `eslint.config.js` dans le dossier `git-hooks/configs/` :

```javascript
import antfu from '@antfu/eslint-config'

export default antfu({
  // Options de configuration
})
```

2. Modifiez le hook pour pointer vers votre fichier de configuration :

```bash
eslint --config git-hooks/configs/eslint.config.js .
```

### Utilisation

Le hook s'exécute automatiquement avant chaque commit. Si des erreurs de linting sont détectées, le commit est bloqué.

```bash
$ git commit -m "feat: add new feature"
# ESLint vérifie tous les fichiers...
# Si des erreurs sont trouvées, le commit est rejeté
```

### Exemples

Voir le fichier [eslint.config.js](../../git-hooks/configs/eslint.config.js) pour un exemple de configuration.

---

## helm-lint

Vérifie que les charts Helm respectent les règles de linting.

### Description

Ce hook utilise `chart-testing` (ct) pour valider les charts Helm selon les meilleures pratiques et les standards de la communauté.

### Prérequis

- [chart-testing](https://github.com/helm/chart-testing)
- [yamllint](https://github.com/adrienverge/yamllint)
- [Helm](https://helm.sh/)

### Installation des dépendances

```bash
# macOS avec Homebrew
brew install chart-testing yamllint helm

# Linux avec pip pour yamllint
pip install yamllint

# chart-testing
curl -sSL https://github.com/helm/chart-testing/releases/download/v3.10.1/chart-testing_3.10.1_linux_amd64.tar.gz | tar xz
sudo mv ct /usr/local/bin/
```

### Configuration

1. Créez un fichier `chart-testing.yaml` dans le dossier `git-hooks/configs/` :

```yaml
remote: origin
target-branch: main
chart-dirs:
  - charts
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
helm-extra-args: --timeout 600s
validate-maintainers: false
```

2. Créez un fichier `yamllint.yaml` dans le dossier `git-hooks/configs/` :

```yaml
extends: default
rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
```

3. Modifiez le hook pour pointer vers vos fichiers de configuration :

```bash
ct lint --config git-hooks/configs/chart-testing.yaml --lint-conf git-hooks/configs/yamllint.yaml .
```

### Utilisation

Le hook s'exécute automatiquement avant chaque commit sur les charts Helm modifiés.

### Exemples

Voir les fichiers [chart-testing.yaml](../../git-hooks/configs/chart-testing.yaml) et [yamllint.yaml](../../git-hooks/configs/yamllint.yaml) pour des exemples de configuration.

---

## yaml-lint

Vérifie que les fichiers YAML respectent les règles de formatage.

### Description

Ce hook utilise `yamllint` pour valider la syntaxe et le formatage des fichiers YAML.

### Prérequis

- [yamllint](https://github.com/adrienverge/yamllint)

### Installation des dépendances

```bash
# macOS avec Homebrew
brew install yamllint

# Linux/macOS avec pip
pip install yamllint

# Avec apt (Ubuntu/Debian)
sudo apt-get install yamllint
```

### Configuration

1. Créez un fichier `yamllint.yaml` dans le dossier `git-hooks/configs/` :

```yaml
---
extends: default

rules:
  line-length:
    max: 120
    level: warning
  indentation:
    spaces: 2
    indent-sequences: true
  comments:
    min-spaces-from-content: 1
  braces:
    max-spaces-inside: 1
  brackets:
    max-spaces-inside: 1
  document-start: disable
  truthy:
    allowed-values: ['true', 'false', 'on', 'off']
```

2. Modifiez le hook pour pointer vers votre fichier de configuration :

```bash
yamllint --config-file git-hooks/configs/yamllint.yaml .
```

### Utilisation

Le hook s'exécute automatiquement avant chaque commit sur tous les fichiers YAML.

```bash
$ git commit -m "feat: update configuration"
# yamllint vérifie tous les fichiers .yml et .yaml
# Si des erreurs sont trouvées, le commit est rejeté
```

### Exemples

Voir le fichier [yamllint.yaml](../../git-hooks/configs/yamllint.yaml) pour un exemple de configuration.

---

## Désactivation temporaire

Pour désactiver temporairement tous les hooks pre-commit :

```bash
git commit --no-verify -m "message de commit"
```

## Personnalisation

Vous pouvez combiner plusieurs hooks dans un seul fichier `pre-commit` :

```bash
#!/bin/bash

# Vérifier YAML
yamllint --config-file git-hooks/configs/yamllint.yaml .

# Vérifier ESLint
eslint --config git-hooks/configs/eslint.config.js .

# Vérifier Helm
if [ -d "charts" ]; then
  ct lint --config git-hooks/configs/chart-testing.yaml .
fi
```
