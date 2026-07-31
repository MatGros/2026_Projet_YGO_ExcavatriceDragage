#!/usr/bin/env python3
"""
AST Parser & Diagram Generator for ST2PY Generated Modules.
Parses generated Python files (e.g. out/FB_Safety_EmergencyManagement.py) using `ast`,
extracts Class structure, Inputs, Outputs, FSM States, and generates UML & State Machine diagrams.
"""

import argparse
import ast
import re
import sys
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))
from visualize_workflow import render_puml


def parse_module_ast(py_file_path: Path) -> dict:
    """Parse a generated Python module AST to extract class details and FSM states."""
    code = py_file_path.read_text(encoding="utf-8")
    tree = ast.parse(code)

    info = {
        "module_name": py_file_path.stem,
        "class_name": "",
        "inputs": [],
        "outputs": [],
        "state_vars": [],
        "fsm_states": [],
        "fsm_transitions": [],
    }

    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            info["class_name"] = node.name
            # Look at __init__ assignments
            for stmt in node.body:
                if isinstance(stmt, ast.FunctionDef) and stmt.name == "__init__":
                    for item in stmt.body:
                        if isinstance(item, ast.AnnAssign) and isinstance(item.target, ast.Attribute):
                            attr_name = item.target.attr
                            type_name = getattr(item.annotation, "id", "object")
                            if attr_name.startswith("_"):
                                info["state_vars"].append((attr_name, type_name))
                            elif attr_name in ["Enable", "Reset", "ArmRequest", "EmergencyChainClosed",
                                              "PowerContactorEngaged", "PowerCutOffRequest", "BtnEmergencyCutOff",
                                              "StartStop", "SafeStop", "SpeedRefPct", "Direction"]:
                                info["inputs"].append((attr_name, type_name))
                            else:
                                info["outputs"].append((attr_name, type_name))

    # Extract FSM step comments or comparisons like `self._step == X` from code using regex
    steps_found = sorted(set(re.findall(r"self\._step\s*==\s*(\d+)", code)))
    info["fsm_states"] = [int(s) for s in steps_found]

    return info


def generate_uml_puml(info: dict) -> str:
    """Generate PlantUML Class Diagram for the parsed module."""
    class_name = info["class_name"]
    inputs_str = "\n".join([f"  + {name} : {tp}" for name, tp in info["inputs"]])
    outputs_str = "\n".join([f"  + {name} : {tp}" for name, tp in info["outputs"]])
    state_str = "\n".join([f"  - {name} : {tp}" for name, tp in info["state_vars"]])

    return f"""@startuml
scale max 3800x3800
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam classHeaderBackgroundColor #E1BEE7

title Diagramme de Classe UML — {class_name} (Module Python Genere)

class {class_name} << (C,#7B1FA2) POU Python >> {{
  .. Entrées (VAR_INPUT) ..
{inputs_str}

  .. Sorties (VAR_OUTPUT) ..
{outputs_str}

  .. Variables d'État Internes ..
{state_str}

  -- Méthodes --
  + __init__() : void
  + step(time_ms: float) : void
  + to_dict() : dict
  + set_inputs_from_mapping(values: dict) : void
}}

legend bottom
  |= Emplacement |= Rôle |
  | `out/{class_name}.py` | Modèle Python autonome généré depuis le bundle XML |
  | `CONTRACT` | Dictionnaire de contrat runtime (inputs/outputs/state) |
endlegend

@enduml"""


