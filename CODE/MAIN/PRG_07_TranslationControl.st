(* ═══════════════════════════════════════════════════════════════
   ↔️ PRG_07_TranslationControl — Pilotage de la Translation Translation M3
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 7.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_07_TranslationControl
VAR
    instTranslationM3           : FB_Translation;
 
    // Commandes arbitrées après sélection Manuel/Auto
    M3_StartStop_Active     : BOOL;
    M3_Direction_Active     : INT;
    M3_SpeedRef_Active      : REAL;
    M3_PositionSensorTarget : BOOL;
    
    // Target active (HMI en manuel, instCycle en auto)
    SelectedTargetNum       : INT;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_07_TranslationControl) ===

// ── 1. ARBITRAGE DU SÉLECTEUR DE CIBLE ET DE LA DIRECTION ──────────────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    // Mode Auto/Semi-Auto : Consigne issue du séquenceur de cycle
    SelectedTargetNum    := PRG_05_Cycle.instCycle.CmdTranslationM3_Target;
    M3_StartStop_Active  := PRG_05_Cycle.instCycle.CmdTranslationM3_Start;
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
    SelectedTargetNum    := StubTranslationPositionSelect_IHM;
    M3_StartStop_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.StartStop;
    M3_Direction_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.Direction;
    M3_SpeedRef_Active   := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdX.SpeedRef;
END_IF;

// Câblage du capteur de butée de la cible sélectionnée
CASE SelectedTargetNum OF
    1: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosFosse1;
    2: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosFosse2;
    3: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosMaintenance;
    4: M3_PositionSensorTarget := PRG_00_Inputs.TranslationPosTremie;
ELSE
    M3_PositionSensorTarget := FALSE;   // Aucun capteur visé
END_CASE;

// ── 2. EXÉCUTION DU PILOTAGE DU TRANSLATION M3 ──────────────────────────────
instTranslationM3(
    Enable                  := PRG_06_WinchControl.StubMachineEnableN1,
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M3_StartStop_Active,
    SafeStop                := PRG_03_Safety.instSafetyTranslationM3.SafeStop,
    Direction               := M3_Direction_Active,
    SpeedRefPct             := M3_SpeedRef_Active,
    PositionSensorTarget    := M3_PositionSensorTarget,
    LimitSwitchFwd          := PRG_00_Inputs.TranslationPosTremie,
    LimitSwitchRev          := PRG_00_Inputs.TranslationPosFosse1,
    DriveStatusWord         := PRG_00_Inputs.M3_StatusWord_Filtered,
    DriveActualFreqHz       := UINT_TO_REAL(PRG_00_Inputs.M3_ActualFrequencyHz_Filtered) / 100.0,
    BrakeFeedback           := SEL(GVL_IHM.TranslationM3.BypassContactorFeedback, PRG_00_Inputs.M3BrakeFeedback, instTranslationM3.BrakeCmd),
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM3_IsReal
);

// 🔴 Recopie commande de frein translation
PRG_10_Outputs.TranslationBrakeCmd := instTranslationM3.BrakeCmd;
