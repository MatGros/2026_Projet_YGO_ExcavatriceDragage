#!/usr/bin/env python3
"""Generate Mermaid diagram of the project workflow gates and their interactions.

Outputs:
- Mermaid diagram (stdout)
- Can be piped to file: python visualize_workflow.py > workflow.mmd
- View in VS Code (Markdown preview), GitHub, or Mermaid live editor
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


MERMAID_TEMPLATE = """```mermaid
flowchart TD
    %% ============================================================
    %% WORKFLOW GATES PIPELINE - MGS Project
    %% Generated automatically by visualize_workflow.py
    %% ============================================================

    subgraph INPUT["[IN] ENTRÉES"]
        A1[CODE_CHANGE\nModification programme/bug]
        A2[NEW_INFORMATION\nClient/chantier/essai]
    end

    subgraph REFINEMENT["[REF] REFINEMENT & PLANNING"]
        B1[Pre-edit Gate\npre_edit_gate.py\n-> Specs DOC lues ?]
        B2[Requirement Intake\nrequirement_intake skill\n-> NEW_INFORMATION qualifiee]
        B3[Scope & Criticite\nC0-C4 + Ponytail policy]
        B4[Plan d'action\nFix + Guard]
    end

    subgraph GATES["[GATE] GATES DÉTERMINISTES (run_all_gates.py)"]
        C1[Gate 1: Structure\ncheck_structure.py\n-> Arborescence CODE/]
        C2[Gate 2: Code Style\ncheck_code_style.py\n-> Tokens interdits\n-> VAR_OUTPUT writes\n-> Homme-mort (W1)\n-> FDC sans rampe (W3)\n-> DESIGN comments (W5)\n-> Refs DOC]
        C3[Gate 3: Bundle Freshness\ncheck_bundle_freshness.py\n-> Regeneration deterministe]
        C4[Gate 4: PyTest\npytest (306 tests)\n-> Generateur\n-> Tests integration\n-> Tests unitaires]
        C5[Gate 5: CODESYS Compile\ncheck_codesys_compile.py\n-> Log build -> 0 erreur]
    end

    subgraph VALIDATION["[OK] VALIDATION HUMAINE"]
        D1[Review Herdr\nRead-only, advisory-only]
        D2[Compilation CODESYS\nImport bundle + Build]
        D3[Essais Simulation\nBanc PLC_TESTS]
        D4[Validation Terrain\nFAT/SAT]
    end

    subgraph TRACEABILITY["[DOC] TRAÇABILITÉ"]
        E1[fix: correction locale]
        E2[guard: gate/template/script]
        E3[WORKFLOW.md double boucle]
        E4[VERSION_HISTORY.md]
        E5[PLAN_TASK.md]
    end

    %% Flux principal
    A1 --> B1
    A2 --> B2
    B1 --> B3
    B2 --> B3
    B3 --> B4
    B4 --> C1

    %% Gates sequentiels
    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> C5

    %% Gate 5 optionnel (si compilation dispo)
    C5 -.->|Si log dispo| D2

    %% Validation
    C5 --> D1
    D1 --> D2
    D2 --> D3
    D3 --> D4

    %% Tracabilite (double boucle)
    D4 --> E1
    D4 --> E2
    E1 --> E3
    E2 --> E3
    E3 --> E4
    E3 --> E5

    %% Feedbacks loops
    C2 -.->|ERROR| B4
    C4 -.->|FAIL| B4
    C5 -.->|Erreur Cxxxx| B4
    D2 -.->|Erreur build| B4

    %% Styles
    classDef input fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef refinement fill:#fff3e0,stroke:#ef6c00,stroke-width:2px;
    classDef gate fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef validation fill:#fce4ec,stroke:#c2185b,stroke-width:2px;
    classDef trace fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;

    class A1,A2 input;
    class B1,B2,B3,B4 refinement;
    class C1,C2,C3,C4,C5 gate;
    class D1,D2,D3,D4 validation;
    class E1,E2,E3,E4,E5 trace;

    %% Clickable links (GitHub/Markdown)
    click A1 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md" "CODE_CHANGE workflow"
    click A2 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/prompts/requirement-intake.md" "NEW_INFORMATION intake"
    click C1 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/scripts/check_structure.py" "Structure check"
    click C2 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/scripts/check_code_style.py" "Code style check"
    click C3 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/scripts/check_bundle_freshness.py" "Bundle freshness"
    click C4 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/tree/main/TOOLS/ST_PLCOPENXML_GENERATOR/tests" "PyTest suite"
    click C5 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/scripts/check_codesys_compile.py" "CODESYS compile check"
    click E3 "https://github.com/MatGros/2026_Projet_YGO_ExcavatriceDragage/blob/main/TOOLS/AGENT_WORKFLOW/docs/WORKFLOW.md" "Double-loop rule"
```


**Legende :**
- [BLUE] Bleu = Entrees
- [ORANGE] Orange = Refinement/Planning
- [GREEN] Vert = Gates deterministes (bloquants)
- [PURPLE] Rose = Validation humaine (non automatisable)
- [VIOLET] Violet = Tracabilite / Double boucle

**Fleches :**
- Pleines = flux normal
- Pointillees = optionnel / conditionnel
- Rouge pointille = boucles de retroaction (retour en arriere si echec)
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Mermaid workflow diagram")
    parser.add_argument("-o", "--output", type=Path, help="Output file (default: stdout)")
    parser.add_argument("--no-header", action="store_true", help="Omit markdown code fence")
    args = parser.parse_args()

    content = MERMAID_TEMPLATE
    if args.no_header:
        # Extract just the mermaid content
        lines = content.split('\n')
        # Remove first and last line (```mermaid and ```)
        content = '\n'.join(lines[1:-1])

    if args.output:
        args.output.write_text(content, encoding="utf-8")
        print(f"Written to {args.output}")
    else:
        print(content)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())