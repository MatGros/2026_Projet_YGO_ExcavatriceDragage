(* ═══════════════════════════════════════════════════════════════
   🪝 PRG_06_WinchControl — Commande des Treuils M1/M2, Synchro et Grappin
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 6.
   ✅ Arbitre entre les commandes Manuelles (Joystick) et Automatiques (PRG_05_Cycle).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_06_WinchControl
VAR
    // Stubs
    StubMachineEnableN1 : BOOL := TRUE;

    // Instances
    instWinchSync : FB_WinchSync;
    instGrappin   : FB_Grappin;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;

    // Variables de commande M1 après arbitrage Manuel/Auto
    M1_StartStop_Active     : BOOL;
    M1_Direction_Active     : INT;
    M1_SpeedRef_Active      : REAL;

    // Variables de commande M2 après arbitrage Grappin/Manuel/Auto
    M2_StartStop_Active     : BOOL;
    M2_Direction_Active     : INT;
    M2_SpeedRef_Active      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    // Bornage et limites
    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;
    ForbidDescentM1_Active  : BOOL;
    ForbidDescentM2_Active  : BOOL;

    // 🔧 REX 2026-07-07 : couplage croisé M1/M2 des arrêts, UNIQUEMENT si SyncActive (mouvement
    // coherent voulu). Hors synchro (Grappin.Busy ou OverrideSync MAINT_N2) : chaque treuil réagit
    // à SA PROPRE limite/défaut uniquement — commande indépendante voulue dans ce cas.
    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    ForbidDescentM1_Raw     : BOOL;
    ForbidDescentM2_Raw     : BOOL;
    ForbidAscentM1_Raw      : BOOL;
    ForbidAscentM2_Raw      : BOOL;
    ForbidAscentM1_Active   : BOOL;
    ForbidAscentM2_Active   : BOOL;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_06_WinchControl) ===

// ── 1. ARBITRAGE DES CONSIGNES M1 (Joystick vs Cycle Automatique) ────────
IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
    M1_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM1_StartStop;
    M1_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM1_Direction;
    M1_SpeedRef_Active  := PRG_05_Cycle.instCycle.CmdWinchM1_SpeedPct;
ELSE
    M1_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop AND NOT instGrappin.Busy;
    M1_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
    M1_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
END_IF;

// ── 2. ARBITRAGE DES CONSIGNES M2 (Grappin vs Cycle Automatique vs Joystick) ──
IF instGrappin.Busy THEN
    M2_StartStop_Active := instGrappin.M2_StartStop;
    M2_Direction_Active := instGrappin.M2_Direction;
    M2_SpeedRef_Active  := 15.0; // Vitesse lente forcée pour fermeture grappin
ELSE
    IF PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO THEN
        M2_StartStop_Active := PRG_05_Cycle.instCycle.CmdWinchM2_StartStop;
        M2_Direction_Active := PRG_05_Cycle.instCycle.CmdWinchM2_Direction;
        M2_SpeedRef_Active  := PRG_05_Cycle.instCycle.CmdWinchM2_SpeedPct;
    ELSE
        M2_StartStop_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;
        M2_Direction_Active := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction;
        M2_SpeedRef_Active  := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.SpeedRef;
    END_IF;
END_IF;

