# TOOLS — Outils du projet

Ce dossier contient **deux outils indépendants** + **documentation/configuration workspace** :

```
TOOLS/
├── AGENT_WORKFLOW/       # Orchestration agents, gates, policies, skills
│   ├── scripts/          # Gates Python (structure, style, bundle, compile, pre-edit)
│   ├── skills/           # Skills (codesys-change, codesys-review, ...)
│   ├── docs/             # Policies (SAFETY, WORKFLOW, TOKEN, DOC_WRITING, ...)
│   ├── schemas/          # JSON schemas (requirement_intake)
│   ├── templates/        # Templates ST & DOC
│   ├── prompts/          # Prompts agents
│   └── config/           # naming_baseline.json, workflow_diagram.json, Device_IO_*.csv
├── ST_PLCOPENXML_GENERATOR/  # Convertisseur ST → PLCopenXML (autonome)
    ├── generator/        # Code Python du générateur
    ├── tests/            # Unitaires, intégration, golden files (306 tests)
    ├── SAMPLES_CODESYS/
    ├── test_import_poc/
    └── docs/
├── LINTER_ST/               # Linter ST CODESYS 3.5 (STruCpp vendoré, 100% encapsulé)
│   ├── resolve_deps.py       # Résolveur de dépendances (types/FB) autonome
│   ├── lint.py                # Orchestrateur : deps → conversion → compile → diagnostics JSON
│   └── bin/win32-x64/         # strucpp.exe vendoré (copie propre)
├── COMPILER_ST2C_STruCpp/   # PoC compilation FB en C++17 pour tests boîte noire (STruCpp)
├── PROJECT_WORKSPACE/       # Environnement de travail du projet (AGY, Claude, Codex, OpenCode, Gates, Graph)
│   ├── README.md             # Documentation et guide (terminaux VS Code)
│   ├── MARKDOWN_WORKSPACE.md # Édition & cochage des fichiers Markdown (Ctrl+K V)
│   └── terminals.json        # Fichier de configuration modèle
├── DIAGRAM_GENERATORS/      # Générateurs spécialisés de diagrammes Mermaid
└── visualize_workflow.py    # Compatibilité et moteur commun Mermaid
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
cd TOOLS/ST_PLCOPENXML_GENERATOR
python -m pytest                          # 306 tests
python -m generator.cli --bundle CODE_Bundle --project-name "MGS_v0.4.18" --timestamp "2026-07-18T00:05:50"
```

### 3️⃣ Validation compilation CODESYS (après build manuel)

```powershell
# 💾 Après un build dans CODESYS, exporter le log :
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --codesys-log build.log --strict
```

### Lancer les terminaux VS Code (AGY + Claude + Codex + OpenCode + Gates + Graph)

L’extension **Terminals Manager** ouvre les dix onglets dans le terminal intégré :

```text
Ctrl+Shift+P → Terminals: Run
```

Configuration et procédure : `TOOLS/PROJECT_WORKSPACE/README.md`.

Le lancement est volontairement manuel : rien ne démarre à l’ouverture de VS Code.

> Pour un démarrage automatique via session, utilisez également l’extension **Terminal Keeper** (Nguyen Ngoc Long) avec `.vscode/sessions.json`.


### Visualiser le workflow (Mermaid)

```powershell
# Générer diagramme Mermaid
python TOOLS/DIAGRAM_GENERATORS/generate_all.py --no-header

# Voir dans VS Code (Markdown preview) ou Mermaid Live Editor
```

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
|---|---|---|
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

### `ST_PLCOPENXML_GENERATOR/` — Compilateur maison

🏭 **Convertisseur autonome** : ST (notre dialecte) → PLCopenXML (format CODESYS universal) :

- 306 tests unitaires + intégration (pas de régression)
- Appelé par `generate_codesys_bundle.py`
- **Jamais** copier du code du générateur dans `AGENT_WORKFLOW` — c'est une CLI externa

### `PROJECT_WORKSPACE/` — Orchestration IDE

🖥️ Config VS Code : lance AGY, Claude, Codex, OpenCode, Gates, Graph dans 10 terminaux parallèles (1 raccourci)
- `README.md` → terminaux VS Code (`Ctrl+Shift+P` → **Terminals: Run**)
- `MARKDOWN_WORKSPACE.md` → édition & cochage des fichiers Markdown (`Ctrl+K V` sans extension checkbox)

---

## Règle d'or

| Outil | Indépendance | Dépendances |
|---|---|---|
| `ST_PLCOPENXML_GENERATOR` | **100% autonome** | Aucune (Python stdlib + pytest) |
| `LINTER_ST` | **100% autonome** | Aucune — vendore sa propre copie de STruCpp, aucun lien vers `COMPILER_ST2C_STruCpp` |
| `COMPILER_ST2C_STruCpp` | **100% autonome** | Aucune — vendore sa propre copie de STruCpp |
| `AGENT_WORKFLOW` | Orchestration | Appelle le générateur via CLI, n'intègre pas son code |

Ne **jamais** copier du code du générateur dans AGENT_WORKFLOW.
L'orchestrateur appelle le générateur comme un outil externe (`subprocess` / CLI).

---

## Arborescence projet (contexte)

```
PROJET/
├── CODE/           # Sources ST (automate)
├── DOC/            # Spécifications fonctionnelles (AF_Partie-XX)
├── TOOLS/          # Outils (ce dossier)
│   ├── AGENT_WORKFLOW/
│   └── ST_PLCOPENXML_GENERATOR/
└── ARCHIVES/       # Docs & outils obsolètes
```

---

## Versioning

| Outil | Version | Changelog |
|---|---|---|
| AGENT_WORKFLOW | Voir `TOOLS/AGENT_WORKFLOW/pyproject.toml` | `DOC/VERSION_HISTORY.md` |
| ST_PLCOPENXML_GENERATOR | Voir `TOOLS/ST_PLCOPENXML_GENERATOR/pyproject.toml` | `DOC/VERSION_HISTORY.md` |

Chaque outil gère son propre versioning. Le projet principal référence les versions dans `DOC/VERSION_HISTORY.md`.