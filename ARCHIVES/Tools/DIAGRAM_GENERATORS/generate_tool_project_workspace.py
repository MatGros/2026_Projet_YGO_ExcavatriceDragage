#!/usr/bin/env python3
"""Generate the explanatory workspace diagram for TOOLS/PROJECT_WORKSPACE."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = """@startuml Tool_ProjectWorkspace
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundcorner 5
skinparam fontname "Consolas, Segoe UI, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #455A64
skinparam nodesep 35
skinparam ranksep 45
left to right direction

title Outil - PROJECT_WORKSPACE (.vscode/terminals.json & launch_workspace.py)

package "<$monitor> Terminaux Pre-configures (VS Code / CLI)" #E3F2FD {
  rectangle "Terminal 1 : OpenCode Multi-Agent\\nopencode --agent orchestrateur" as T1 #BBDEFB
}

package "<$cogs> Agent Orchestrateur OpenCode" #FFF3E0 {
  rectangle "Agent : Orchestrateur\\n.opencode/agent/orchestrateur.md" as AG1 #FFE0B2
  rectangle "Agent : Codeur ST\\n.opencode/agent/codeur.md" as AG2 #FFE0B2
  rectangle "Agent : Verificateur\\n.opencode/agent/verificateur.md" as AG3 #FFE0B2
}

package "<$circle-check> Script d'initialisation" #E8F5E9 {
  rectangle "launch_workspace.py\\nGenerateur .vscode/terminals.json" as SCRIPT #C8E6C9
}

T1 --> AG1 : Mode all (délégation)
AG1 --> AG2 : Mission codage ST
AG1 --> AG3 : Inspection & Gates
SCRIPT --> T1 : Genere la config automatisee

footer Document source : TOOLS/PROJECT_WORKSPACE/README.md
@enduml"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "TOOLS"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_TOOL_ProjectWorkspace.png"

    print("Generation diagramme PROJECT_WORKSPACE...")
    ok = render_puml(PUML, output)
    sys.exit(0 if ok else 1)
