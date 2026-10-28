# Installer les skills

Les skills suivent le standard [Agent Skills](https://agentskills.io/specification) : ils fonctionnent avec Claude Code
et OpenCode. Choisissez **une seule** façon d'installer par client : en combiner deux charge les skills deux fois.

| | Claude Code (plugin) | OpenCode (plugin) | OpenCode (URL) | OpenCode (clone) | Copie (tout client) |
| --- | :---: | :---: | :---: | :---: | :---: |
| Skills | ✅ | ✅ | ✅ | ✅ | ✅ |
| Liens relatifs vers `docs/` et `git-hooks/` | ✅ | ✅ | ❌ (doc en ligne) | ✅ | ❌ (doc en ligne) |
| Mise à jour | `plugin update` | vider le cache | automatique | `git pull` | à refaire |

## Claude Code

**Avant de commencer**, il faut :

- [Claude Code](https://code.claude.com/docs/en/overview) **2.1.275 ou plus récent** : `claude --version` affiche la version ;
- `git` et un accès à github.com (le dépôt est public) ;
- recommandé, mais pas obligatoire : la [CLI GitHub `gh`](https://cli.github.com/), connectée avec `gh auth login`.
  L'agent s'en sert pour vérifier que vos secrets existent (leurs **noms**, jamais leurs valeurs) et lire les logs
  d'un run en échec. Sans elle, il vous indique quoi vérifier dans l'interface GitHub.

**1. Ajouter le catalogue.** Dans un terminal :

```bash
claude plugin marketplace add dnum-mi/fabnum-cicd
```

Cela n'enregistre que la liste des plugins disponibles : aucun skill n'est encore actif.

**2. Installer le plugin.**

```bash
claude plugin install fabnum-cicd@fabnum-cicd
```

Ou, depuis une session Claude Code, en une seule étape (qui remplace aussi l'étape 1) :

```
/plugin install fabnum-cicd --marketplace dnum-mi/fabnum-cicd
```

**3. Vérifier.** Lancez `claude` dans votre projet, puis tapez `/reload-plugins` (inutile si vous venez de démarrer la
session). Dans un terminal :

```bash
claude plugin list
```

La ligne `fabnum-cicd@fabnum-cicd` doit apparaître avec le statut `enabled`. Dans Claude Code, la commande `/skills`
liste les cinq skills `fabnum-cicd-…`.

**4. Les essayer.** Dans votre projet, demandez par exemple :

- « Mets en place la CI de ce projet avec les workflows fabnum-cicd. »
- « Ma PR de release ne déclenche pas la CI, pourquoi ? »
- « Relis mon `.github/workflows/ci.yml` selon les recommandations fabnum-cicd. »
- « Installe les git hooks de fabnum-cicd. »

L'agent charge le skill adapté tout seul. Vous pouvez aussi le nommer : « utilise le skill fabnum-cicd-auth ».
Relisez toujours ce qu'il écrit avant de committer : c'est vous qui créez les secrets dans GitHub.

**Mettre à jour** (les skills suivent la branche `main`) :

```bash
claude plugin marketplace update fabnum-cicd
claude plugin update fabnum-cicd@fabnum-cicd
```

**Désinstaller** : `claude plugin uninstall fabnum-cicd@fabnum-cicd`.

**Pour toute l'équipe**, versionnez dans le `.claude/settings.json` de votre projet : Claude Code proposera
l'installation à l'ouverture du dossier.

```json
{
  "extraKnownMarketplaces": {
    "fabnum-cicd": { "source": { "source": "github", "repo": "dnum-mi/fabnum-cicd" } }
  },
  "enabledPlugins": { "fabnum-cicd@fabnum-cicd": true }
}
```

## OpenCode

OpenCode ne lit pas les marketplaces de plugins de Claude Code, mais il charge les skills au standard Agent Skills
depuis un plugin, une URL ou le dossier d'un clone. Version testée : OpenCode 1.18.35. Prérequis : `git` ; `gh`
authentifié est recommandé, pas obligatoire (voir plus haut pour son rôle).

### Façon recommandée : le plugin

Dans le `opencode.json` du projet, ou dans `~/.config/opencode/opencode.json` pour tous vos projets :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["fabnum-cicd@git+https://github.com/dnum-mi/fabnum-cicd.git"]
}
```

OpenCode clone le dépôt dans son cache (`~/.cache/opencode/packages/`) et charge
[`.opencode/plugins/fabnum-cicd.js`](../../.opencode/plugins/fabnum-cicd.js). Ce plugin ne fait qu'une chose : ajouter le
dossier `skills/` du clone à la configuration d'OpenCode (même mécanisme que le plugin de
[`starter-kit-opencode`](https://github.com/dnum-mi/starter-kit-opencode)). Il n'exécute aucune commande. Comme le
dépôt est cloné en entier, les liens relatifs des skills vers `docs/` et `git-hooks/` résolvent.

- **Figer une version** : ajouter `#<tag ou sha>` à l'URL, par exemple `…/fabnum-cicd.git#v0.25.1`. Sans cela, le
  plugin suit `main`.
- **Mettre à jour** : supprimer le dossier `fabnum-cicd@…` de `~/.cache/opencode/packages/`, puis relancer OpenCode.

**Vérifier** dans un terminal :

```bash
opencode debug skill
```

Les cinq skills `fabnum-cicd-…` doivent apparaître dans la liste. Dans OpenCode, l'agent les propose via son outil
`skill` quand la demande correspond ; vous pouvez aussi le lui demander par son nom.

### Sans plugin : une URL

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": {
    "urls": ["https://raw.githubusercontent.com/dnum-mi/fabnum-cicd/main/skills/"]
  }
}
```

OpenCode lit [`skills/index.json`](../../skills/index.json) et ne télécharge que les fichiers qu'il liste. Les skills
sont alors seuls : les liens relatifs vers `docs/` et `git-hooks/` ne résolvent pas, l'agent se rabat sur la
[documentation en ligne](https://github.com/dnum-mi/fabnum-cicd/tree/main/docs). Remplacer `main` par un tag fige la
version. OpenCode 2 remplace `skills.paths` et `skills.urls` par un seul tableau : `"skills": ["https://…/skills/"]`.

### Sans plugin : un clone et `skills.paths`

```bash
git clone --branch v0.25.1 https://github.com/dnum-mi/fabnum-cicd.git ~/fabnum-cicd
```

```json
{
  "$schema": "https://opencode.ai/config.json",
  "skills": {
    "paths": ["~/fabnum-cicd/skills"]
  }
}
```

Mise à jour : `git -C ~/fabnum-cicd fetch --tags && git -C ~/fabnum-cicd checkout <tag>` (sans `--branch`, le clone
suit `main` et un `git pull` suffit).

### Autorisations

Si votre configuration restreint les skills, autorisez ceux-ci :

```json
{
  "permission": {
    "skill": { "fabnum-cicd-*": "allow" }
  }
}
```

## Copie, pour tout autre agent compatible

Copier les skills dans le dossier global de votre agent. OpenCode lit aussi `~/.agents/skills`, `~/.claude/skills` et,
par projet, `.opencode/skills`, `.claude/skills` et `.agents/skills`.

```bash
git clone --depth 1 https://github.com/dnum-mi/fabnum-cicd.git
cp -r fabnum-cicd/skills/fabnum-cicd-* ~/.agents/skills/
```

Les liens vers `docs/` ne résolvent alors plus : l'agent s'appuie sur le catalogue du skill `fabnum-cicd-pipeline` et
sur la [documentation en ligne](../workflows/01-introduction.md).

## Ce que les skills ne font pas

- Ils ne contiennent aucun code exécutable : l'agent écrit des fichiers et peut lancer quelques commandes (`cp`, `gh secret list`, `actionlint`…) que votre client vous demande d'approuver ; GitHub exécute les workflows.
- Ils ne lisent ni n'écrivent la valeur d'un secret : c'est vous qui les créez dans GitHub.
- Relisez toujours ce que l'agent propose avant de committer.
