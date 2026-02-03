# Hooks pre-push

Les hooks `pre-push` sont exécutés avant que les commits ne soient poussés vers le dépôt distant. Ils permettent de valider des aspects critiques comme la signature des commits.

## signed-commit

Vérifie que tous les commits poussés sont signés avec GPG.

### Description

Ce hook valide que chaque commit dans la plage de commits à pousser possède une signature GPG valide. Cela garantit l'authenticité et l'intégrité des commits.

### Prérequis

- **GPG** doit être installé et configuré
- Une clé GPG doit être créée et associée à votre compte Git/GitHub

### Installation de GPG

```bash
# macOS avec Homebrew
brew install gnupg

# Ubuntu/Debian
sudo apt-get install gnupg

# Fedora/RHEL
sudo dnf install gnupg
```

### Configuration de GPG avec Git

1. **Générer une clé GPG** (si vous n'en avez pas) :

```bash
gpg --full-generate-key
# Choisissez les options par défaut
# Utilisez l'email associé à votre compte Git
```

2. **Lister vos clés GPG** :

```bash
gpg --list-secret-keys --keyid-format LONG
```

Vous verrez quelque chose comme :

```
/Users/username/.gnupg/secring.gpg
----------------------------------
sec   rsa4096/3AA5C34371567BD2 2024-01-01 [SC]
uid                 [ultimate] Your Name <your.email@example.com>
ssb   rsa4096/42B317FD4BA89E7A 2024-01-01 [E]
```

L'ID de la clé est `3AA5C34371567BD2` dans cet exemple.

3. **Configurer Git pour utiliser votre clé GPG** :

```bash
git config --global user.signingkey 3AA5C34371567BD2
git config --global commit.gpgsign true
```

4. **Exporter votre clé publique pour GitHub** :

```bash
gpg --armor --export 3AA5C34371567BD2
```

Copiez la sortie et ajoutez-la à votre compte GitHub :
- Allez dans **Settings** > **SSH and GPG keys** > **New GPG key**
- Collez votre clé publique

### Installation du hook

1. Copiez le fichier dans `.git/hooks/` :
   ```bash
   cp git-hooks/pre-push/signed-commit .git/hooks/pre-push
   chmod +x .git/hooks/pre-push
   ```

2. Ou créez un lien symbolique :
   ```bash
   ln -s ../../git-hooks/pre-push/signed-commit .git/hooks/pre-push
   chmod +x .git/hooks/pre-push
   ```

### Utilisation

Le hook s'exécute automatiquement lors de chaque `git push`. Si un commit n'est pas signé, le push est rejeté.

```bash
$ git push origin main
# Vérification des signatures...
Error: Commit a1b2c3d is not signed.
error: failed to push some refs to 'origin'
```

### Signer un commit

Pour signer un commit lors de sa création :

```bash
# Signer automatiquement tous les commits (si configuré globalement)
git commit -m "feat: add new feature"

# Signer manuellement un commit
git commit -S -m "feat: add new feature"
```

### Signer des commits existants

Si vous avez des commits non signés :

```bash
# Signer le dernier commit
git commit --amend --no-edit -S

# Signer plusieurs commits (rebase interactif)
git rebase -i HEAD~3
# Dans l'éditeur, remplacez 'pick' par 'edit' pour chaque commit
# Puis pour chaque commit :
git commit --amend --no-edit -S
git rebase --continue
```

### Vérifier les signatures

Pour vérifier qu'un commit est signé :

```bash
# Vérifier un commit spécifique
git verify-commit <commit-hash>

# Afficher les informations de signature
git log --show-signature

# Afficher uniquement les commits signés
git log --pretty="format:%h %G? %aN  %s"
# %G? affiche :
#   G = bonne signature
#   B = mauvaise signature
#   U = bonne signature, clé non fiable
#   N = pas de signature
```

### Désactivation temporaire

Pour désactiver temporairement le hook :

```bash
git push --no-verify origin main
```

⚠️ **Attention** : Utiliser `--no-verify` contourne la vérification de sécurité. À utiliser avec précaution.

### Dépannage

**Erreur : "gpg: signing failed: Inappropriate ioctl for device"**

```bash
export GPG_TTY=$(tty)
# Ajoutez cette ligne à votre ~/.bashrc ou ~/.zshrc
echo 'export GPG_TTY=$(tty)' >> ~/.zshrc
```

**Erreur : "gpg: signing failed: No secret key"**

Assurez-vous que Git utilise la bonne clé :

```bash
git config --global user.signingkey <your-key-id>
```

**Problème avec le cache de mot de passe GPG**

```bash
# Augmenter la durée du cache (1 heure)
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf

# Redémarrer l'agent GPG
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
```

### Bonnes pratiques

1. **Toujours signer vos commits** : Activez la signature automatique :
   ```bash
   git config --global commit.gpgsign true
   ```

2. **Sauvegarder votre clé GPG** : Exportez et sauvegardez votre clé privée en lieu sûr :
   ```bash
   gpg --export-secret-keys --armor <your-key-id> > gpg-private-key.asc
   ```

3. **Utiliser une passphrase forte** : Protégez votre clé GPG avec une passphrase robuste.

4. **Renouveler votre clé** : Définissez une date d'expiration et renouvelez régulièrement :
   ```bash
   gpg --edit-key <your-key-id>
   # Tapez 'expire' puis suivez les instructions
   ```

### Ressources

- [Documentation Git - Signature des commits](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work)
- [Documentation GitHub - Gestion des clés GPG](https://docs.github.com/en/authentication/managing-commit-signature-verification)
- [Guide GPG](https://www.gnupg.org/documentation/)
