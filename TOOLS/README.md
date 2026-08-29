# TOOLS — Outils du projet

Ce dossier contient **deux outils indépendants** + **documentation/configuration workspace** :

```text
TOOLS/
├── AGENT_WORKFLOW/                # Orchestration agents, gates, policies, skills
│   ├── scripts/                   # Gates Python (structure, style, bundle, compile, pre-edit)
│   ├── skills/                    # Skills (codesys-change, codesys-review, ...)
│   ├── docs/                      # Policies (SAFETY, WORKFLOW, TOKEN, DOC_WRITING, ...)
│   ├── templates/                 # Templates ST & DOC
│   └── prompts/                   # Prompts agents
├── COMPILER_ST2C_STruCpp/         # Compilation ST → C++17 & tests unitaires boîte noire (STruCpp)
├── CONVERTER_ST2XML_PLCopenXML/   # Convertisseur ST → PLCopenXML (autonome)
│   ├── generator/                 # Code Python du générateur
│   ├── scripts/                   # Scripts CLI modulaires (st_to_pou, build_bundle)
│   ├── tests/                     # Tests Pytest unitaires, intégration, golden files (393 tests)
│   └── docs/                      # Spécifications format PLCopenXML CODESYS
├── LINTER_ST/                     # Linter ST CODESYS 3.5 (STruCpp vendoré, 100% encapsulé)
│   ├── lint.py                    # Orchestrateur : deps → conversion → compile → diagnostics JSON
│   ├── resolve_deps.py            # Résolveur de dépendances (types/FB) autonome
│   └── bin/win32-x64/             # strucpp.exe vendoré (copie propre)
├── LM_STUDIO/                     # Connecteur client streaming LLM distant
├── PLC_CSV_SNAPSHOT/              # Capture & snapshot CSV des variables réelles CODESYS
│   ├── codesys_console/           # Scripts exécutés dans la console CODESYS
│   ├── variable_lists/            # Listes de variables à acquérir
│   └── RESULTS/                   # Snapshots et acquisitions horodatées
├── PROJECT_WORKSPACE/             # Environnement & terminaux VS Code
├── SAMPLES_XML_CODESYS/           # Échantillons XML réels de référence CODESYS (24 fichiers)
└── TEST_AUTO_CI/                  # Suites de validation & intégration continue
```

## 🚀 Utilisation rapide

### 1️⃣ Valider le code (avant de terminer une tâche)

```powershell
# 📋 Tous les gates : liaison + structure + style
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py

# 🔗 BLOQUANT : Vérifier que TOUT est câblé (REX 2026-07-29)
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report
```

👉 **Pas de commit sans gates verts ET validation utilisateur** — les deux sont obligatoires.

### 2️⃣ Générer le bundle PLCopenXML

```powershell
# Depuis la racine du projet
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .
# Sortie : CODE_XML/CODE_Bundle.xml → copier/coller dans CODESYS 3.5
```

**Alternative manuelle** (rarement) :

```powershell
cd TOOLS/CONVERTER_ST2XML_PLCopenXML
python -m pytest                          # 306 tests
python -m generator.cli --bundle CODE_Bundle --project-name "MGS_v0.4.18" --timestamp "2026-07-18T00:05:50"
```

### 3️⃣ Validation compilation CODESYS (après build manuel)

```powershell
# 💾 Après un build dans CODESYS, exporter le log :
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --codesys-log build.log --strict
```

### Lancer les terminaux VS Code (AGY + Claude + Codex + OpenCode + Gates)

L’extension **Terminals Manager** ouvre les neuf onglets dans le terminal intégré :

```text
Ctrl+Shift+P → Terminals: Run
```

Configuration et procédure : `TOOLS/PROJECT_WORKSPACE/README.md`.

Le lancement est volontairement manuel : rien ne démarre à l’ouverture de VS Code.

> Pour un démarrage automatique via session, utilisez également l’extension **Terminal Keeper** (Nguyen Ngoc Long) avec `.vscode/sessions.json`.

### Visualiser le workflow (Mermaid)

🗄️ **Archivé** (diagrammes plus à jour, plus utilisé) : `ARCHIVES/Tools/DIAGRAM_GENERATORS/generate_all.py`

