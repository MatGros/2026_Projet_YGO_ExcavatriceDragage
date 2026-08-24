# AGENT_WORKFLOW — Orchestration, Gates & Policies

Outillage agent du projet : **scripts de gate** (fichiers plats appelés directement par Python),
**skills de référence**, **prompts**, **policies**, **gabarits** et **config**.

> ⚠️ **Réalité disque (T150-C)** : il n'existe **pas** de package Python installable ici.
> Il n'y a **ni `pyproject.toml`, ni `src/agent_workflow/`**. Les scripts sont des **fichiers
> plats** dans `scripts/*.py`, exécutés directement :
> ```powershell
> python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py
> ```

```text
TOOLS/AGENT_WORKFLOW/
├── scripts/                     # Gates Python (structure, style, bundle, compile, pre-edit, skills)
├── skills/                      # Skills de référence (codesys-change, codesys-review, doc-sync, ...)
├── prompts/                     # Prompts standardisés (troubleshooting, release-check, subagent_preamble, ...)
├── schemas/                     # JSON Schemas (requirement_intake)
├── docs/                        # Policies (SAFETY, WORKFLOW, TOKEN, DOC_WRITING, CODE_WRITING, ...)
├── templates/                   # Gabarits de projet (FB, PRG, GVL, spec, ...) — voir DOC/WFLOW/TEMPLATE
├── config/                      # naming_baseline.json, workflow_diagram.json
├── hooks/                       # Hooks Git partagés (pre-push)
└── tests/                       # Tests unitaires des gates (pytest)
```

---

## 🚀 Utilisation

Tous les scripts se lancent **depuis la racine du projet** via `python` :

```powershell
# ✅ Tous les gates : liaison + structure + style (fin de lot)
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py

# 🎯 Par palier (GUIDE_GATES_ET_TESTS §2) : A=bloc isolé, B=liens, C=fin de lot, D=sur demande
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --palier C

# 🔗 BLOQUANT : vérifier que TOUT est câblé (REX 2026-07-29)
python TOOLS/AGENT_WORKFLOW/scripts/G200_check_linkage.py --report

# Générer le bundle PLCopenXML
python TOOLS/AGENT_WORKFLOW/scripts/generate_codesys_bundle.py .

# Gate anti-dérive des skills agents (stub + canonique, T150-A)
python TOOLS/AGENT_WORKFLOW/scripts/check_skill_stubs.py .
```

## 🗂️ Gates (dans `scripts/`)

Les gates G1xx–G5xx sont des filtres automatiques qui **bloquent le code cassé avant qu'il
n'entre en CODESYS**. Ils sont regroupés par palier dans `run_all_gates.py` (voir le docstring
du fichier et `docs/WORKFLOW.md`).

| Gate | Rôle |
|---|---|
| `G100`–`G110` | Structure/style du code ST (palier A) |
| `G200`–`G210` | **Liaison réelle** + câblage CFC natif (palier B, **bloquant**) |
| `G300`–`G430` | Structure dépôt, bundle, types, docs, commentaires REX (palier C) |
| `G440` | Skills agents stub + canonique (anti-dérive, T150-A) |
| `G500` | Compilation CODESYS (palier D, sur demande, `--codesys-log`) |

Détail de chaque gate : docstring du fichier + `docs/WORKFLOW.md`.

## 🧪 Tests unitaires des gates

```bash
python -m pytest TOOLS/AGENT_WORKFLOW/tests/ -q
```

## 🔌 Vérification de compilation CODESYS (optionnelle)

```bash
python TOOLS/AGENT_WORKFLOW/scripts/run_all_gates.py --codesys-log build.log --strict
```

---

## 📚 Skills (référence dans `skills/`, auto-découvertes dans `.claude/skills/`)

Les skills « de référence » (`skills/`) ne sont **pas** auto-découvertes par les outils — ce sont
des procédures pointées par `AGENTS.md`/`WORKFLOW.md`. Les skills **déclenchables** vivent dans
`.claude/skills/` (Claude Code) et `.dsh/skills/` (DSH), sous forme de **stub** pointant vers une
source canonique (cf. `check_skill_stubs.py`, T150-A).

| Skill | Rôle |
|---|---|
| `codesys-change` | Modification CODE/ : lecture specs, plan, gates, bundle, validation humaine |
| `codesys-review` | Revue read-only CODE/DOC/tests |
| `doc-sync` | Maj DOC après modification CODE |
| `release-check` | Checklist fin de tâche |
| `requirement-intake` | Qualification `NEW_INFORMATION` avant tout code |

## 📚 Policies (dans `docs/`)

| Fichier | Sujet |
|---|---|
| `SAFETY_POLICY.md` | Interdiction Ponytail safety, validation humaine obligatoire |
| `WORKFLOW.md` | Flux `CODE_CHANGE` / `NEW_INFORMATION`, criticité C0–C4 |
| `TOKEN_POLICY.md` | Gestion budget tokens |
| `DOC_WRITING_POLICY.md` | Style docs projet |
| `CODE_WRITING_POLICY.md` | Style ST (headers, naming, contrats FB) |
| `MODEL_ROUTING.md` | Routage des modèles (ancien environnement de sous-agents abandonné 2026-08-17) |
| `DSH_PROVIDERS.md` | Provider `omniroute` + délégation multi-modèles |
| `TASK_CONTEXT.md` | Contexte de tâche / contract |
| `STRUCTURE_AND_CLEANUP.md` | Arborescence, archivage, nettoyage |
| `RELEASE_PROCESS.md` | Checklist fin de tâche |

## 📦 Templates (dans `templates/`)

Décision T150-G (2026-08-24) : les **gabarits de projet** (en-têtes ST, spec AF, fiche requise,
bannière...) sont rattachés au pilotage projet sous **`DOC/WFLOW/TEMPLATE/`** (ex. gabarit de
bannière `SKILL_BANNER_TEMPLATE.md`). Le dossier `templates/` de `AGENT_WORKFLOW` conserve les
gabarits d'outillage/agents (task_contract, etc.). Si un gabarit est en fait un *standard projet*,
il doit vivre sous `DOC/WFLOW/TEMPLATE/` ou `DOC/STDS/` et être référencé, jamais dupliqué.

## 📋 Schemas (dans `schemas/`)

| Schema | Validation |
|---|---|
| `requirement_intake.schema.json` | Entrée `NEW_INFORMATION` |

## 🗂️ Config (dans `config/`)

| Fichier | Rôle | Fraîcheur |
|---|---|---|
| `naming_baseline.json` | Baseline de nommage (lu par `G110_check_naming_style.py`, `TASK_VIEWER.html`) | Régénéré quand le nommage `CODE/` évolue (T150-B) |
| `workflow_diagram.json` | Source du diagramme Mermaid du workflow | Manuelle (le script visualize_workflow.py n'existe pas) |

## Versioning

- Les scripts et gates n'ont **pas de version propre** : leur évolution est tracée dans
  `DOC/VERSION_HISTORY.md`.
- Les gates sont nommés `G<id>_<nom>.py` (numérotation décrite dans `docs/WORKFLOW.md`).
