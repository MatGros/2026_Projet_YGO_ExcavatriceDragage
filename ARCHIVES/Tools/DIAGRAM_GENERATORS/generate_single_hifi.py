#!/usr/bin/env python3
"""Generate the parent overview for the Translation M3 detailed maps."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml TranslationM3_HiFi
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

title <img:open-iconic/media-play> Translation M3 — Vue Mère des Flux Fonctionnels & Architecture

rectangle "<img:open-iconic/input>\nACQUISITION & DECODAGE\n---\n• PRG_00_Inputs\n• FB_Translation_PositionDecoder (5 bits)" as ACQ #E3F2FD

rectangle "<img:open-iconic/wrench>\nDIAGNOSTICS BUS\n---\n• PRG_01_Diagnostics\n• Bus CANopen + Bus EtherCAT" as DIAG #ECEFF1

rectangle "<img:open-iconic/shield>\nSÉCURITÉ MÉTIER\n---\n• PRG_03_Safety\n• instSafetyTranslationM3" as SAFE #FFCDD2

rectangle "<img:open-iconic/cog>\nARBITRAGE & MOUVEMENT\n---\n• PRG_07_TranslationControl\n• instTranslationM3 (FB_Translation)" as MOVE #E8F5E9

rectangle "<img:open-iconic/external-link>\nSORTIES PHYSIQUES\n---\n• PRG_10_Outputs\n• Variateur AC600 + Frein + Relais A/B" as OUT #FFF3E0

rectangle "<img:open-iconic/monitor>\nSUPERVISION IHM\n---\n• PRG_09_Supervision\n• GVL_IHM.TranslationM3" as HMI #F8BBD0

ACQ --> SAFE : Positions, frein, AU,\nétat et fréquence AC600
DIAG --> SAFE : États CANopen / EtherCAT
ACQ --> MOVE : Positions + retours AC600
DIAG --> MOVE : Consignes Joystick
SAFE --> MOVE : SafeStop M3
MOVE --> SAFE : Direction + BrakeCmd
MOVE --> OUT : DriveControlWord\nDriveFreqRefHz + BrakeCmd
SAFE --> OUT : PowerCutOff M3 (1oo2)
ACQ --> HMI : Mesures conditionnées
SAFE --> HMI : Diagnostics sécurité
MOVE --> HMI : État et commande effective

note bottom of SAFE
  <img:open-iconic/shield> **Sécurité Métier Translation** :
  • SafeStop est propre au métier Translation (rampe rapide).
  • PowerCutOff rejoint la coupure générale redondante A/B (1oo2).
end note

legend bottom
  |= Vues Détaillées |= Contenu Spécifique & Pictogrammes |
  | Vue 1 | Acquisition <img:open-iconic/input>, Décodage 5 bits <img:open-iconic/magnifying-glass>, Sécurité <img:open-iconic/shield> & Bitfield ErrorId <img:open-iconic/warning> |
  | Vue 2 | Sources de commande <img:open-iconic/dial>, Arbitrage <img:open-iconic/cog>, Rampes <img:open-iconic/graph> & PDO AC600 <img:open-iconic/cogs> |
  | Vue 3 | Sorties physiques <img:open-iconic/external-link> & Mapping exhaustif IHM <img:open-iconic/monitor> |
endlegend

footer Vue mère Translation M3 — Consulter les vues 1 à 3 pour le détail des flux
@enduml"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_TranslationM3_HiFi.png"
    print("Génération de la vue mère Translation M3...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
