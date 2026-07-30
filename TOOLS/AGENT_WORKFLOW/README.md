# AGENT_WORKFLOW — Orchestration, Gates & Policies

Package Python + Pi Coding Agent pour automatiser et fiabiliser le workflow CODESYS.

```text
TOOLS/AGENT_WORKFLOW/
├── src/agent_workflow/          # Code importable (scripts, gates, utils)
├── scripts/                     # Points d'entrée CLI (installés via pyproject.toml)
├── skills/                      # Skills Pi Coding (codesys-change, codesys-review, ...)
├── prompts/                     # Prompts standardisés (requirement-intake, release-check, ...)
├── schemas/                     # JSON Schemas (herdr_review, requirement_intake)
├── docs/                        # Policies (SAFETY, WORKFLOW, TOKEN, DOC_WRITING, CODE_WRITING, ...)
└── templates/                   # Gabarits (FB, PRG, GVL, spec, validation, ...)
```

---

## Installation

```powershell
pip install -e TOOLS/AGENT_WORKFLOW
```

Cela installe les commandes CLI ci-dessous et rend le package importable :
```python
from agent_workflow.scripts import check_code_style, run_all_gates
```

---

## Outils associés au workflow

- [TOOLS/ST_PLCOPENXML_GENERATOR/README.md](../ST_PLCOPENXML_GENERATOR/README.md) : générateur de bundle PLCopenXML à partir des sources ST et des POU XML natifs/CFC. Le workflow l'appelle pour produire `CODE/CODE_Bundle.xml` avant import CODESYS.
- [TOOLS/OUTILS_ST2PY/README.md](../OUTILS_ST2PY/README.md) : pont ST/XML → Python pour simulation, tests fonctionnels hors-PLC et non-régression. Outil d'aide, pas source de vérité ni substitut à la validation CODESYS/terrain.

---

## Commandes CLI (entry points)

| Commande | Description |
|---|---|
| `run-all-gates [--skip-codesys] [--codesys-log LOG] [--strict]` | Lance tous les gates : structure, style, bundle, pytest, (compilation CODESYS) |
| `check-structure` | Vérifie l'arborescence `CODE/` conforme |
| `check-code-style <scope>` | Tokens interdits, refs DOC, écritures `VAR_OUTPUT` illégales |
| `check-bundle-freshness <project_root>` | Compare `CODE_Bundle.xml` vs régénération déterministe |
| `pre-edit-gate --check <file.st> [--mark-read SPEC...]` | Bloque si specs DOC non lues avant modification CODE |
| `check-codesys-compile --log <build.log> [--strict] [--max-warnings N]` | Valide log de compilation CODESYS (0 erreur) |

### Exemples

```powershell
# Gates complets (sans CODESYS)
run-all-gates --skip-codesys

# Gates + validation compilation CODESYS
run-all-gates --codesys-log build.log --strict

# Vérification style sur un fichier
check-code-style CODE/TREUILS/FB_Winch.st

# Pre-edit gate : spécifications lues ?
pre-edit-gate --check CODE/TRANSLATION/FB_Translation.st
pre-edit-gate --mark-read DOC/AF_Partie-12/AF_Partie-12_Fonction_Translation_v2.0.md

# Validation compilation CODESYS
check-codesys-compile --log build.log --strict
```

---

## Gates — Détails

### 1. Structure (`check-structure`)
- Arborescence `CODE/` : dossiers obligatoires, noms PascalCase, pas de fichiers orphelins

### 2. Code Style (`check-code-style`)
- Tokens interdits : `CoupeEnable`, `FB_Watchdog`
- Références `DOC/*.md` dans l'en-tête (obligatoire pour FB/PRG/GVL métier)
- **Écriture sur `VAR_OUTPUT` détectée** : `instFB.Ready := ...` → ERROR (sauf baseline connue)

### 3. Bundle fraîcheur (`check-bundle-freshness`)
- Régénère le bundle dans un répertoire temporaire avec le même timestamp
- Compare binaire vs `CODE/CODE_Bundle.xml` versionné
- Échoue si diff → bundle périmé

### 4. PyTest (générateur)
- 306 tests : unitaires, intégration, golden files
- Doit passer avant tout commit

