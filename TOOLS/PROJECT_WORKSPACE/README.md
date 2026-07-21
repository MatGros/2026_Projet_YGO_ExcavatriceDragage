# PROJECT_WORKSPACE — Environnement de travail du projet

Configuration et mode d’emploi de l’environnement de développement du projet : **Pi**, **AGY Antigravity**, **Claude Code**, **OpenCode** (avec agents Orchestrateur, Codeur & Vérificateur intégrés), gates, **Herdr** et visualisation du workflow.

L’extension VS Code **Terminals Manager** est uniquement le mécanisme utilisé pour afficher ces outils dans le terminal intégré.

Extension : `fabiospampinato.vscode-terminals`

## 🎯 Rôle

Cet environnement ouvre, dans le terminal intégré VS Code, neuf onglets indépendants :

| Onglet | Commande | Rôle |
|---|---|---|
| **🥧 Pi** | `pi` | Agent de coding Pi dans le projet |
| **🚀 AGY Antigravity** | `agy` | Agent Antigravity CLI dans le projet |
| **🧠 Claude Code** | `claude` | Agent Claude Code CLI dans le projet |
| **🦙 Claude Code (Ollama)** | `ollama launch claude --model gemma4:e4b` | Agent Claude Code local via Ollama (`gemma4:e4b`) |
| **🔓 OpenCode** | `opencode --agent orchestrateur` | Interface OpenCode unique avec agents Orchestrateur, Codeur (`@codeur`) et Vérificateur (`@verificateur`) |
| **🦙 OpenCode (Ollama)** | `ollama launch opencode --model gemma4:e4b` | Agent OpenCode local via Ollama (`gemma4:e4b`) |
| **✅ Gates** | `python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys` | Contrôles Python du workflow |
| **🤠 Herdr** | `herdr start-agent claude` | Agent Herdr/Claude optionnel |
| **📊 Workflow Graph** | `python TOOLS/DIAGRAM_GENERATORS/generate_all.py --no-header` | Génération de tous les diagrammes Mermaid |

Chaque terminal utilise la racine du projet comme répertoire courant :
`C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage`.

## 📦 Installation sur un autre PC

1. Installer VS Code.
2. Ouvrir le projet dans VS Code.
3. Ouvrir **Extensions** (`Ctrl+Shift+X`).
4. Rechercher **Terminals Manager** — auteur **Fabio Spampinato**.
5. Installer l’extension `fabiospampinato.vscode-terminals`.
6. Vérifier que Python, Pi, AGY (`agy`), Claude (`claude`) et Herdr sont disponibles dans le `PATH` si ces onglets sont utilisés.

La configuration active lue par VS Code est versionnée à la racine dans :

```text
.vscode/terminals.json
```

Et une copie source est également présente dans le dossier de l'outil :

```text
TOOLS/PROJECT_WORKSPACE/terminals.json
```

## ▶️ Utilisation

L’ouverture de VS Code ne lance rien automatiquement (`autorun: false`).

Pour lancer les sept onglets :

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

## 👁️ Afficher le graphe

Le terminal **Workflow Graph** génère les deux diagrammes à partir des sources du projet. Il n’affiche pas le dessin dans le terminal.

La mise en page applique ces règles :
- le workflow utilise l’ordre `BT` défini dans `workflow_diagram.json` ;
- la structure affiche uniquement les dossiers principaux et leurs compteurs ;
- les dossiers vides sont masqués pour garder une vue lisible ;
- les fichiers détaillés ne sont pas affichés dans la vue globale.

Ouvre ensuite ce fichier dans VS Code avec une extension de prévisualisation Mermaid, par exemple **Markdown Preview Mermaid Support**, puis utilise l’aperçu Markdown.

## 🔧 Dépannage

### La commande n’est pas reconnue

Tester dans un terminal VS Code :

```powershell
python --version
pi --version
agy --version
claude --version
herdr --help
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
- `TOOLS/ST_PLCOPENXML_GENERATOR/` reste totalement autonome et n’est pas modifié par cette configuration.