// ── 3. SURVEILLANCE ÉCART DE SYNCHRONISATION ────────────────────────────
instWinchSync(
    Enable          := NOT PRG_04_Modes.instModes.OverrideSync AND NOT instGrappin.Busy,
    Reset           := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk := PRG_00_Inputs.EmergencyStopOk,
    Mode            := PRG_04_Modes.instModes.Mode,
    CablePosM1      := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2      := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1         := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2         := PRG_02_Encoders.instHomingM2.Homed,
    OverrideSync    := PRG_04_Modes.instModes.OverrideSync,
    SyncToleranceM  := GVL_PERSISTENT.WinchSyncTolerance_M,
    ActiveOffsetM   := instGrappin.ActiveOffsetM,
    
    RelayFwdM1      := instWinchM1.RelayFwd,
    RelayFwdM2      := instWinchM2.RelayFwd,
    RelayRevM1      := instWinchM1.RelayRev,
    RelayRevM2      := instWinchM2.RelayRev,
    Contactor1_M1   := instWinchM1.Contactor1,
    Contactor1_M2   := instWinchM2.Contactor1,
    Contactor2_M1   := instWinchM1.Contactor2,
    Contactor2_M2   := instWinchM2.Contactor2,
    Contactor3_M1   := instWinchM1.Contactor3,
    Contactor3_M2   := instWinchM2.Contactor3,
    Contactor4_M1   := instWinchM1.Contactor4,
    Contactor4_M2   := instWinchM2.Contactor4
);

// ── 4. COMMANDE DU GRAPPIN (Séquence lente) ─────────────────────────────
instGrappin(
    Enable              := TRUE,
    Reset               := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    Mode                := PRG_04_Modes.instModes.Mode,
    CmdOpen_IHM         := GVL_IHM.Grappin.CmdOpen OR PRG_05_Cycle.instCycle.CmdGrappin_Open,
    CmdClose_IHM        := GVL_IHM.Grappin.CmdClose OR PRG_05_Cycle.instCycle.CmdGrappin_Close,
    JoystickY_StartStop := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop,
    JoystickY_Direction := PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.Direction,
    CablePosM1          := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    CablePosM2          := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    HomedM1             := PRG_02_Encoders.instHomingM1.Homed,
    HomedM2             := PRG_02_Encoders.instHomingM2.Homed,
    Config              := GVL_PERSISTENT.GrappinConfig,
    TimeoutDuration     := GVL_IHM.Grappin.TimeoutDuration,
    GrappinState        := GVL_PERSISTENT.GrappinState
);


// Table active M2 (court-circuite les contacteurs si vitesse lente requise pour le grappin)
IF instGrappin.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := FALSE; M2_SpeedStepTableActive.P1R2 := FALSE; M2_SpeedStepTableActive.P1R3 := FALSE; M2_SpeedStepTableActive.P1R4 := FALSE;
    M2_SpeedStepTableActive.P2R1 := FALSE; M2_SpeedStepTableActive.P2R2 := FALSE; M2_SpeedStepTableActive.P2R3 := FALSE; M2_SpeedStepTableActive.P2R4 := FALSE;
    M2_SpeedStepTableActive.P3R1 := FALSE; M2_SpeedStepTableActive.P3R2 := FALSE; M2_SpeedStepTableActive.P3R3 := FALSE; M2_SpeedStepTableActive.P3R4 := FALSE;
    M2_SpeedStepTableActive.P4R1 := FALSE; M2_SpeedStepTableActive.P4R2 := FALSE; M2_SpeedStepTableActive.P4R3 := FALSE; M2_SpeedStepTableActive.P4R4 := FALSE;
    M2_SpeedStepTableActive.P5R1 := FALSE; M2_SpeedStepTableActive.P5R2 := FALSE; M2_SpeedStepTableActive.P5R3 := FALSE; M2_SpeedStepTableActive.P5R4 := FALSE;
    M2_SpeedStepTableActive.StepThreshold_Pct := GVL_PERSISTENT.WinchM2SpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := GVL_PERSISTENT.WinchM2SpeedStepTable;
END_IF;

