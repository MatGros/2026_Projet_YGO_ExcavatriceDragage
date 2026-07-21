(* ═══════════════════════════════════════════════════════════════
   🔄 PRG_05_Cycle — Séquenceur du Cycle Automatique / Semi-Auto (Grafcet)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5.
   ✅ Gère la machine d'état principale de dragage (FB_Cycle).
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-04_Cycle_Sequenceur_v1.4.md
*)

PROGRAM PRG_05_Cycle
VAR
    // Instance du séquenceur automatique
    instCycle           : FB_Cycle;

    // Commandes issues de la supervision (IHM)
    CmdStartCycle_IHM   : BOOL;         // Lancement cycle automatique
    CmdPauseCycle_IHM   : BOOL;         // Pause cycle automatique
    CmdAbortCycle_IHM   : BOOL;         // Abandon / arrêt cycle automatique
    CmdResetCycle_IHM   : BOOL;         // 🔧 REX 2026-07-07 : reset dédié FB_Cycle, jamais mélangé au reset défauts général

    // Paramètres cibles réglés par l'opérateur
    TargetDepthM        : REAL := -12.5; // Profondeur de dragage cible (mètres, négative)
    TargetOffsetM       : REAL := 1.5;  // Décalage cible de fermeture du benne (mètres)
    CycleMotionPermit    : BOOL;        // Homme-mort + axe Y actif
    // 🧪 T43 — paramètres provisoirement désactivés ; à définir avec T45.
    SpeedMismatchThresholdMps : REAL := 0.0;
    SpeedMismatchTimeout      : TIME := T#0ms;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_05_Cycle) ===

// 🕹️ Interface unique de commande cycle depuis GVL_IHM.
CmdStartCycle_IHM := GVL_IHM.Cycle.CmdStart;
CmdPauseCycle_IHM := GVL_IHM.Cycle.CmdPause;
CmdAbortCycle_IHM := GVL_IHM.Cycle.CmdAbort;
CmdResetCycle_IHM := GVL_IHM.Cycle.CmdReset;
TargetDepthM      := GVL_IHM.Cycle.TargetDepth_M;
TargetOffsetM     := GVL_IHM.Cycle.TargetOffset_M;
GVL_Simulation.KoboldContactFond_Simulated := GVL_IHM.Cycle.SimKoboldContactFond;
CycleMotionPermit := PRG_01_Diagnostics.FB_Joystick_0.DeadmanArmed
                     AND PRG_01_Diagnostics.FB_Joystick_0.AxisCmdY.StartStop;

// Appel du séquenceur de cycle principal avec tous ses raccordements
instCycle(
    // 🔧 REX 2026-07-19 : suppression IHM_MANU — Mode=SEMI_AUTO suffit seul (les modes
    // sont mutuellement exclusifs dans FB_Modes, plus besoin d'un flag ManuActive séparé).
    Enable              := (PRG_04_Modes.instModes.Mode = E_Mode.SEMI_AUTO),
    CycleMotionPermit   := CycleMotionPermit,
    HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk,
    Reset               := CmdResetCycle_IHM,
    EmergencyStopOk     := PRG_00_Inputs.EmergencyStopOk,
    
    StartCycle          := CmdStartCycle_IHM,
    PauseCycle          := CmdPauseCycle_IHM,
    AbortCycle          := CmdAbortCycle_IHM,
    
    TargetDepthM        := TargetDepthM,
    TargetOffsetM       := TargetOffsetM,
    SelectedTargetNum_IHM := GVL_IHM.TranslationM3.SelectedTargetNum,

    // Retour dédié Kobold — distinct du mou de câble.
    KoboldContactFond   := PRG_00_Inputs.KoboldContactFond,
    LimitLegalReached   := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM    := GVL_IHM.Commun.LimitLegalDepthMinAllowed_M,
    WinchSyncError      := PRG_06_WinchControl.instWinchSync.Error,
    WinchSyncDeltaM     := PRG_06_WinchControl.instWinchSync.DeltaPosM,
    M1_CablePosM        := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2_CablePosM        := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    M1_MeasuredSpeedMps := PRG_03_Safety.instSafetyWinchM1.MeasuredSpeedMps,
    M2_MeasuredSpeedMps := PRG_03_Safety.instSafetyWinchM2.MeasuredSpeedMps,
    SpeedMismatchThresholdMps := SpeedMismatchThresholdMps,
    SpeedMismatchTimeout      := SpeedMismatchTimeout,
    CableLimitM1AscentM       := _CableLimitM1Ascent_M,

    // Position translation — 🆕 REX 2026-07-18 : Fosse1/Fosse2 renommés P1/P2 (AF_Partie-02 v2.12 §3bis)
    Translation_At_P1       := PRG_00_Inputs.TranslationPosP1,
    Translation_At_P2       := PRG_00_Inputs.TranslationPosP2,
    Translation_At_Maintenance := PRG_00_Inputs.TranslationPosMaintenance,
    Translation_At_Tremie   := PRG_00_Inputs.TranslationPosTremie,
    Translation_Busy        := PRG_07_TranslationControl.instTranslationM3.Busy,
    Translation_Done        := PRG_07_TranslationControl.instTranslationM3.Done,

    // Mouvements mâchoires benne (gérés par instBucket)
    Benne_Busy        := PRG_06_WinchControl.instBucket.Busy,
    Benne_Done        := PRG_06_WinchControl.instBucket.Done,
    Benne_IsOpen      := _BucketState.IsOpen,
    Benne_IsClosed    := _BucketState.IsClosed
);

GVL_IHM.Cycle.SpeedMismatch_Mps        := instCycle.SpeedMismatchMps;
GVL_IHM.Cycle.SpeedMismatchActive     := instCycle.SpeedMismatchActive;
GVL_IHM.Cycle.SpeedMismatchConfirmed  := instCycle.SpeedMismatchConfirmed;

// 🧹 Les commandes restent impulsionnelles même si GVL_IHM est RETAIN.
GVL_IHM.Cycle.CmdStart := FALSE;
GVL_IHM.Cycle.CmdPause := FALSE;
GVL_IHM.Cycle.CmdAbort := FALSE;
GVL_IHM.Cycle.CmdReset := FALSE;
