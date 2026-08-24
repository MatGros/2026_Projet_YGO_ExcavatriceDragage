#!/usr/bin/env python3
"""Generate high-fidelity architecture map for Benne M2 (FB_Bucket)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml BenneM2_HiFi
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

title <img:open-iconic/layers> Architecture, Contrôle d'Ouverture & Séquence Benne M2 (FB_Bucket)

package "1. <img:open-iconic/input> COMMANDES & POSITIONS" as PKG_IN #E3F2FD {
  rectangle "<img:open-iconic/loop>\nSÉQUENCEUR CYCLE (PRG_05)\n---\n• CmdOpen / CmdClose : BOOL\n• TargetState : E_BucketState" as CYC #BBDEFB
  rectangle "<img:open-iconic/dial>\nPILOTAGE JOYSTICK / IHM\n---\n• Action manuelle Ouv / Ferm\n• AdjustOffsetReq : REAL (m)" as JOY #BBDEFB
  rectangle "<img:open-iconic/graph>\nCODEURS ABSOLUS\n---\n• PosM1 : Retenue (m)\n• PosM2 : Benne (m)" as COD #BBDEFB
}

package "2. <img:open-iconic/layers> FONCTION MÉTIER BENNE" as PKG_BUCKET #E8F5E9 {
  rectangle "<img:open-iconic/layers>\nFB_Bucket (PRG_06_WinchControl)\n---\n• DeltaPositionM := PosM2 - PosM1\n• State : OPEN / CLOSED / MOVING\n• OffsetOuverture (m) / OffsetFermeture (m)\n• Interlocks de mouvement" as BUCKET #C8E6C9
}

package "3. <img:open-iconic/shield> SÉCURITÉ & GARDE-FOUS BENNE" as PKG_SAFE #FFCDD2 {
  rectangle "<img:open-iconic/shield>\nGARDE-FOUS SPÉCIFIQUES\n---\n• Glissement M1 inadmissible\n• OverDeltaLimit : Écart M1-M2 hors jauge\n• Butée mécanique Ouverture / Fermeture" as SAFE #FFEBEE
}

package "4. <img:open-iconic/external-link> CONSIGNES TREUIL M2 & SUPERVISION" as PKG_OUT #FFF3E0 {
  rectangle "<img:open-iconic/cog>\nCONSIGNES TREUIL M2\n---\n• StartStop / SafeStop M2\n• Direction (Ouv = +1 / Ferm = -1)\n• SpeedRefPct (%)\n• BrakeCmd M2" as OUT #FFE0B2
  rectangle "<img:open-iconic/monitor>\nSUPERVISION IHM\n---\n• GVL_IHM.Bucket\n• State : E_BucketState\n• DeltaPositionM : REAL\n• Error / ErrorId : WORD" as HMI #F8BBD0
}

CYC --> BUCKET : Consignes de cycle
JOY --> BUCKET : Ordres manuels
COD --> BUCKET : PosM1 / PosM2 (m)

BUCKET --> SAFE : Surveillance Delta
SAFE --> BUCKET : SafeStop M2 / Defaut

BUCKET --> OUT : Consignes pilotage M2
BUCKET --> HMI : Statuts & Positions IHM

note bottom of BUCKET
  <img:open-iconic/layers> **Mécanisme d'Ouverture / Fermeture** :
  • L'ouverture/fermeture s'obtient en créant un décalage (offset) entre les positions des treuils M1 et M2.
  • Le bloc calcule en continu le `DeltaPositionM` et verrouille les consignes une fois l'offset cible atteint.
end note

note bottom of SAFE
  <img:open-iconic/shield> **Garde-fou Glissement M1** :
  • Si M1 glisse pendant une manœuvre de benne ➔ Verrouillage immédiat et passage en <img:open-iconic/warning> **Error**.
end note

footer Document source : AF_Partie-11 & FB_Bucket
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_Benne_HiFi.png"

    print("Génération du diagramme Benne M2...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
