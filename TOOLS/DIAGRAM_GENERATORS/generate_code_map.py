#!/usr/bin/env python3
"""Generate detailed sub-diagrams for Translation M3 (Vue 1, Vue 2, Vue 3)."""

import sys
from pathlib import Path

TOOLS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_ROOT))
from visualize_workflow import render_puml

PUML_COMMON = r"""skinparam backgroundColor #FFFFFF
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
"""


def v1_acquisition():
    return rf"""@startuml View1_Acquisition
{PUML_COMMON}
title <img:open-iconic/input> Vue 1 — Acquisition, Décodage 5 Bits & Sécurité (Translation M3)

rectangle "<img:open-iconic/input>\nCAPTEURS TOR (5 BITS)\n---\n• TranslationPosTremie : BOOL\n• TranslationPosPV : BOOL\n• TranslationPosP2 : BOOL\n• TranslationPosP1 : BOOL\n• TranslationPosMaintenance : BOOL" as SENSORS #BBDEFB

rectangle "<img:open-iconic/input>\nPRG_00_Inputs (CONDITIONNEMENT)\n---\n• M3BrakeFeedback : BOOL\n• BrakeThermalFeedback : BOOL\n• PhaseRotationOk : BOOL\n• EmergencyStopOk : BOOL\n• M3_StatusWord_Filtered : WORD\n• M3_ActualFrequencyHz_Filtered : UINT (x100)" as INPUTS #E3F2FD

rectangle "<img:open-iconic/cog>\nPRG_07_TranslationControl\n---\n• instPositionDecoder :\n  FB_Translation_PositionDecoder\n• Sens de déplacement & Décodage" as DECODER #E8F5E9

rectangle "<img:open-iconic/wrench>\nPRG_01_Diagnostics\n---\n• instDiagCanOpen.DeviceJoystick\n  (.Online / .Operational)\n• instDiagEthercat.DeviceVariateur\n  (.Online / .Operational)" as DIAG #ECEFF1

rectangle "<img:open-iconic/shield>\nPRG_03_Safety\n---\n• instSafetyTranslationM3 :\n  FB_Safety_Translation\n• Alarmes & Interlocks Safety" as SAFETY #FFCDD2

rectangle "<img:open-iconic/warning>\nRÉACTIONS SÉCURITÉ MÉTIER\n---\n• SafeStop : BOOL (Rampe rapide)\n• PowerCutOff : BOOL (Coupure 1oo2)\n• Error / ErrorId : BOOL / WORD\n• State / StateAtError : E_State" as REACTION #FFEBEE

SENSORS --> INPUTS : 5 entrées TOR brutes
INPUTS --> DECODER : Word 5 bits (Trémie | PV | P2 | P1 | Maint)
DECODER --> SAFETY : LimitSwitchFwd / Rev\nIncoherent = TRUE
INPUTS --> SAFETY : Safety Ok / Thermal / Feedback / Freq
DIAG --> SAFETY : JoystickOnline / DriveOnline
SAFETY --> REACTION : Mémorisé jusqu'au front Reset\n(Cause disparue obligatoire)

note bottom of DECODER
  <img:open-iconic/magnifying-glass> **Masque de contrôle 5 bits** :
  • Mots autorisés : 11111, 01111, 00111, 00011, 00001, 00000
  • Tout autre mot d'entrée ➔ <img:open-iconic/warning> **Incoherent = TRUE**
end note

note bottom of SAFETY
  <img:open-iconic/shield> **Matrice ErrorId (Bitfield 16 bits)** :
  • b0: Joystick CAN · b1: EtherCAT AC600 · b2: Rotation phases
  • b3: Thermique frein · b4: Méca B (>3 s) · b5: Méca A (>0.5 Hz / >1 s)
  • b6: Limite extrême · b7: Mot 5 bits incohérent
  👉 **SafeStop** = Error OR NOT EmergencyStopOk
  👉 **PowerCutOff** = au moins un bit b3..b7
end note

footer Document source : PRG_00_Inputs, PRG_01_Diagnostics, PRG_03_Safety, PRG_07_TranslationControl
@enduml"""


