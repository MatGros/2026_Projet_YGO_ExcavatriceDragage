#!/usr/bin/env python3
"""Generate high-fidelity architecture map for Codeurs & Homing (FB_Encoder_Abs)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml CodeursHoming_HiFi
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

title <img:open-iconic/graph> Architecture, Traitement & Recalage Homing Codeurs EtherCAT (FB_Encoder_Abs)

package "1. <img:open-iconic/input> BUS ETHERCAT (4ms)" as PKG_ECAT #E3F2FD {
  rectangle "<img:open-iconic/input>\nCODEURS ABSOLUS (COD1 / COD2)\n---\n• RawEncoderValue : DWORD (32 bits)\n• StatusWord : WORD\n• FB_DiagEthercat (.Online / .Operational)" as ECAT #BBDEFB
}

package "2. <img:open-iconic/graph> TRAITEMENT INTERNE FB_ENCODER_ABS" as PKG_ENC #E8F5E9 {
  rectangle "<img:open-iconic/graph>\nSCALING & CONVERSION\n---\n• Impulsions ➔ Position en Mètres (m)\n• Ratio réducteur / Diamètre tambour\n• Débordement 32 bits (Rollover auto)" as SCALE #C8E6C9
  rectangle "<img:open-iconic/target>\nHOMING & RECALAGE\n---\n• HomingReq (Appui IHM / Maintenance N2)\n• Recalage automatique au capteur haut\n• Preset Position mémorisé" as HOMING #C8E6C9
  rectangle "<img:open-iconic/shield>\nSURVEILLANCE VITESSE\n---\n• Vitesse instantanée (m/s)\n• Vitesse excessive / Perte de signal" as SPEED #C8E6C9
}

package "3. <img:open-iconic/external-link> POSITIONS CONVERTIES & SUPERVISION" as PKG_OUT #FFF3E0 {
  rectangle "<img:open-iconic/cog>\nMODULES APPLICATIFS CONSOMMATEURS\n---\n• PRG_06_WinchControl (Treuils M1/M2)\n• PRG_05_Cycle (Séquenceur auto)\n• FB_Bucket (Contrôle Benne M2)" as OUT #FFE0B2
  rectangle "<img:open-iconic/monitor>\nSUPERVISION IHM\n---\n• GVL_IHM.EncoderM1 / EncoderM2\n• Position_M : REAL\n• Speed_Ms : REAL\n• IsHomed : BOOL" as HMI #F8BBD0
}

ECAT --> SCALE : RawValue (32 bits)
SCALE --> HOMING : Position brute calculée
HOMING --> SPEED : Position calée (m)

SPEED --> OUT : PosM1 / PosM2 (m)
SPEED --> HMI : Mesures pour IHM

note bottom of HOMING
  <img:open-iconic/target> **Procédure de Homing** :
  • Fixe l'origine (0.0 m) sur passage du capteur de position haute physique ou via commande IHM.
  • Maintient l'indicateur `IsHomed = TRUE` tant qu'aucun défaut codeur n'est détecté.
end note

note bottom of SPEED
  <img:open-iconic/shield> **Sécurité Codeur** :
  • Si la vitesse mesurée dépasse la limite physique du tambour ➔ Passage immédiat en <img:open-iconic/warning> **Error**.
end note

footer Document source : AF_Partie-10 & FB_Encoder_Abs
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_Codeurs_HiFi.png"

    print("Génération du diagramme Codeurs & Homing...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
