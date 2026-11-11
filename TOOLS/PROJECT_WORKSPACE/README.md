# PROJECT_WORKSPACE — Environnement de travail du projet

Configuration et mode d’emploi de l’environnement de développement du projet : **AGY Antigravity**,
**Claude Code**, **Codex**, **OpenCode** (avec agents Orchestrateur, Codeur & Vérificateur intégrés),
gates et visualisation du workflow.

> 📌 **Herdr** retiré le 2026-08-17 (workflow abandonné, voir `AGENTS.md` — délégation
> désormais antigravity/Codex/agents Claude Code natifs).

L’extension VS Code **Terminals Manager** est le mécanisme recommandé pour ouvrir manuellement des terminaux configurés dans ce projet.

Extension : `fabiospampinato.vscode-terminals`

## Task Manager au demarrage

La session Terminal Keeper `AI` ouvre aussi un terminal `Task Manager` au demarrage de VS Code.
Il lance `TOOLS/TASK_MANAGER/LANCER_TASK_MANAGER.bat`, qui :

- arrete une instance precedente qui ecoute sur le port reserve `8081` ;
- demarre l'unique serveur Task Manager ;
- ouvre le navigateur externe sur `http://127.0.0.1:8081/TASK_VIEWER.html`.

Le port `8081` est exclusivement reserve au Task Manager.

> Pour un lancement automatique à l’ouverture du workspace, ce projet contient également une configuration de session dans `.vscode/sessions.json` compatible avec l’extension **Terminal Keeper** de Nguyen Ngoc Long.

## 🎯 Rôle

Cet environnement ouvre, dans le terminal intégré VS Code, huit onglets indépendants :

| Onglet | Commande | Rôle |
|---|---|---|
| **Task Manager** | `cmd /c TOOLS\TASK_MANAGER\LANCER_TASK_MANAGER.bat` | Suivi local des tâches |
| **🚀 AGY Antigravity** | `agy` | Agent Antigravity CLI dans le projet |
| **🧠 Claude Code** | `claude` | Agent Claude Code CLI dans le projet |
| **Claude Code OmniRoute AGY** | Voir la commande détaillée ci-dessous | Claude Code via `agy/gemini-3.8-flash-tiered` |
| **🔓 OpenCode** | `opencode --agent orchestrateur` | Interface OpenCode unique avec agents Orchestrateur, Codeur (`@codeur`) et Vérificateur (`@verificateur`) |
| **🌐 OmniRoute Server** | `cmd /c "set OMNIROUTE_SERVER_HOST=127.0.0.1&& omniroute"` | Serveur local, limité à la machine |
| **🤖 Codex (OpenAI)** | `codex` | Agent Codex CLI dans le projet |
| **🦙 DSH (Ollama)** | `ollama launch dsh` | Agent DSH local via Ollama |

OpenCode-Go (glm-5.2) est désactivé dans `disabled_terminals` ; les terminaux Ollama et Gates qui y figurent restent désactivés.

Chaque terminal utilise la racine du projet comme répertoire courant :
`C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage`.

## 📦 Installation sur un autre PC

1. Installer VS Code.
2. Ouvrir le projet dans VS Code.
3. Ouvrir **Extensions** (`Ctrl+Shift+X`).
4. Rechercher **Terminals Manager** — auteur **Fabio Spampinato**.
5. Installer l’extension `fabiospampinato.vscode-terminals`.
6. Si vous voulez que des terminaux s’ouvrent automatiquement au démarrage du workspace, installer également **Terminal Keeper** — auteur **Nguyen Ngoc Long**.
7. Vérifier que Python, AGY (`agy`), Claude (`claude`) et Codex (`codex`) sont disponibles dans le `PATH` si ces onglets sont utilisés.

La configuration active lue par VS Code est versionnée à la racine dans :

```text
.vscode/terminals.json
```

Et une copie source est également présente dans le dossier de l'outil :

```text
TOOLS/PROJECT_WORKSPACE/terminals.json
```