// ── 5. CALCUL DES LIMITES BASSES ACTIVES ET DU BLOCAGE DE DESCENTE ──────
// 🔧 REX 2026-07-07 : limite légale appliquée sur LimitLegalEnabled SEUL, plus de garde
// Mode=SEMI_AUTO — la limite légale doit stopper la descente dans TOUS les modes dès qu'elle
// est activée (constat terrain : ne s'arrêtait pas en MAINT_N1/N2 alors qu'attendu).
BottomLimitM1_Active := GVL_PERSISTENT.CableLimitDescent_M;
IF GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(BottomLimitM1_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

BottomLimitM2_Active := GVL_PERSISTENT.CableLimitDescent_M;
IF GVL_PERSISTENT.LimitLegalEnabled THEN
    BottomLimitM2_Active := MAX(BottomLimitM2_Active, GVL_PERSISTENT.LimitLegalDepthMinAllowed);
END_IF;

// ── 5bis. COUPLAGE CROISÉ M1/M2 — REX 2026-07-07 ────────────────────────
// Hors synchro (Grappin.Busy ou OverrideSync N2) : chaque treuil réagit à SA PROPRE limite/
// défaut uniquement (commande indépendante voulue). En synchro (SyncActive, mouvement cohérent
// voulu) : n'importe quel arrêt (SafeStop, limite câble, limite légale, fin de course haut) sur
// UN treuil coupe IMMÉDIATEMENT les deux — pas d'attente du filtre 500ms de FB_WinchSync.
// 🔧 REX 2026-07-07 : instGrappin.M1SlipDetected ajouté à M1 uniquement (Méca C couche 1) — M2
// est déjà arrêté par son propre mécanisme SevereError interne à FB_Grappin, pas besoin ici.
SafeStopM1_Raw      := PRG_03_Safety.instSafetyWinchM1.SafeStop OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000)
                       OR instGrappin.M1SlipDetected;
SafeStopM2_Raw      := PRG_03_Safety.instSafetyWinchM2.SafeStop OR ((instWinchSync.ErrorId AND 16#0002) <> 16#0000);

ForbidDescentM1_Raw := PRG_03_Safety.instSafetyWinchM1.ForbidDescent
                       OR (GVL_PERSISTENT.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM1.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));
ForbidDescentM2_Raw := PRG_03_Safety.instSafetyWinchM2.ForbidDescent
                       OR (GVL_PERSISTENT.LimitLegalEnabled
                           AND (PRG_02_Encoders.instEncoderScaleM2.CablePosM <= GVL_PERSISTENT.LimitLegalDepthMinAllowed));

ForbidAscentM1_Raw  := PRG_03_Safety.instSafetyWinchM1.ForbidAscent;
ForbidAscentM2_Raw  := PRG_03_Safety.instSafetyWinchM2.ForbidAscent;

SafeStopM1_Active      := SafeStopM1_Raw      OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active      := SafeStopM2_Raw      OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
ForbidDescentM1_Active := ForbidDescentM1_Raw OR (instWinchSync.SyncActive AND ForbidDescentM2_Raw);
ForbidDescentM2_Active := ForbidDescentM2_Raw OR (instWinchSync.SyncActive AND ForbidDescentM1_Raw);
ForbidAscentM1_Active  := ForbidAscentM1_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM2_Raw);
ForbidAscentM2_Active  := ForbidAscentM2_Raw  OR (instWinchSync.SyncActive AND ForbidAscentM1_Raw);

// ── 6. EXÉCUTION DU PILOTAGE DU TREUIL M1 ───────────────────────────────
instWinchM1(
    Enable                  := StubMachineEnableN1,
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M1_StartStop_Active,
    SafeStop                := SafeStopM1_Active,
    ForbidDescent           := ForbidDescentM1_Active,
    ForbidAscent            := ForbidAscentM1_Active,
    Direction               := M1_Direction_Active,
    SpeedRefPct             := M1_SpeedRef_Active,
    SpeedStepTable          := GVL_PERSISTENT.WinchM1SpeedStepTable,
    MaxStepDescente         := GVL_PERSISTENT.WinchM1MaxStepDescente,
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M1FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M1BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM1_IsReal,
    RampAccelRate           := GVL_PERSISTENT.WinchM1RampAccelRate_Pct,
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM1RampDecelNormal_Pct,
    RampDecelFastRate       := GVL_PERSISTENT.WinchM1RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM1.Homed,
    CablePosM               := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM1_M,
    BottomLimitM            := BottomLimitM1_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
);