### Skills du workflow

Installation :

```powershell
pip install -e TOOLS/AGENT_WORKFLOW
```

Skills disponibles (`TOOLS/AGENT_WORKFLOW/skills/`, référence — non auto-découvertes par Claude
Code, seul `.claude/skills/` l'est) : `codesys-change`, `codesys-review`, `doc-sync`,
`release-check`, `requirement-intake`.

---

## 🧰 Ce que font les outils (dossier par dossier)

### `AGENT_WORKFLOW/scripts/` — Gates & Validation

📌 **Gates** = filtres automatiques qui **bloquent le code cassé avant qu'il ne rentre en CODESYS** :

| Gate | 🎯 Rôle | Bloque si... |
| --- | --- | --- |
| **`check_linkage.py`** | 🔗 Câblage réel : chaque variable appelle une autre variable, chaque FB sort dans `PRG_*_Outputs` | Une variable n'est nulle part connectée · un module orphelin · un appel de FB manquant |
| **`check_structure.py`** | 📦 Structure ST valide : pas de doublons FB, bonnes déclarations, interface FB conforme | Code ST mal formé · noms non-PascalCase · FB sans contrat (AF_Partie-03) |
| **`check_style.py`** | 🎨 Respect des conventions : noms, indentation, zones de code (INPUT/VAR/METHOD) | Majuscules mal placées · underscore → PascalCase · mauvaise section |
| **`check_compile.py`** | ⚙️ Compilation CODESYS OK (optionnel, si log disponible) | Erreurs build · warnings non tolérants |
| **`generate_codesys_bundle.py`** | 📦 Génère PLCopenXML → ready-to-import dans CODESYS | Invalid ST → PLCopenXML échoue |

👉 **Toujours lancer `run_all_gates.py` avant de terminer une tâche** — c'est le "test de consentement". Pas de commit sans gates verts **ET validation utilisateur** — les deux sont obligatoires.

### `AGENT_WORKFLOW/skills/` — Skills de référence

🤖 Compétences qu'on donne aux agents IA pour naviguer le projet (référence, pointées par
`AGENTS.md`/`WORKFLOW.md` — seul `.claude/skills/` est auto-découvert par Claude Code) :

- **`codesys-change`** 📝 : Modifier CODE/ (lecture specs, plan, gates, bundle, validation)
- **`codesys-review`** 🔍 : Review du code ST (sécurité machine, non-régression, contrats)
- **`doc-sync`** 🔄 : Mise à jour DOC après modification CODE
- **`release-check`** ✅ : Checklist fin de tâche
- **`requirement-intake`** 📥 : Qualification `NEW_INFORMATION` avant tout code

### `AGENT_WORKFLOW/docs/` — Policies & Architecture

📚 Directives machine-lisibles pour les agents :

