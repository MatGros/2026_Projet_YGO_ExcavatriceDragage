#!/usr/bin/env python3
"""Generate the organization and responsibility map for Functional Analyses (AF_Partie-01 to 14)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML_AF_MAP = r"""@startuml Organization_AF
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 6
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #37474F
skinparam ArrowThickness 1.5
skinparam nodesep 45
skinparam ranksep 50
skinparam packagePadding 15
left to right direction

title Carte des Analyses Fonctionnelles (AF_Partie-01 à 14)

package "1. <img:open-iconic/bolt> FONDATIONS & SOCLE" as PKG1 #E3F2FD {
  rectangle "<img:open-iconic/bolt>\nAF_Partie-01\nÉquipements & AU\n---\n• Chaîne AU matérielle\n• PowerCutOff 1oo2" as AF01 #BBDEFB
  rectangle "<img:open-iconic/cog>\nAF_Partie-02\nArchitecture PRG\n---\n• Tâches 4ms/10ms/20ms\n• Arborescence PRG/FB" as AF02 #BBDEFB
  rectangle "<img:open-iconic/shield>\nAF_Partie-03\nContrat FB Commun\n---\n• Enable > SafeStop > StartStop\n• Reset sur front" as AF03 #BBDEFB

  AF01 --> AF02
  AF02 --> AF03
}

package "2. <img:open-iconic/loop>\nSPECS TRANSVERSES" as PKG2 #FFF3E0 {
  rectangle "<img:open-iconic/loop>\nAF_Partie-04\nCycle & Séquenceur\n---\n• E_CycleStep (12 phases)\n• Synchro & Freins" as AF04 #FFE0B2
  rectangle "<img:open-iconic/wrench>\nAF_Partie-05\nModes & Maintenance\n---\n• N1/N2 & AUTO\n• Limite Légale (FB_Modes)" as AF05 #FFE0B2
  rectangle "<img:open-iconic/input>\nAF_Partie-06\nConditionnement E/S\n---\n• FB_Input_Digital\n• FB_Output_Relay" as AF06 #FFE0B2
  rectangle "<img:open-iconic/monitor>\nAF_Partie-07\nInterface IHM\n---\n• GVL_IHM & ST_*HMI\n• Supervision & Diag" as AF07 #FFE0B2

  AF05 --> AF04
  AF04 --> AF06
  AF06 --> AF07
}

package "3. <img:open-iconic/cogs>\nFONCTIONS MÉTIER ACTIONNEURS" as PKG3 #E8F5E9 {
  rectangle "<img:open-iconic/dial>\nAF_Partie-08\nJoystick CAN\n---\n• FB_Joystick (20ms)\n• Homme-Mort" as AF08 #C8E6C9
  rectangle "<img:open-iconic/graph>\nAF_Partie-10\nCodeurs EtherCAT\n---\n• FB_Encoder_Abs (4ms)\n• COD1 / COD2" as AF10 #C8E6C9
  rectangle "<img:open-iconic/cog>\nAF_Partie-09\nTreuils M1/M2\n---\n• FB_Winch & Sync\n• Garde-fous A-E" as AF09 #C8E6C9
  rectangle "<img:open-iconic/media-play>\nAF_Partie-11\nTranslation M3\n---\n• FB_Translation\n• AC600 & 5 bits" as AF11 #C8E6C9
  rectangle "<img:open-iconic/layers>\nAF_Partie-12\nBenne M2\n---\n• FB_Bucket\n• Offset ouv/ferm" as AF12 #C8E6C9
  rectangle "<img:open-iconic/bug>\nAF_Partie-13\nSimulation\n---\n• FB_Simulation\n• Granularité device" as AF13 #C8E6C9

  AF08 --> AF09
  AF10 --> AF09
  AF09 --> AF11
  AF11 --> AF12
  AF13 --> AF09
}

package "4. <img:open-iconic/circle-check>\nTESTS & VALIDATION" as PKG4 #F3E5F5 {
  rectangle "<img:open-iconic/circle-check>\nAF_Partie-14\nPLC Tests & Validation\n---\n• Scénarios TC-01 à TC-03\n• Framework in-PLC" as AF14 #E1BEE7
}

PKG1 -right-> PKG2 : Contrat FB
PKG2 -right-> PKG3 : Consignes & Modes
PKG3 -right-> PKG4 : Actionneurs & Safety

legend bottom
  |= Numérotation |= Rôle & Portée |
  | <img:open-iconic/bolt> 1 à 3 | Fondations système & contrat d'architecture FB |
  | <img:open-iconic/loop> 4 à 7 | Spécifications transverses (Cycle, Modes, E/S, IHM) |
  | <img:open-iconic/cog> 8 à 13 | Fonctions métier dédiées par composant / actionneur |
  | <img:open-iconic/circle-check> 14 | Validation sécurité & plan de tests in-PLC |
endlegend

footer Document source : AGENTS.md & DOC/AF_Partie-01 à 14
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "ANALYSES_FONCTIONNELLES"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_AF_Organisation_Responsabilites.png"

    print("Génération du diagramme d'organisation des AF (AF_Partie-01 à 14)...")
    raise SystemExit(0 if render_puml(PUML_AF_MAP, output) else 1)
