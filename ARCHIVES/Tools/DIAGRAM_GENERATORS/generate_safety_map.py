#!/usr/bin/env python3
"""Generate high-fidelity architecture map for Safety & Emergency Management (FB_Safety_*)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML = r"""@startuml SafetyArchitecture_HiFi
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

title <img:open-iconic/shield> Architecture Globale Sécurité, Chaîne AU & PowerCutOff Redondant (1oo2)

package "1. <img:open-iconic/bolt> CHAÎNE AU MATÉRIELLE & CAPTEURS" as PKG_HW #E3F2FD {
  rectangle "<img:open-iconic/bolt>\nMATÉRIEL & HARDWARE\n---\n• Boutons Arrêt d'Urgence (AU physiques)\n• Contrôle de Phase (PhaseRotationOk)\n• Contacteurs de puissance (FB_Output_Relay)" as HW #BBDEFB
}

package "2. <img:open-iconic/shield> BLOCS DE SÉCURITÉ APPLICATIFS" as PKG_SAFE #FFCDD2 {
  rectangle "<img:open-iconic/shield>\nFB_Safety_EmergencyManagement\n---\n• PowerCutOff_A_RQ / B_RQ (Relais redondants A/B)\n• Synchro de la chaîne AU physique" as EM #FFEBEE
  rectangle "<img:open-iconic/shield>\nFB_Safety_Winch (M1/M2)\n---\n• Mou de câble / Thermique moteur\n• Garde-fous Méca A à E (Roue libre, glissement...)\n• SafeStop M1 / M2" as SAFE_W #FFEBEE
  rectangle "<img:open-iconic/shield>\nFB_Safety_Translation (M3)\n---\n• Décodage 5 bits (Mot Incohérent)\n• Butées mécaniques extrema (Fwd/Rev)\n• SafeStop M3" as SAFE_T #FFEBEE
}

package "3. <img:open-iconic/warning> HIÉRARCHIE DE SÉCURITÉ & RÉACTION" as PKG_REACT #FFF3E0 {
  rectangle "<img:open-iconic/warning>\nHIÉRARCHIE DE SÉCURITÉ & RÉACTION\n---\n1. **SafeStop** : Rampe rapide, Enable maintenu\n2. **PowerCutOff** : Coupure de la puissance amont (1oo2)\n3. **Front Montant Reset Obligatoire** : Cause disparue + Appui Operator" as REACT #FFE0B2
}

package "4. <img:open-iconic/external-link> CONSIGNES AUTOMATE & SUPERVISION" as PKG_OUT #E8F5E9 {
  rectangle "<img:open-iconic/external-link>\nPRG_10_Outputs (PILOTAGE RELAIS)\n---\n• PowerCutOff_A_RQ / B_RQ (Relais A et B en série)\n• Variateurs Enable / SafeStop" as OUT #C8E6C9
  rectangle "<img:open-iconic/monitor>\nGVL_IHM.Safety\n---\n• SafetyErrorId (Bitfield 16 bits)\n• Diagnostic précis de la cause d'arrêt" as HMI #F8BBD0
}

HW --> EM : EmergencyStopOk
HW --> SAFE_W : Thermique / Mou de câble
HW --> SAFE_T : Signal Capteurs TOR 5 bits

EM --> REACT : PowerCutOff Global
SAFE_W --> REACT : SafeStop M1/M2
SAFE_T --> REACT : SafeStop M3

REACT --> OUT : Commandes Relais A/B
REACT --> HMI : ErrorId & Statuts IHM

note bottom of EM
  <img:open-iconic/bolt> **Architecture de coupure 1oo2** :
  • `PowerCutOff` pilote deux relais physiques A et B câblés en série.
  • Si un contacteur reste collé, le second relais interrompt la puissance amont.
end note

note bottom of REACT
  <img:open-iconic/reload> **Exigence de Réarmement (Reset)** :
  • Aucun redémarrage automatique n'est autorisé après l'apparition d'un défaut.
  • L'opérateur doit obligatoirement acquitter via un **front montant sur Reset** une fois la cause éliminée.
end note

footer Document source : AF_Partie-01, AF_Partie-03, FB_Safety_*
@enduml
"""

if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)
    output = out_dir / "DIAG_CODE_Safety_HiFi.png"

    print("Génération du diagramme Sécurité & AU...")
    raise SystemExit(0 if render_puml(PUML, output) else 1)