### 5. Compilation CODESYS (`check-codesys-compile`)
- Parse le log `build.log` exporté depuis CODESYS
- Patterns détectés : `[ERREUR]`, `Cxxxx:`, `Error N`
- `--strict` = warnings = erreurs

### 6. Pre-edit gate (`pre-edit-gate`)
- État persistant dans `.pi/spec_read_state.json`
- `--mark-read` : marque une spec comme lue
- `--check` : bloque si specs requises non lues pour le fichier cible

---

## Skills Pi Coding Agent (dans `skills/`)

| Skill | Rôle |
|---|---|
| `codesys-change` | Modification CODE/ : lecture specs, plan, gates, bundle, validation humaine |
| `codesys-review` | Revue read-only CODE/DOC/tests |
| `doc-sync` | Maj DOC après modification CODE |
| `release-check` | Checklist fin de tâche avant intégration manuelle |
| `requirement-intake` | Qualification `NEW_INFORMATION` avant tout code |

Chargement auto dans Pi via `package.json` → `pi.skills`.

---

## Policies (dans `docs/`)

| Fichier | Sujet |
|---|---|
| `SAFETY_POLICY.md` | Interdiction Ponytail safety, validation humaine obligatoire, `humanValidationRequired` |
| `WORKFLOW.md` | Flux `CODE_CHANGE` / `NEW_INFORMATION`, criticité C0–C4 |
| `TOKEN_POLICY.md` | Gestion budget tokens, context window, compression |
| `DOC_WRITING_POLICY.md` | Style docs projet (concision, emoji, versioning) |
| `CODE_WRITING_POLICY.md` | Style ST (headers, naming, contrats FB, sécurité) |
| `INTEGRATIONS.md` | Pi Subagents (défaut), Herdr secours, Ponytail, config, modes |
| `RELEASE_PROCESS.md` | Checklist fin de tâche |
| `STRUCTURE_AND_CLEANUP.md` | Arborescence, archivage, nettoyage |

---

## Templates (dans `templates/`)

| Template | Usage |
|---|---|
| `fb_header.st` | En-tête standard Function Block |
| `motion_fb_header.st` | En-tête FB de mouvement (StartStop/SafeStop) |
| `program_header.st` | En-tête PRG |
| `gvl_header.st` | En-tête GVL |
| `type_header.st` | En-tête TYPE/STRUCT/ENUM |
| `af_spec.md` | Spécification fonctionnelle (AF_Partie-N) |
| `requirement_intake.md` | Fiche qualification nouvelle info |
| `validation_checklist.md` | Checklist validation humaine |
| `project_tracking.md` | Suivi tâche (PLAN_TASK) |
| `tool_readme.md` | README standard pour outil |

---

## Schémas JSON (dans `schemas/`)

| Schema | Validation |
|---|---|
| `herdr_review.schema.json` | Rapports Herdr : `humanValidationRequired: true`, `validationStatus: advisory-only \| human-validated` |
| `requirement_intake.schema.json` | Entrée `NEW_INFORMATION` : id, source, TBD, décision humaine obligatoire |

---

## Exécution des tests internes

```powershell
python -m pytest TOOLS/AGENT_WORKFLOW/scripts/ -v
```

Tests : structure, style, bundle, pre-edit gate, compile check.

---

## Intégration Pi Coding Agent

1. Installer le package : `pip install -e TOOLS/AGENT_WORKFLOW`
2. Dans Pi : `pi package add TOOLS/AGENT_WORKFLOW` (ou via `package.json` déjà présent)
3. Skills auto-disponibles : `codesys-change`, `codesys-review`, `herdr-review`, `doc-sync`, `release-check`, `requirement-intake`

---

## Variables d'environnement utiles

| Variable | Défaut | Rôle |
|---|---|---|
| `AGENT_WORKFLOW_PROJECT_ROOT` | CWD | Racine projet (pour chemins relatifs) |
| `PYTEST_ADDOPTS` | `-q` | Options pytest par défaut |

---

## Versioning & Changelog

- Version dans `pyproject.toml`
- Historique dans `DOC/VERSION_HISTORY.md`
- Tags git : `tools/agent-workflow/vX.Y.Z`
