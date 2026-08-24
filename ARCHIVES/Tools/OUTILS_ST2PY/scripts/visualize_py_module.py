#!/usr/bin/env python3
"""
AST Parser & Diagram Generator for ST2PY Generated Modules.
Parses generated Python files (RESULTS/<DOMAINE>/modules/*.py) using `ast`, extracts Class
structure, Inputs, Outputs, FSM States, and generates UML & State Machine diagrams.

Les diagrammes atterrissent à côté des autres résultats de test du même domaine
(RESULTS/<DOMAINE>/chronicles/), pas dans un dossier séparé : un rapport de test et
son diagramme se lisent ensemble (REX 2026-08).
"""

import argparse
import ast
import re
import sys
from pathlib import Path

ST2PY_DIR = Path(__file__).resolve().parents[1]
TOOLS_DIR = ST2PY_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))
sys.path.insert(0, str(ST2PY_DIR / "core"))
from visualize_workflow import render_puml
from results_layout import RESULTS_DIR, iter_module_files


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

    steps_found = sorted(set(re.findall(r"self\._step\s*==\s*(\d+)", code)))
    info["fsm_states"] = [int(s) for s in steps_found]

    return info


def generate_uml_puml(info: dict) -> str:
    """Generate PlantUML Class & Composition Diagram for the parsed module, including DUTs & Sub-FBs."""
    class_name = info["class_name"]

    # Traitement spécial pour FB_Safety_EmergencyManagement (diagramme d'architecture composite complet)
    if class_name == "FB_Safety_EmergencyManagement":
        return """@startuml
scale max 3800x3800
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam classHeaderBackgroundColor #E1BEE7

title Architecture, Composition & DUT — FB_Safety_EmergencyManagement (Domaine AU)

package "Données Structurées (DUT)" #F5F5F5 {
    class ST_Safety_Emergency_InternalCmd << (S,#1976D2) STRUCT >> {
        + MaintainA_Cmd : BOOL
        + MaintainB_Cmd : BOOL
        + ArmPulse_Cmd : BOOL
    }

    class ST_Safety_Emergency_State << (S,#2E7D32) STRUCT >> {
        + ChainOk : BOOL
        + ContactorOk : BOOL
        + Step : INT
        + Armable : BOOL
        + ArmingBusy : BOOL
    }

    class ST_Safety_Emergency_Diag << (S,#C62828) STRUCT >> {
        + Error : BOOL
        + ErrorId : WORD
        + RedundancyTestFailed : BOOL
        + ArmFailed : BOOL
        + LockoutActive : BOOL
    }
}

package "Bloc Composite AU (CODE/AU)" #FAFAFA {
    class FB_Safety_EmergencyManagement << (C,#7B1FA2) Composite Parent >> {
        .. Entrées (VAR_INPUT) ..
        + Enable : BOOL
        + Reset : BOOL
        + ArmRequest : BOOL
        + EmergencyChainClosed : BOOL
        + PowerContactorEngaged : BOOL
        + PowerCutOffRequest : BOOL
        + BtnEmergencyCutOff : BOOL
        .. Sorties (VAR_OUTPUT) ..
        + Ready : BOOL
        + Busy : BOOL
        + Done : BOOL
        + Error : BOOL
        + ErrorId : WORD
        + MaintainA_RQ : BOOL
        + MaintainB_RQ : BOOL
        + ArmPulse_RQ : BOOL
        + State : ST_Safety_Emergency_State
        + Diag : ST_Safety_Emergency_Diag
    }

    class FB_Safety_EmergencyManagementLogic << (C,#D81B60) Décision & FSM >> {
        + Enable : BOOL
        + Reset : BOOL
        + ArmRequest : BOOL
        + EmergencyChainClosed : BOOL
        + PowerContactorEngaged : BOOL
        + PowerCutOffRequest : BOOL
        + BtnEmergencyCutOff : BOOL
        --
        + Cmd : ST_Safety_Emergency_InternalCmd
        + ArmingSeqStep : INT
        + RedundancyTestFailed : BOOL
        + EmergencyArmingFailed : BOOL
        + EmergencyArmingLockoutActive : BOOL
        + Armable : BOOL
        + ArmingBusy : BOOL
        + StartupFail : BOOL
    }

    class FB_Safety_EmergencyManagementOutput << (C,#00897B) Pilote Physique >> {
        + Enable : BOOL
        + Cmd : ST_Safety_Emergency_InternalCmd
        + ChainOk : BOOL
        + ContactorOk : BOOL
        + ArmingStep : INT
        + Armable : BOOL
        + ArmingBusy : BOOL
        + Error : BOOL
        + ErrorId : WORD
        --
        + MaintainA_RQ : BOOL
        + MaintainB_RQ : BOOL
        + ArmPulse_RQ : BOOL
        + State : ST_Safety_Emergency_State
        + Diag : ST_Safety_Emergency_Diag
    }
}

package "Écosystème & Interconnexions AU" #F0F4C3 {
    class PRG_AU_Acquisition_CFC << (P,#78909C) CFC Acquisition >>
    class FB_Sim_AU_ChainFeedback << (C,#FB8C00) Simulation Feedback >>
    class PRG_AU_Outputs_LD << (P,#78909C) LD Sorties Scalaires >>
    class PRG_09_Supervision << (P,#5C6BC0) Supervision IHM >>
}

FB_Safety_EmergencyManagement *-- FB_Safety_EmergencyManagementLogic : "Logic (Instance Privée)"
FB_Safety_EmergencyManagement *-- FB_Safety_EmergencyManagementOutput : "Output (Instance Privée)"

FB_Safety_EmergencyManagementLogic --> ST_Safety_Emergency_InternalCmd : "produit Cmd"
FB_Safety_EmergencyManagementOutput --> ST_Safety_Emergency_InternalCmd : "consomme Cmd"
FB_Safety_EmergencyManagementOutput --> ST_Safety_Emergency_State : "produit State"
FB_Safety_EmergencyManagementOutput --> ST_Safety_Emergency_Diag : "produit Diag"

PRG_AU_Acquisition_CFC --> FB_Safety_EmergencyManagement : "EmergencyChainClosed, PowerContactorEngaged"
FB_Safety_EmergencyManagement --> PRG_AU_Outputs_LD : "MaintainA/B_RQ, ArmPulse_RQ, scalaires"
FB_Safety_EmergencyManagement --> PRG_09_Supervision : "State, Diag"
FB_Sim_AU_ChainFeedback <--> FB_Safety_EmergencyManagement : "Boucle simulation A/B"

legend bottom
  |= Objet |= Rôle dans le domaine AU |
  | `FB_Safety_EmergencyManagement` | Composite parent encapsulant Logic & Output |
  | `FB_Safety_EmergencyManagementLogic` | Machine d'état (steps 0..6, autotest, Cause/Ack) |
  | `FB_Safety_EmergencyManagementOutput` | Pilote physique & génération des bus d'état/diag |
  | `ST_*` | Structures DUT véhiculant les consignes & états publics |
endlegend

@enduml"""

    # Traitement spécial pour FB_Safety_Translation / FB_Translation
    if class_name in ["FB_Translation", "FB_Safety_Translation"]:
        return """@startuml
scale max 3800x3800
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam classHeaderBackgroundColor #B2EBF2

title Architecture & Interconnexions — Domaine Translation (CODE/TRANSLATION)

package "Données Structurées & DÉCODEUR" #F5F5F5 {
    class FB_Translation_PositionDecoder << (C,#00ACC1) Décodeur Capteurs >> {
        + SensorsMask : WORD
        --
        + RawPosition : INT
        + IncoherentMask : BOOL
        + ForwardAllowed : BOOL
        + ReverseAllowed : BOOL
    }

    class ST_TranslationHMI << (S,#1976D2) STRUCT >> {
        + SpeedRefPct : REAL
        + Direction : INT
        + ManualCmd : BOOL
    }
}

package "Sécurité & Pilotage Translation" #FAFAFA {
    class FB_Safety_Translation << (C,#D32F2F) Sécurité Translation >> {
        + Enable : BOOL
        + SafeStop : BOOL
        + Reset : BOOL
        --
        + Error : BOOL
        + ErrorId : WORD
        + DriveControlWord : WORD
    }

    class FB_Translation << (C,#0288D1) Commande Translation >> {
        + Enable : BOOL
        + StartStop : BOOL
        + SpeedRefPct : REAL
        + Direction : INT
        --
        + Active : BOOL
        + SpeedOutPct : REAL
        + Done : BOOL
    }

    class FB_Brake << (C,#7CB342) Frein >> {
        + Release : BOOL
        --
        + Engaged : BOOL
    }

    class FB_Ramp << (C,#7CB342) Rampe Accél/Décél >> {
        + Target : REAL
        --
        + Current : REAL
    }
}

FB_Translation --> FB_Translation_PositionDecoder : "consomme détection position"
FB_Safety_Translation --> FB_Translation : "verrouille en cas de SafeStop/Erreur"
FB_Translation *-- FB_Brake : "pilote Frein"
FB_Translation *-- FB_Ramp : "applique Rampe Vitesse"
FB_Translation --> ST_TranslationHMI : "échange consigne IHM"

@enduml"""

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