def v2_control():
    return rf"""@startuml View2_Control
{PUML_COMMON}
title <img:open-iconic/cog> Vue 2 — Arbitrage, Consignes, Rampes & Variateur AC600 (Translation M3)

rectangle "<img:open-iconic/loop>\nSEMI_AUTO (CYCLE)\n---\n• PRG_05_Cycle.instCycle\n  - CmdTranslationM3_Start : BOOL\n  - CmdTranslationM3_Target : INT" as CYCLE #FFE0B2

rectangle "<img:open-iconic/dial>\nMANUEL (JOYSTICK)\n---\n• PRG_01_Diagnostics.FB_Joystick_0\n  - DeadmanArmed : BOOL\n  - AxisCmdX.StartStop : BOOL\n  - AxisCmdX.Direction : INT\n  - AxisCmdX.SpeedRef : REAL (%)" as JOY #BBDEFB

rectangle "<img:open-iconic/monitor>\nMAINTENANCE (IHM N1/N2)\n---\n• GVL_IHM.TranslationM3\n  - ReqFwd / ReqRev : BOOL\n  - JoystickSelect : BOOL\n  - FreqSetpointHz : REAL\n  - SelectedTargetNum : INT" as HMI #F8BBD0

rectangle "<img:open-iconic/wrench>\nSÉLECTION DU MODE\n---\n• PRG_04_Modes.instModes\n  - Mode : E_Mode\n  - MaintenanceM3TargetEnable : BOOL" as MODES #D1C4E9

rectangle "<img:open-iconic/cog>\nPRG_07_TranslationControl\n(ARBITRAGE EFFECTIF)\n---\n• SelectedTargetNum : INT\n• M3_StartStop_Active : BOOL\n• M3_Direction_Active : INT\n• M3_SpeedRef_Active : REAL (%)\n• M3_PositionSensorTarget : BOOL" as ARB #FFF3E0

rectangle "<img:open-iconic/cogs>\nMETIER : FB_Translation\n---\n• Enable / Reset / EmergencyStopOk\n• StartStop / SafeStop\n• Direction / SpeedRefPct\n• BrakeFeedback / BypassContactorCheck" as MOVE #E8F5E9

rectangle "<img:open-iconic/graph>\nLOGIQUE INTERNE FB\n---\n• SpeedRamp : FB_Ramp\n• Brake : FB_Brake\n• DirectionChangeDelay : TON\n• CaptorDebounceTon : TON\n• ArrivalLock : BOOL" as INTERNAL #DCEDC8

rectangle "<img:open-iconic/external-link>\nCOMMANDES EFFECTIVES\n---\n• DriveControlWord : WORD\n• DriveFreqRefHz : REAL (Hz)\n• BrakeCmd : BOOL\n• Ready / Busy / Done / Error" as FBOUT #C8E6C9

CYCLE --> ARB : Consignes de cycle
JOY --> ARB : Homme-mort + Sens/Vitesse
HMI --> ARB : Maintenance & Consigne Hz
MODES --> ARB : Mode actif + Autorisation
ARB --> MOVE : 5 commandes arbitrées
MOVE --> INTERNAL : RampTargetPct\nMovementRequested
INTERNAL --> FBOUT : Trame AC600 + Frein

note bottom of ARB
  <img:open-iconic/target> **Priorité des cibles** : 0=Aucune · 1=Trémie · 2=P2 · 3=P1 · 4=Maintenance
  • PV (ralentissement) n'est pas une cible mais un point d'approche.
  • Cible Maintenance refusée si MaintenanceM3TargetEnable = FALSE.
end note

note bottom of MOVE
  <img:open-iconic/shield> **Hiérarchie stricte des arrêts** :
  1. **Enable = FALSE** ➔ Neutralisation immédiate (sorties coupées).
  2. **SafeStop = TRUE** ➔ Decel rapide (RampDecelFastRate), Enable maintenu.
  3. **StartStop = FALSE** ➔ Decel normale (RampDecelNormalRate).
end note

footer Document source : PRG_07_TranslationControl et FB_Translation
@enduml"""


