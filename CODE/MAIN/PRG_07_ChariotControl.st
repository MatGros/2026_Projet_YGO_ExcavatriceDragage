(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_07_ChariotControl — Pilotage de la Translation Chariot M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_07_ChariotControl
VAR
    instChariotM3           : FB_Chariot;
    
    // Commandes arbitrées après sélection Manuel/Auto
    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositionSensorTarget : BOOL;
    
    // Target active (HMI en manuel, instCycle en auto)
    SelectedTargetNum       : INT;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_07_ChariotControl) ===

// ── 1. ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ──────────────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // Mode Auto/Semi-Auto : Consigne issue du séquenceur de cycle
    SelectedTargetNum    := PRG_05_Cycle.instCycle.CmdChariotM3_Target;
    M3_StartStop_Active  := PRG_05_Cycle.instCycle.CmdChariotM3_Start;
    M3_SpeedRef_Active   := 40.0; // Vitesse de translation automatique nominale (40%)
    
    // Détermination automatique du sens de marche selon la cible :
    // - Trémie (cible 4) = Marche Avant (Direction := 1)
    // - Fosses (cible 1 et 2) = Marche Arrière (Direction := -1)
    IF SelectedTargetNum = 4 THEN
        M3_Direction_Active := 1;
    ELSE
        M3_Direction_Active := -1;
    END_IF;
ELSE
    // Mode Manuel/Maintenance : Consignes issues du Joystick et sélecteur HMI
    SelectedTargetNum    := StubChariotPositionSelect_IHM;
    M3_StartStop_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.StartStop;
    M3_Direction_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.Direction;
    M3_SpeedRef_Active   := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
END_IF;

// Câblage du capteur de butée de la cible sélectionnée
CASE SelectedTargetNum OF
    1: M3_PositionSensorTarget := PRG_00_Inputs.ChariotPosFosse1;
    2: M3_PositionSensorTarget := PRG_00_Inputs.ChariotPosFosse2;
    3: M3_PositionSensorTarget := PRG_00_Inputs.ChariotPosMaintenance;
    4: M3_PositionSensorTarget := PRG_00_Inputs.ChariotPosTremie;
ELSE
    M3_PositionSensorTarget := FALSE;   // Aucun capteur visé
END_CASE;

// ── 2. EXÉCUTION DU PILOTAGE DU CHARIOT M3 ──────────────────────────────
instChariotM3(
    Enable                  := PRG_06_WinchControl.StubMachineEnableN1,
    Reset                   := PRG_09_Supervision.MachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := PRG_03_Safety.instSafetyChariotM3.SafeStop,
    CommMode                := E_ChariotCommMode.DEGRADED_IO,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    DriveStatusWord         := 0,
    DriveActualFreqHz       := 0.0,
    ContactorFeedbackFwd    := M3_ContactorFeedbackFwd,
    ContactorFeedbackRev    := M3_ContactorFeedbackRev,
    DriveFaultFeedback      := M3_DriveFaultFeedback,
    BrakeFeedback           := SEL(GVL_IHM.Chariot.BypassBrakeFeedback, PRG_00_Inputs.M3BrakeFeedback, instChariotM3.BrakeCmd)
);

// ── 3. RECOPIE VERS LES VARIABLES GLOBALES DE SIMULATION / STUBS ─────────
M3_RelayFwd     := instChariotM3.RelayFwd;
M3_RelayRev     := instChariotM3.RelayRev;
M3_RelaySpeedGv := instChariotM3.RelaySpeedGv;

M3_ContactorFeedbackFwd := M3_RelayFwd;
M3_ContactorFeedbackRev := M3_RelayRev;
