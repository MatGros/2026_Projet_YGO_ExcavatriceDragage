# TOOLS — Outils du projet

Ce dossier contient **deux outils indépendants** :

```
TOOLS/
├── AGENT_WORKFLOW/       # Orchestration agents, gates, policies, skills Pi
│   ├── scripts/          # Gates Python (structure, style, bundle, compile, pre-edit)
│   ├── skills/           # Skills Pi Coding Agent (codesys-change, herdr-review, ...)
│   ├── docs/             # Policies (SAFETY, WORKFLOW, TOKEN, DOC_WRITING, ...)
│   ├── schemas/          # JSON schemas (herdr_review, requirement_intake)
│   ├── templates/        # Templates ST & DOC
│   ├── prompts/          # Prompts agents
│   └── config/           # herdr_policy.json
│
└── ST_PLCOPENXML_GENERATOR/  # Convertisseur ST → PLCopenXML (autonome)
    ├── generator/        # Code Python du générateur
    ├── tests/            # Unitaires, intégration, golden files (306 tests)
    ├── samples_reference_codesys/
    ├── test_import_poc/
    └── docs/
```

## Utilisation rapide

### Générer le bundle PLCopenXML

```powershell
# Depuis la racine du projet
cd TOOLS/ST_PLCOPENXML_GENERATOR
python -m pytest                          # 306 tests
python -m generator.cli --bundle CODE_Bundle --project-name "MGS_v0.4.18" --timestamp "2026-07-18T00:05:50"
```

Sortie : `CODE/CODE_Bundle.xml` → importer dans CODESYS.

### Lancer tous les gates (workflow)

```powershell
# Gates Python uniquement
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --skip-codesys

# Gates + validation compilation CODESYS (après build manuel)
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --codesys-log build.log --strict
```

### Skills Pi Coding Agent

Installation :

```powershell
pip install -e TOOLS/AGENT_WORKFLOW
# ou via Pi : pi package add TOOLS/AGENT_WORKFLOW
```

Skills disponibles : `codesys-change`, `codesys-review`, `herdr-review`, `doc-sync`, `release-check`, `requirement-intake`.

---

## Règle d'or

| Outil | Indépendance | Dépendances |
|---|---|---|
| `ST_PLCOPENXML_GENERATOR` | **100% autonome** | Aucune (Python stdlib + pytest) |
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
├── ARCHIVES/       # Docs & outils obsolètes
└── .pi/            # Config Pi Coding Agent
```

---

## Versioning

| Outil | Version | Changelog |
|---|---|---|
| AGENT_WORKFLOW | Voir `TOOLS/AGENT_WORKFLOW/pyproject.toml` | `TOOLS/AGENT_WORKFLOW/CHANGELOG.md` |
| ST_PLCOPENXML_GENERATOR | Voir `TOOLS/ST_PLCOPENXML_GENERATOR/pyproject.toml` | `TOOLS/ST_PLCOPENXML_GENERATOR/CHANGELOG.md` |

Chaque outil gère son propre versioning. Le projet principal référence les versions dans `DOC/VERSION_HISTORY.md`.