title Diagramme de Classe UML — {class_name} (Module Python Généré)

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
  | `RESULTS/<DOMAINE>/modules/{class_name}.py` | Modèle Python autonome généré depuis le bundle XML |
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

title Diagramme d'Etats FSM — {class_name} [Steps 0 a 6]

[*] --> Step0 : Boot / Enable=TRUE

state Step0 #E8F5E9
Step0 : Step 0 IDLE — Attente ArmRequest
Step0 : MaintainA_RQ=TRUE, MaintainB_RQ=TRUE

state Step1 #FFF3E0
Step1 : Step 1 TestA — MaintainA_RQ=FALSE [200ms]
Step1 : Test ouverture canal A

state Step2 #E3F2FD
Step2 : Step 2 RestoreA — MaintainA_RQ=TRUE [200ms]
Step2 : Attente refermeture boucle

state Step3 #FFF3E0
Step3 : Step 3 TestB — MaintainB_RQ=FALSE [200ms]
Step3 : Test ouverture canal B

state Step4 #E3F2FD
Step4 : Step 4 RestoreB — MaintainB_RQ=TRUE [200ms]
Step4 : Attente refermeture boucle

state Step5 #FFE0B2
Step5 : Step 5 Pulse — ArmPulse_RQ=TRUE [1000ms]
Step5 : Impulsion réarmement contacteur

