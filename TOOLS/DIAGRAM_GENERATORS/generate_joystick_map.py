#!/usr/bin/env python3
"""Generate high-fidelity architecture map for Joystick CAN (FB_Joystick)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml JoystickCAN_HiFi
skinparam backgroundColor #FFFFFF
skinparam shadowing false
skinparam roundcorner 8
skinparam fontname "Segoe UI, Arial, sans-serif"
skinparam fontsize 12
skinparam ArrowColor #37474F
skinparam ArrowThickness 1.5
skinparam nodesep 50
skinparam ranksep 60
skinparam packagePadding 15
left to right direction

title <img:open-iconic/dial> Architecture, Scaling, PT1 & Sécurité Homme-Mort Joystick CAN (FB_Joystick)

package "1. <img:open-iconic/input> ACQUISITION BUS CAN (20ms)" as PKG_CAN #E3F2FD {
  rectangle "<img:open-iconic/input>\nTRAME CANOPEN (JOYSTICK HALL)\n---\n• RawAxisX / RawAxisY : INT16 (-10000 à +10000)\n• RawButtonDeadman : BOOL (Bouton Homme-Mort)\n• FB_Diag_CanOpen (.Online / .Operational)" as CAN #BBDEFB
}

package "2. <img:open-iconic/dial> TRAITEMENT INTERNE FB_JOYSTICK" as PKG_JOY #E8F5E9 {
  rectangle "<img:open-iconic/target>\nFB_AxisScale\n---\n• Deadband (Zone neutre anti-drift)\n• Inversion de sens paramétrable\n• Normalisation -100.0% à +100.0%" as SCALE #C8E6C9
  rectangle "<img:open-iconic/graph>\nFB_FilterPT1\n---\n• Filtrage lissage PT1 (TimeConstantMs)\n• Élimination des secousses opérateur" as FILTER #C8E6C9
  rectangle "<img:open-iconic/shield>\nHOMME-MORT (DEADMAN)\n---\n• Verification de maintien du bouton\n• Neutralisation immédiate si relâché" as DEAD #C8E6C9
}

package "3. <img:open-iconic/external-link> CONSIGNES ARBITRÉES & SUPERVISION" as PKG_OUT #FFF3E0 {
  rectangle "<img:open-iconic/cog>\nCONSIGNES ACTIONNEURS (ST_JoystickAxisCmd)\n---\n• StartStop : BOOL (Actionné + Homme-Mort OK)\n• Direction : INT (-1 Arrière / 0 Neutre / +1 Avant)\n• SpeedRef : REAL (0.0% à 100.0%)" as OUT #FFE0B2
  rectangle "<img:open-iconic/monitor>\nSUPERVISION IHM\n---\n• GVL_IHM.JoystickJOY1\n• DeadmanArmed : BOOL\n• Error / ErrorId (Bitfield diagnostic CAN)" as HMI #F8BBD0
}

CAN --> SCALE : RawAxisX / RawAxisY
CAN --> DEAD : RawButtonDeadman
SCALE --> FILTER : Signal lissé (-100% à +100%)
FILTER --> OUT : SpeedRef (%) & Direction
DEAD --> OUT : Validation StartStop

OUT --> HMI : Transmis à PRG_09 Supervision
CAN --> HMI : Diagnostic Bus CANopen

note bottom of SCALE
  <img:open-iconic/target> **Mise à l'échelle & Deadband** :
  • Élimine les dérives du zéro au repos (deadband ~5%).
  • Produit une consigne linéaire et symétrique en %.
end note

note bottom of DEAD
  <img:open-iconic/shield> **Sécurité Homme-Mort (Deadman)** :
  • Si le bouton Homme-Mort est relâché ➔ `DeadmanArmed = FALSE`, `StartStop = FALSE`.
  • Empêche tout mouvement intempestif si l'opérateur lâche le manche.
end note

footer Document source : AF_Partie-08 & FB_Joystick
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_Joystick_HiFi.png"

    print("Génération du diagramme Joystick CAN...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
