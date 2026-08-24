#!/usr/bin/env python3
"""Generate the explanatory diagram for TOOLS/DIAGRAM_GENERATORS/generate_all.py."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = """@startuml Tool_DiagramGenerators
skinparam backgroundColor #FFFFFF
skinparam shadowing true
skinparam roundcorner 5
skinparam fontname "Consolas, Segoe UI, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #455A64
skinparam nodesep 40
skinparam ranksep 50
left to right direction

title Outil - DIAGRAM_GENERATORS (Orchestrateur & Moteur Anti-Crop)

package "<$list> Orchestrateur Principal" #E3F2FD {
  rectangle "generate_all.py\\nExecuteur master" as MASTER #BBDEFB
}

package "<$cogs> Generateurs de Diagrammes" #E8F5E9 {
  rectangle "visualize_workflow.py\\nWorkflow de dev" as G1 #C8E6C9
  rectangle "generate_af_map.py\\nAnalyses Fonctionnelles" as G2 #C8E6C9
  rectangle "generate_single_hifi.py\\nVue Mere Translation M3" as G3 #C8E6C9
  rectangle "generate_code_map.py\\nVues Detaillees M3" as G4 #C8E6C9
  rectangle "generate_treuils_map.py\\nTreuils M1/M2" as G5 #C8E6C9
  rectangle "generate_benne_map.py\\nBenne M2" as G6 #C8E6C9
  rectangle "generate_joystick_map.py\\nJoystick CAN" as G7 #C8E6C9
  rectangle "generate_encoder_map.py\\nCodeurs EtherCAT" as G8 #C8E6C9
  rectangle "generate_safety_map.py\\nSecurite & AU" as G9 #C8E6C9
  rectangle "generate_tool_*.py\\nOutils Projet" as G10 #C8E6C9
}

package "<$shield> Moteur Anti-Crop & Validation PNG" #FFF3E0 {
  rectangle "render_puml()\\nInjection scale max 3800x3800\\nCheck PNG dimensions < 4096px" as RENDER #FFE0B2
}

package "<$image> Rendus DOC/DIAGRAMS/*.png" #F8BBD0 {
  rectangle "ANALYSES_FONCTIONNELLES/" as OUT1 #F48FB1
  rectangle "CODE/" as OUT2 #F48FB1
  rectangle "TOOLS/" as OUT3 #F48FB1
}

MASTER --> G1
MASTER --> G2
MASTER --> G3
MASTER --> G4
MASTER --> G5
MASTER --> G6
MASTER --> G7
MASTER --> G8
MASTER --> G9
MASTER --> G10

G1 --> RENDER
G2 --> RENDER
G3 --> RENDER
G4 --> RENDER
G5 --> RENDER
G6 --> RENDER
G7 --> RENDER
G8 --> RENDER
G9 --> RENDER
G10 --> RENDER

RENDER --> OUT1
RENDER --> OUT2
RENDER --> OUT3

footer Document source : TOOLS/DIAGRAM_GENERATORS/generate_all.py
@enduml"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "TOOLS"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_TOOL_DiagramGenerators.png"

    print("Generation diagramme DIAGRAM_GENERATORS...")
    ok = render_puml(PUML, output)
    sys.exit(0 if ok else 1)
