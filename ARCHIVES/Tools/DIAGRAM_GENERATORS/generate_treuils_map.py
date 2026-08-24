#!/usr/bin/env python3
"""Generate high-fidelity architecture map for Treuils M1/M2 (FB_Winch, FB_WinchSync, FB_SpeedStep)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml TreuilsM1M2_HiFi
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

title <img:open-iconic/cog> Architecture, Synchronisation & Garde-fous Treuils M1/M2 (Retenue & Benne)

package "1. <img:open-iconic/input> ACQUISITION & CAPTEURS" as PKG_IN #E3F2FD {
  rectangle "<img:open-iconic/graph>\nCODEURS ABSOLUS (4ms)\n---\n• COD1 : PosM1 Retenue (m)\n• COD2 : PosM2 Benne (m)\n• FB_Encoder_Abs" as COD #BBDEFB
  rectangle "<img:open-iconic/warning>\nENTRÉES TOR & SÉCURITÉ\n---\n• Fin de course haut / bas\n• Mou de câble (M1/M2)\n• Thermique moteur (M1/M2)" as SENS #BBDEFB
}

package "2. <img:open-iconic/cog> PILOTAGE & SYNCHRONISATION" as PKG_CTRL #E8F5E9 {
  rectangle "<img:open-iconic/cog>\nM1 : RETENUE (FB_Winch)\n---\n• Enable / Reset / EmergencyStopOk\n• StartStop / SafeStop\n• SpeedStep (Masque 4 bits)\n• RampDecelNormal / Fast" as W1 #C8E6C9
  rectangle "<img:open-iconic/cog>\nM2 : BENNE (FB_Winch)\n---\n• Enable / Reset / EmergencyStopOk\n• StartStop / SafeStop\n• SpeedStep (Masque 4 bits)\n• RampDecelNormal / Fast" as W2 #C8E6C9
  rectangle "<img:open-iconic/transfer>\nSYNCHRO : FB_WinchSync\n---\n• Calcul Écart M1 - M2\n• Factorisation Vitesse (%)\n• Alerte désynchronisation" as SYNC #DCEDC8
}

package "3. <img:open-iconic/shield> SÉCURITÉ MÉTIER (GARDE-FOUS A-E)" as PKG_SAFE #FFCDD2 {
  rectangle "<img:open-iconic/shield>\nFB_Safety_Winch\n---\n• Méca A : Roue libre (>0.5 Hz / >1 s)\n• Méca B : Pilotage sans cmd (>3 s)\n• Méca C : Glissement benne M1/M2\n• Méca D : Capteur haut physique\n• Méca E : Écart synchro > max" as SAFE #FFEBEE
}

package "4. <img:open-iconic/external-link> SORTIES VARIATEURS & SUPERVISION" as PKG_OUT #FFF3E0 {
  rectangle "<img:open-iconic/external-link>\nCONSIGNES VARIATEURS\n---\n• SpeedRefPct M1 / M2 (%)\n• BrakeCmd M1 / M2 (TOR)\n• PowerCutOff M1 / M2" as OUT #FFE0B2
  rectangle "<img:open-iconic/monitor>\nSUPERVISION IHM\n---\n• GVL_IHM.WinchM1 / WinchM2\n• EcartSynchroM : REAL\n• Bitfield ErrorId (16 bits)" as HMI #F8BBD0
}

COD --> W1 : PosM1 (m)
COD --> W2 : PosM2 (m)
SENS --> SAFE : Mou câble & Thermique
W1 --> SYNC : Consigne & Pos M1
W2 --> SYNC : Consigne & Pos M2
SYNC --> W1 : Correction % M1
SYNC --> W2 : Correction % M2

SAFE --> W1 : SafeStop M1
SAFE --> W2 : SafeStop M2

W1 --> OUT : Consigne M1
W2 --> OUT : Consigne M2

W1 --> HMI : Statut M1
W2 --> HMI : Statut M2
SYNC --> HMI : Écart Synchro

note bottom of SYNC
  <img:open-iconic/transfer> **Régulation de Synchro** :
  • Maintient l'alignement mécanique entre le treuil de retenue (M1) et le treuil de benne (M2).
  • Ajuste dynamiquement le facteur de vitesse sur le treuil suiveur.
end note

note bottom of SAFE
  <img:open-iconic/shield> **Garde-fous Mécaniques A à E** :
  • Défaut critique ➔ <img:open-iconic/media-stop> **SafeStop** (rampe rapide) + <img:open-iconic/bolt> **PowerCutOff** (coupure puissance 1oo2).
  • Nécessite la disparition de la cause + front montant sur le bouton **Reset**.
end note

footer Document source : AF_Partie-09 & FB_Winch / FB_WinchSync
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_Treuils_HiFi.png"

    print("Génération du diagramme Treuils M1/M2...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