def generate_fsm_puml(info: dict) -> str:
    """Generate PlantUML State Machine Diagram for the emergency FSM."""
    class_name = info["class_name"]

    return f"""@startuml
scale max 3800x3800
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12

title Diagramme d'Etats FSM - {class_name} [Steps 0 a 6]

[*] --> Step0 : Boot / Enable=TRUE

state Step0 #E8F5E9
Step0 : Step 0 IDLE - Attente ArmRequest
Step0 : MaintainA_RQ=TRUE, MaintainB_RQ=TRUE

state Step1 #FFF3E0
Step1 : Step 1 TestA - MaintainA_RQ=FALSE [200ms]
Step1 : Test ouverture canal A

state Step2 #E3F2FD
Step2 : Step 2 RestoreA - MaintainA_RQ=TRUE [200ms]
Step2 : Attente refermeture boucle

state Step3 #FFF3E0
Step3 : Step 3 TestB - MaintainB_RQ=FALSE [200ms]
Step3 : Test ouverture canal B

state Step4 #E3F2FD
Step4 : Step 4 RestoreB - MaintainB_RQ=TRUE [200ms]
Step4 : Attente refermeture boucle

state Step5 #FFE0B2
Step5 : Step 5 Pulse - ArmPulse_RQ=TRUE [1000ms]
Step5 : Impulsion rearmement contacteur

state Step6 #FFF9C4
Step6 : Step 6 Confirm - Attente PowerContactorEngaged [2000ms max]

state FailRedundancy #FFCDD2
FailRedundancy : ECHEC REDONDANCE - RedundancyTestFailed=TRUE
FailRedundancy : Canal A ou B reste colle

state FailConfirm #FFCDD2
FailConfirm : ECHEC CONFIRMATION - ArmingFailed=TRUE
FailConfirm : LockoutActive=TRUE [5s]

Step0 --> Step1 : ArmRequest + Armable
Step1 --> Step2 : 200ms + ChainClosed=FALSE
Step1 --> FailRedundancy : 200ms + ChainClosed=TRUE

Step2 --> Step3 : 200ms + ChainClosed=TRUE
Step2 --> Step0 : 200ms + ChainClosed=FALSE

Step3 --> Step4 : 200ms + ChainClosed=FALSE
Step3 --> FailRedundancy : 200ms + ChainClosed=TRUE

Step4 --> Step5 : 200ms + ChainClosed=TRUE
Step4 --> Step0 : 200ms + ChainClosed=FALSE

Step5 --> Step6 : 1000ms elapsed
Step6 --> Step0 : PowerContactorEngaged=TRUE
Step6 --> FailConfirm : Timeout 2000ms

FailRedundancy --> Step0 : Reset (Cause disparue)
FailConfirm --> Step0 : Reset + ContactorEngaged=TRUE

@enduml"""


def process_module(py_path: Path, out_dir: Path) -> bool:
    """Génère les diagrammes UML (+ FSM si applicable) pour UN module Python.
    Retourne False si le module n'a pas de classe exploitable (ex. artefact neutralise)."""
    print(f"Analyse AST du module Python: {py_path.name}...")
    info = parse_module_ast(py_path)

    if not info["class_name"]:
        print(f"   (aucune classe trouvee dans {py_path.name} -- artefact neutralise/vide, ignore)")
        return False

    # 1. Diagramme UML Classe (toujours généré)
    uml_puml = generate_uml_puml(info)
    uml_png = out_dir / f"DIAG_PY_UML_{info['class_name']}.png"
    render_puml(uml_puml, uml_png, output_format="png")
    print(f"OK : {uml_png}")

    # 2. Diagramme d'États FSM (seulement si le module a une vraie machine d'état,
    # détectée via la présence de self._step et de comparaisons self._step == N)
    if info["fsm_states"]:
        fsm_puml = generate_fsm_puml(info)
        fsm_png = out_dir / f"DIAG_PY_FSM_{info['class_name']}.png"
        render_puml(fsm_puml, fsm_png, output_format="png")
        print(f"OK : {fsm_png}")
    else:
        print(f"   (pas de machine d'état detectee dans {py_path.name}, FSM ignore)")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Genere les diagrammes UML/FSM pour les modules Python generes dans out/modules/."
    )
    parser.add_argument(
        "module", nargs="?", default=None,
        help="Nom du module (ex: FB_Safety_EmergencyManagement). Omis = TOUS les modules de out/modules/."
    )
    args = parser.parse_args()

    modules_dir = TOOLS_DIR / "OUTILS_ST2PY" / "out" / "modules"
    out_dir = TOOLS_DIR.parent / "DOC" / "DIAGRAMS" / "TESTS"
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.module:
        targets = [modules_dir / f"{args.module}.py"]
    else:
        targets = sorted(modules_dir.glob("*.py"))

    if not targets:
        print(f"Aucun module Python trouve dans {modules_dir}", file=sys.stderr)
        return 1

    had_error = False
    for py_path in targets:
        if not py_path.exists():
            print(f"Fichier introuvable: {py_path}", file=sys.stderr)
            had_error = True
            continue
        if not process_module(py_path, out_dir):
            continue

    return 1 if had_error else 0


if __name__ == "__main__":
    main()