- **`SAFETY.md`** ⚠️ : Règles immuables (Enable/SafeStop/StartStop, Reset sur front, pas d'auto-redémarrage)
- **`WORKFLOW.md`** 🔄 : Cycle d'édition (règles → archi → code → vérif → REX)
- **`DOC_WRITING.md`** ✍️ : Style documentation (précision = robustesse)

### `LINTER_ST/` — Linter ST (vraies erreurs, zéro faux positif)

🧹 Compile chaque `.st` (+ dépendances résolues automatiquement) via STruCpp vendoré, remonte
les erreurs réelles en JSON (`file/line/col/message`) — voir `TOOLS/LINTER_ST/README.md`.
Objectif final : diagnostics live dans VSCode (Problems panel), visibles aussi par les agents IA
via `getDiagnostics`. Priorité explicite : ne jamais remonter de fausse alerte (dépendance non
résolue → silence, pas d'erreur inventée).

### `COMPILER_ST2C_STruCpp/` — PoC tests boîte noire

🧪 Compile un FB en C++17 pour le tester en boîte noire (IN/OUT), hors CODESYS — voir
`TOOLS/COMPILER_ST2C_STruCpp/README.md`. Ne pas confondre avec `LINTER_ST/` : deux outils
indépendants qui vendorent chacun leur propre copie de STruCpp (pas de lien entre eux).

### `CONVERTER_ST2XML_PLCopenXML/` — Compilateur maison

🏭 **Convertisseur autonome** : ST (notre dialecte) → PLCopenXML (format CODESYS universal) :

- 306 tests unitaires + intégration (pas de régression)
- Appelé par `generate_codesys_bundle.py`
- **Jamais** copier du code du générateur dans `AGENT_WORKFLOW` — c'est une CLI externa

### `PROJECT_WORKSPACE/` — Orchestration IDE

🖥️ Config VS Code : lance AGY, Claude, Codex, OpenCode, Gates dans 9 terminaux parallèles (1 raccourci)

- `README.md` → terminaux VS Code (`Ctrl+Shift+P` → **Terminals: Run**)
- `MARKDOWN_WORKSPACE.md` → édition & cochage des fichiers Markdown (`Ctrl+K V` sans extension checkbox)

### 🗂️ Config — fraîcheur des fichiers (T150-B)

| Fichier | Producteur réel | Consommateur réel | Fraîcheur |
|---|---|---|---|
| `AGENT_WORKFLOW/config/naming_baseline.json` | `AGENT_WORKFLOW/scripts/G110_check_naming_style.py` (lit) — régénéré manuellement via son flag baseline | `G110_check_naming_style.py` | À régénérer quand le nommage `CODE/` évolue (normes IEC NC-010..070). |
| `AGENT_WORKFLOW/config/workflow_diagram.json` | ⚠️ **Aucun script ne le génère** — le fichier `visualize_workflow.py` (mentionné dans certains README) n'existe pas. Fichier maintenu manuellement. | `PROJECT_WORKSPACE/README.md` (cité), `DOC/WFLOW/TASK_VIEWER.html` (texte embarqué, pas un fetch) | Manuelle — aucun outil de regénération actif. Le diagramme Mermaid était généré par `generate_all.py`, désormais archivé (`ARCHIVES/Tools/DIAGRAM_GENERATORS/`). |

> ⚠️ **Audit T150-B (2026-08-24)** : `workflow_diagram.json` est référencé par 2 docs mais
> **aucun script ne le régénère** — c'est un fichier de configuration manuelle. `TASK_VIEWER.html`
> embarque ses données (JSON en dur dans `defaultTasks`) et **ne lit pas** ces fichiers `.json`
> à l'exécution.

---

## Règle d'or

| Outil | Indépendance | Dépendances |
| --- | --- | --- |
| `CONVERTER_ST2XML_PLCopenXML` | **100% autonome** | Aucune (Python stdlib + pytest) |
| `LINTER_ST` | **100% autonome** | Aucune — vendore sa propre copie de STruCpp, aucun lien vers `COMPILER_ST2C_STruCpp` |
| `COMPILER_ST2C_STruCpp` | **100% autonome** | Aucune — vendore sa propre copie de STruCpp |
| `AGENT_WORKFLOW` | Orchestration | Appelle le générateur via CLI, n'intègre pas son code |

Ne **jamais** copier du code du générateur dans AGENT_WORKFLOW.
L'orchestrateur appelle le générateur comme un outil externe (`subprocess` / CLI).

---

## Arborescence projet (contexte)

```text
PROJET/
├── CODE/           # Sources ST (automate)
├── DOC/            # Spécifications fonctionnelles (AF_Partie-XX)
├── TOOLS/          # Outils (ce dossier)
│   ├── AGENT_WORKFLOW/
│   └── CONVERTER_ST2XML_PLCopenXML/
└── ARCHIVES/       # Docs & outils obsolètes
```

---

## Versioning

| Outil | Version | Changelog |
| --- | --- | --- |
| AGENT_WORKFLOW | Voir `TOOLS/AGENT_WORKFLOW/pyproject.toml` | `DOC/VERSION_HISTORY.md` |
| CONVERTER_ST2XML_PLCopenXML | Voir `TOOLS/CONVERTER_ST2XML_PLCopenXML/pyproject.toml` | `DOC/VERSION_HISTORY.md` |

Chaque outil gère son propre versioning. Le projet principal référence les versions dans `DOC/VERSION_HISTORY.md`.