state Step6 #FFF9C4
Step6 : Step 6 Confirm — Attente PowerContactorEngaged [2000ms max]

state FailRedundancy #FFCDD2
FailRedundancy : ÉCHEC REDONDANCE — RedundancyTestFailed=TRUE
FailRedundancy : Canal A ou B resté collé

state FailConfirm #FFCDD2
FailConfirm : ÉCHEC CONFIRMATION — EmergencyArmingFailed=TRUE
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
FailConfirm --> Step0 : Reset + ArmRequest

@enduml"""


def process_module(py_path: Path, out_dir: Path) -> bool:
    """Génère les diagrammes UML (+ FSM si applicable) pour UN module Python."""
    print(f"Analyse AST du module Python: {py_path.name}...")
    info = parse_module_ast(py_path)

    if not info["class_name"]:
        print(f"   (aucune classe trouvée dans {py_path.name} — artefact neutralisé/vide, ignoré)")
        return False

    # 1. Diagramme UML Classe + Composition + DUT + Interconnexions
    uml_puml = generate_uml_puml(info)
    uml_png = out_dir / f"DIAG_PY_UML_{info['class_name']}.png"
    render_puml(uml_puml, uml_png, output_format="png")
    print(f"OK : {uml_png}")

    # 2. Diagramme d'États FSM
    if info["fsm_states"]:
        fsm_puml = generate_fsm_puml(info)
        fsm_png = out_dir / f"DIAG_PY_FSM_{info['class_name']}.png"
        render_puml(fsm_puml, fsm_png, output_format="png")
        print(f"OK : {fsm_png}")
    else:
        print(f"   (pas de machine d'état détectée dans {py_path.name}, FSM ignoré)")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Génère les diagrammes UML/FSM des modules générés, "
                    "dans RESULTS/<DOMAINE>/chronicles/ (à côté des rapports de test)."
    )
    parser.add_argument(
        "module", nargs="?", default=None,
        help="Nom du module (ex: FB_Safety_EmergencyManagement). "
             "Omis = TOUS les modules de RESULTS/*/modules/."
    )
    args = parser.parse_args()

    targets = iter_module_files()
    if args.module:
        targets = [t for t in targets if t[1].stem == args.module]
        if not targets:
            print(f"Module introuvable dans RESULTS/*/modules/ : {args.module}", file=sys.stderr)
            return 1

    if not targets:
        print(f"Aucun module Python trouvé dans {RESULTS_DIR}", file=sys.stderr)
        return 1

    had_error = False
    for domain, py_path in targets:
        out_dir = RESULTS_DIR / domain / "chronicles"
        out_dir.mkdir(parents=True, exist_ok=True)
        if not py_path.exists():
            print(f"Fichier introuvable: {py_path}", file=sys.stderr)
            had_error = True
            continue
        if not process_module(py_path, out_dir):
            continue

    return 1 if had_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
