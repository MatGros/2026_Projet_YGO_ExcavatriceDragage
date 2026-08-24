#!/usr/bin/env python3
"""Generate CFC diagram for the Emergency Management chain (AU)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml
scale max 3800x3800
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #37474F
skinparam ArrowThickness 2
skinparam packagePadding 15
skinparam ranksep 60
skinparam nodesep 40
left to right direction

title [CFC] Architecture et Interconnexion des Blocs - Chaine Arret d'Urgence [AU]

package "1. FRONTIERE ACQUISITION (DI)" #E3F2FD {
  rectangle ACQ #BBDEFB [
    PRG_AU_Acquisition
    --
    * Filtre anti-rebond 20ms
    * Feedback boucle AU 1-cycle
    * Qualified inputs generator
  ]
}

package "2. COMMANDES OPERATEUR IHM" #F3E5F5 {
  database IHM_CMD #E1BEE7 [
    GVL_IHM_AU.Cmd
    --
    ST_Safety_Emergency_HmiCmd
    * BtnEmergencyArming
    * BtnEmergencyCutOff
    * BtnFaultReset
  ]
}

package "3. COEURS ET COMPOSITE SAFETY" #FFCDD2 {
  rectangle COMP #EF9A9A [
    FB_Safety_EmergencyManagement
    --
    Composite Parent (Facade publique)
    Encapsulation POO Logic + Output
  ]
  rectangle LOGIC #E57373 [
    FB_Safety_EmergencyManagementLogic
    --
    Machine d'etat Steps 0..6
    Autotest boot + Redondance A/B
    VAR CONSTANT : 200ms / 1s / 2s / 5s
    Calcul Armable et ArmingBusy
  ]
  rectangle OUT_FB #E57373 [
    FB_Safety_EmergencyManagementOutput
    --
    Gate Enable + Projection Q
    Generateur des bus State et Diag
  ]
}

package "4. STRUCTURES ET BUS INTER-BLOCS (DUT)" #ECEFF1 {
  rectangle DUT_INT #CFD8DC [
    ST_Safety_Emergency_InternalCmd
    --
    DUT prive Logic -> Output
    * MaintainA_Cmd : BOOL
    * MaintainB_Cmd : BOOL
    * ArmPulse_Cmd : BOOL
  ]
  rectangle DUT_STATE #CFD8DC [
    ST_Safety_Emergency_State
    --
    Bus Etat public
    * ChainOk / ContactorOk
    * Step (0..6) / Armable / ArmingBusy
  ]
  rectangle DUT_DIAG #CFD8DC [
    ST_Safety_Emergency_Diag
    --
    Bus Diagnostic public
    * Error / ErrorId
    * RedundancyTestFailed / ArmFailed
    * LockoutActive
  ]
}

package "5. SORTIES PHYSIQUES ET VISU IHM" #E8F5E9 {
  rectangle OUT_PRG #C8E6C9 [
    PRG_AU_Outputs
    --
    Barriere finale LD (PRG_10_Outputs)
    Sorties Q + publication IHM
  ]
  database IHM_STATE #D1C4E9 [
    GVL_IHM_AU.State
    --
    ST_Safety_Emergency_HmiState
    * ChainOk / ContactorOk / Armable
    * ArmingBusy / Step / ErrorId
    * RedundancyTestFailed / ArmingFailed
  ]
  rectangle HARD_Q #A5D6A7 [
    SORTIES HARDWARE Q
    --
    * PowerKeepAlive_A_RQ (NC)
    * PowerKeepAlive_B_RQ (NC)
    * EmergencyArming_RQ (Pulse 1s)
  ]
}

IHM_CMD --> COMP : ST_Safety_Emergency_HmiCmd
ACQ --> COMP : DI qualifiees (EmergencyChainClosed, PowerContactorEngaged)

COMP --> LOGIC : Entrees qualifiees
LOGIC --> DUT_INT : MaintainA_Cmd, MaintainB_Cmd, ArmPulse_Cmd
DUT_INT --> OUT_FB : ST_Safety_Emergency_InternalCmd

OUT_FB --> DUT_STATE : State (ST_Safety_Emergency_State)
OUT_FB --> DUT_DIAG : Diag (ST_Safety_Emergency_Diag)

COMP --> OUT_PRG : Maintain_RQ, State, Diag

OUT_PRG --> HARD_Q : PowerKeepAlive_A/B_RQ, EmergencyArming_RQ
OUT_PRG --> IHM_STATE : GVL_IHM_AU.State

legend bottom
  |= Couleur |= Role dans l'architecture CFC |
  |<#E3F2FD>| Acquisition DI physiques ou simulees |
  |<#F3E5F5>| Commandes operateur IHM (ST_Safety_Emergency_HmiCmd) |
  |<#FFCDD2>| Coeur de securite FB (Facade composite parent, Logic avec VAR CONSTANT) |
  |<#ECEFF1>| Structures d'echange et Bus inter-blocs (DUT) |
  |<#E8F5E9>| Sorties physiques terminales (Q) et Retours visu IHM |
endlegend

@enduml"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    for out_dir in [project_root / "DOC" / "DIAGRAMS", project_root / "DOC" / "DIAGRAMS" / "CODE"]:
        out_dir.mkdir(parents=True, exist_ok=True)
        png = out_dir / "DIAG_EmergencyManagement_CFC.png"
        svg = out_dir / "DIAG_EmergencyManagement_CFC.svg"
        print(f"Génération diagramme {png}...")
        render_puml(PUML, png, output_format="png")
        render_puml(PUML, svg, output_format="svg")