⚠️ **Les deux fichiers ne sont liés par aucun mécanisme** (pas de build, pas de symlink) — un
copier-coller manuel. Elles ont déjà divergé une fois (onglets `Codex`/`DSH` ajoutés à `.vscode/`
sans être reportés dans la copie source, corrigé le 2026-08-17). **Toute modification d'un des
deux fichiers doit être reportée à l'identique dans l'autre dans le même geste.**

## ▶️ Utilisation

L’ouverture de VS Code ne lance rien automatiquement (`autorun: false`).

Pour lancer les huit onglets :

1. `Ctrl+Shift+P`
2. Exécuter **Terminals: Run**

Pour lancer un seul onglet :

```text
Terminals: Run Single
```

Pour arrêter les terminaux créés par l’extension :

```text
Terminals: Kill
```

## ⚙️ Fonctionnement de `terminals.json`

- `autorun: false` : aucun programme ne démarre à l’ouverture du projet.
- `cwd` : dossier de travail de chaque terminal.
- `command` : commande exécutée dans l’onglet.
- `open: true` : ouvre l’onglet après exécution.
- Aucun champ `split` n’est utilisé : les terminaux restent des onglets indépendants.

## 🔧 Dépannage

### La commande n’est pas reconnue

Tester dans un terminal VS Code :

```powershell
python --version
agy --version
claude --version
codex --version
```

Installer ou ajouter au `PATH` le programme manquant.

### Le fichier de configuration n’apparaît pas

Ouvrir le projet comme dossier racine, puis vérifier :

```text
.vscode/terminals.json
```

### Les terminaux se lancent automatiquement

Vérifier que le fichier contient :

```json
"autorun": false
```

## 🚫 Choix volontaire

- Aucun `.bat` nécessaire.
- Aucun lanceur PowerShell externe nécessaire.
- Aucun `runOn: folderOpen` dans les tasks.
- Aucun split forcé.
- `TOOLS/CONVERTER_ST2XML_PLCopenXML/` reste totalement autonome et n’est pas modifié par cette configuration.

## Claude Code via OmniRoute / AGY

Le terminal Terminal Keeper **Claude Code OmniRoute AGY (Gemini 3.8)** lance Claude Code avec le modèle `agy/gemini-3.8-flash-tiered` via le serveur OmniRoute local.

```cmd
cmd /c "set ANTHROPIC_BASE_URL=http://127.0.0.1:20128&& set ANTHROPIC_AUTH_TOKEN=local-dev&& set ANTHROPIC_API_KEY=&& set ANTHROPIC_MODEL=agy/gemini-3.8-flash-tiered&& claude --model agy/gemini-3.8-flash-tiered"
```

Les variables ne vivent que dans le processus `cmd` et ses enfants : le terminal **Claude Code classique** conserve sa configuration. L’URL loopback est la racine OmniRoute, sans `/v1`, car Claude Code utilise le protocole Anthropic. Le `local-dev` est le jeton local accepté pendant l’essai ; si l’instance OmniRoute impose une clé, utiliser le jeton local configuré pour cette instance.

Le raccourci `omniroute launch` échoue sur cette installation Windows en cherchant `claude.cmd` alors que Claude Code est installé comme `claude.exe` ; la commande ci-dessus lance directement `claude`.

Le terminal **OmniRoute Server** de Terminal Keeper est lié à `127.0.0.1` : il n'écoute pas sur le réseau local. Il démarre le serveur une seule fois avant **Claude Code OmniRoute AGY**. L'ancienne commande `omniroute` est archivée dans `disabled_terminals`; l'entrée du modèle Terminals Manager est masquée de ses commandes d'exécution (`onlyAPI: true`) pour éviter un second serveur. Test réel du 2026-11-11 après mise à jour vers OmniRoute 3.8.53 : Claude Code a reçu `PONG` de `agy/gemini-3.8-flash-tiered`. L'avertissement Claude Code « model isn't recognized » reste affiché, mais n'empêche pas la requête. OpenCode-Go (glm-5.2) est conservé dans `disabled_terminals` et peut être réactivé dans `.vscode/sessions.json`.