def v3_supervision():
    return rf"""@startuml View3_Supervision
{PUML_COMMON}
title <img:open-iconic/monitor> Vue 3 — Sorties Physiques EtherCAT & Supervision IHM (Translation M3)

rectangle "<img:open-iconic/cogs>\nMETIER : FB_Translation\n---\n• DriveControlWord : WORD\n• DriveFreqRefHz : REAL\n• BrakeCmd : BOOL\n• Diagnostic Mouvement" as MOVE #E8F5E9

rectangle "<img:open-iconic/shield>\nSAFETY : FB_Safety_Translation\n---\n• PowerCutOff : BOOL\n• SafeStop : BOOL\n• ErrorId : WORD\n• 8 Alarms décapsulées" as SAFE #FFCDD2

rectangle "<img:open-iconic/external-link>\nPRG_10_Outputs (PILOTAGE)\n---\n• M3_CommandWord := DriveControlWord\n• M3_SetpointFrequencyHz := REAL_TO_UINT\n• TranslationBrakeCmd := BrakeCmd\n• PowerCutOffReq := OR M1, M2, M3" as OUTPUTS #FFF3E0

rectangle "<img:open-iconic/input>\nSORTIES PHYSIQUES (HARDWARE)\n---\n• M3_CommandWord (0x3101)\n• M3_SetpointFrequencyHz (0x3100)\n• M3_BrakeCmd_RQ (TOR)\n• PowerCutOff_A_RQ / B_RQ (Relais A/B)" as PHYS #FFE0B2

rectangle "<img:open-iconic/monitor>\nPRG_09_Supervision\n(MAPPING STRUCTURÉ)" as SUP #E3F2FD

rectangle "<img:open-iconic/monitor>\nGVL_IHM.TranslationM3 — MOUVEMENT\n---\n• Ready / Busy / Done / Error / ErrorId\n• BrakeCmd · PositionSensorTarget\n• DriveControlWord · DriveFreqRefHz" as HMI_MOVE #E1F5FE

rectangle "<img:open-iconic/monitor>\nGVL_IHM.TranslationM3 — ACQUISITION\n---\n• BrakeFeedback\n• Positions (Trémie, PV, P2, P1, Maint)\n• SensorsWord · SensorWordIncoherent\n• LimitSwitchFwd / Rev" as HMI_IN #E1F5FE

rectangle "<img:open-iconic/monitor>\nGVL_IHM.TranslationM3 — SÉCURITÉ\n---\n• SafetyError · SafetyErrorId\n• SafetyErrorJoystick · SafetyErrorDriveComm\n• SafetyErrorPhaseRotation · SafetyErrorBrakeThermal\n• SafetyErrorMecaB · SafetyErrorMecaA" as HMI_SAFE #FFEBEE

MOVE --> OUTPUTS : Commandes effectives
SAFE --> OUTPUTS : PowerCutOff M3
OUTPUTS --> PHYS : Écriture EtherCAT + Relais TOR
MOVE --> SUP : Statut & Frein
SAFE --> SUP : Causes & ErrorId
SUP --> HMI_MOVE : Transmis IHM Mouvement
SUP --> HMI_IN : Transmis IHM Capteurs
SUP --> HMI_SAFE : Transmis IHM Sécurité

note bottom of OUTPUTS
  <img:open-iconic/bolt> **Architecture de coupure 1oo2** :
  • PowerCutOffReq contrôle deux relais physiques A et B en série.
  • Garantit le déclenchement de la puissance amont même en cas de contacteur collé.
end note

footer Document source : PRG_09_Supervision & GVL_IHM
@enduml"""


if __name__ == "__main__":
    project_root = TOOLS_ROOT.parent
    out_dir = project_root / "DOC" / "DIAGRAMS" / "CODE"
    out_dir.mkdir(parents=True, exist_ok=True)

    print("Génération des trois vues détaillées Translation M3...")
    ok1 = render_puml(v1_acquisition(), out_dir / "DIAG_CODE_TranslationM3_View1_Acquisition.png")
    ok2 = render_puml(v2_control(), out_dir / "DIAG_CODE_TranslationM3_View2_Control.png")
    ok3 = render_puml(v3_supervision(), out_dir / "DIAG_CODE_TranslationM3_View3_Supervision.png")

    sys.exit(0 if (ok1 and ok2 and ok3) else 1)