// ── 7. EXÉCUTION DU PILOTAGE DU TREUIL M2 ───────────────────────────────
instWinchM2(
    Enable                  := StubMachineEnableN1,
    Reset                   := PRG_09_Supervision.FaultMachineReset_IHM,
    EmergencyStopOk         := PRG_00_Inputs.EmergencyStopOk,
    Mode                    := PRG_04_Modes.instModes.Mode,
    StartStop               := M2_StartStop_Active,
    SafeStop                := SafeStopM2_Active,
    ForbidDescent           := ForbidDescentM2_Active,
    ForbidAscent            := ForbidAscentM2_Active,
    Direction               := M2_Direction_Active,
    SpeedRefPct             := M2_SpeedRef_Active,
    SpeedStepTable          := M2_SpeedStepTableActive,
    MaxStepDescente         := GVL_PERSISTENT.WinchM2MaxStepDescente,
    FwdRevSpeedFeedbackOff  := PRG_00_Inputs.M2FwdRevSpeedFeedbackOff, // 🔧 REX 2026-07-07
    BrakeFeedback           := PRG_00_Inputs.M2BrakeFeedback,
    BypassContactorCheck    := GVL_Simulation.SimulationModeActive AND NOT GVL_Simulation.ContactorFeedbackM2_IsReal,
    RampAccelRate           := GVL_PERSISTENT.WinchM2RampAccelRate_Pct,
    RampDecelNormalRate     := GVL_PERSISTENT.WinchM2RampDecelNormal_Pct,
    RampDecelFastRate       := GVL_PERSISTENT.WinchM2RampDecelFast_Pct,
    Homed                   := PRG_02_Encoders.instHomingM2.Homed,
    CablePosM               := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    TopLimitM               := GVL_PERSISTENT.HomingTargetM2_M,
    BottomLimitM            := BottomLimitM2_Active,
    SlowdownDistanceM       := GVL_PERSISTENT.WinchSlowdownDistance_M,
    SlowSpeedPct            := GVL_PERSISTENT.WinchSlowSpeedPct
);

// ── 8. ALIMENTATION PRG_10_Outputs (sorties physiques) ──────────────────
// 🔴🔧 REX 2026-07-07 : PRG_10_Outputs est une tâche indépendante (MainTask, PouList),
// jamais appelée avec paramètres — ses VAR_INPUT restaient à FALSE en permanence, y compris
// sur machine réelle (aucun relais/contacteur/frein ne s'activait jamais). Alimentation directe
// ici, AVANT PRG_10_Outputs dans l'ordre de tâche (position 6 < 10, même cycle API).
PRG_10_Outputs.M1RelayFwd        := instWinchM1.RelayFwd;
PRG_10_Outputs.M1RelayRev        := instWinchM1.RelayRev;
PRG_10_Outputs.M1SpeedContactor1 := instWinchM1.Contactor1;
PRG_10_Outputs.M1SpeedContactor2 := instWinchM1.Contactor2;
PRG_10_Outputs.M1SpeedContactor3 := instWinchM1.Contactor3;
PRG_10_Outputs.M1SpeedContactor4 := instWinchM1.Contactor4;
PRG_10_Outputs.M1BrakeCmd        := instWinchM1.BrakeCmd;

PRG_10_Outputs.M2RelayFwd        := instWinchM2.RelayFwd;
PRG_10_Outputs.M2RelayRev        := instWinchM2.RelayRev;
PRG_10_Outputs.M2SpeedContactor1 := instWinchM2.Contactor1;
PRG_10_Outputs.M2SpeedContactor2 := instWinchM2.Contactor2;
PRG_10_Outputs.M2SpeedContactor3 := instWinchM2.Contactor3;
PRG_10_Outputs.M2SpeedContactor4 := instWinchM2.Contactor4;
PRG_10_Outputs.M2BrakeCmd        := instWinchM2.BrakeCmd;
