# Hooks commit-msg

Les hooks `commit-msg` sont exécutés après que l'utilisateur a rédigé le message de commit mais avant que le commit ne soit finalisé. Ils permettent de valider et modifier le message de commit.

## conventional-commit

Vérifie que le message de commit suit le format [Conventional Commits](https://www.conventionalcommits.org/).

### Description

Ce hook valide que chaque message de commit respecte la convention de format suivante :

```
<type>(<scope>): <subject>
```

ou avec breaking change :

```
<type>(<scope>)!: <subject>
```

### Types autorisés

- `feat` : Nouvelle fonctionnalité
- `fix` : Correction de bug
- `docs` : Documentation uniquement
- `style` : Changements de formatage (espaces, points-virgules, etc.)
- `refactor` : Refactorisation du code sans correction de bug ni ajout de fonctionnalité
- `perf` : Amélioration des performances
- `test` : Ajout ou modification de tests
- `chore` : Tâches de maintenance (build, outils, etc.)
- `revert` : Annulation d'un commit précédent
- `ci` : Changements dans les fichiers de configuration CI/CD

### Scope (optionnel)

Le scope est optionnel et peut contenir :
- Lettres (a-z, A-Z)
- Chiffres (0-9)
- Tirets (-)
- Underscores (_)
- Espaces

### Breaking changes

Ajoutez un `!` après le type/scope pour indiquer un breaking change :

```
feat(api)!: change authentication method
```

### Exemples de messages valides

```bash
feat: add user authentication
fix(api): resolve CORS issue
docs: update README with new examples
refactor(core)!: change module structure
chore: update dependencies
```

### Exemples de messages invalides

```bash
# Type manquant
update user authentication

# Type non autorisé
update: add new feature

# Format incorrect
feat add user authentication

# Caractères invalides dans le scope
feat(@#$): add feature
```

### Installation

1. Copiez le fichier dans `.git/hooks/` :
   ```bash
   cp git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
   chmod +x .git/hooks/commit-msg
   ```

2. Ou créez un lien symbolique :
   ```bash
   ln -s ../../git-hooks/commit-msg/conventional-commit .git/hooks/commit-msg
   chmod +x .git/hooks/commit-msg
   ```

### Utilisation

Le hook s'exécute automatiquement lors de chaque `git commit`. Si le message ne respecte pas le format, le commit est rejeté avec un message d'erreur explicatif.

```bash
$ git commit -m "update README"
Commit message does not follow conventional commit format.
Expected format: <type>(<scope>)!: <subject>
Allowed types: feat, fix, docs, style, refactor, perf, test, chore, revert, ci
```

### Désactivation temporaire

Pour désactiver temporairement le hook :

```bash
git commit --no-verify -m "message non conforme"
```

### Personnalisation

Pour modifier les types autorisés ou le format, éditez l'expression régulière dans le fichier :

```bash
CONVENTIONAL_COMMIT_REGEX='^(feat|fix|docs|style|refactor|perf|test|chore|revert|ci)(\([a-zA-Z0-9\-_ ]+\))?!?: .+'
```
