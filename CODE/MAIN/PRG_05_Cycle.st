(* ═══════════════════════════════════════════════════════════════
   🔄 PRG_05_Cycle — Séquenceur du Cycle Automatique / Semi-Auto (Grafcet)
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 5.
   ✅ Gère la machine d'état principale de dragage (FB_Cycle).
   ═══════════════════════════════════════════════════════════════
   📄 Docs : DOC/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md
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
    SetDepthM        : REAL := -12.5; // Profondeur de dragage cible (mètres, négative)
    SetOffsetM       : REAL := 1.5;  // Décalage cible de fermeture du benne (mètres)
    CycleMotionPermit    : BOOL;        // Homme-mort + axe Y actif
    // 🧪 T43 — paramètres provisoirement désactivés ; à définir avec T45.
    SpeedMismatchThresholdMps : REAL := 0.0;
    SpeedMismatchTimeout      : TIME := T#0ms;
END_VAR

// === IMPLEMENTATION (corps du PROGRAM PRG_05_Cycle) ===

// 🕹️ Interface unique de commande cycle depuis GVL_IHM.
CmdStartCycle_IHM := GVL_IHM.Cycle.Cmd.BtnStart;
CmdPauseCycle_IHM := GVL_IHM.Cycle.Cmd.BtnPause;
CmdAbortCycle_IHM := GVL_IHM.Cycle.Cmd.BtnAbort;
CmdResetCycle_IHM := GVL_IHM.Cycle.Cmd.BtnReset;
SetDepthM      := GVL_IHM.Cycle.Cfg.SetDepth_M;
SetOffsetM     := GVL_IHM.Cycle.Cfg.SetOffset_M;
CycleMotionPermit := PRG_01_Diagnostics.instJoystick.DeadmanArmed
                     AND PRG_01_Diagnostics.instJoystick.AxisCmdY.StartStop;

// Appel du séquenceur de cycle principal avec tous ses raccordements
instCycle(
    // 🔧 REX 2026-07-19 : suppression IHM_MANU — Mode=SEMI_AUTO suffit seul (les modes
    // sont mutuellement exclusifs dans FB_Modes, plus besoin d'un flag ManuActive séparé).
    Enable              := (PRG_MODES_CFC.Auth.Mode = E_Mode.SEMI_AUTO),
    CycleMotionPermit   := CycleMotionPermit,
    HeartbeatIhmOk      := PRG_01_Diagnostics.instIhmHeartbeat.HeartbeatIhmOk,
    Reset               := CmdResetCycle_IHM,
    PowerContactorEngaged     := PRG_INPUTS_LD.PowerContactorEngaged,
    
    StartCycle          := CmdStartCycle_IHM,
    PauseCycle          := CmdPauseCycle_IHM,
    AbortCycle          := CmdAbortCycle_IHM,
    
    SetDepthM        := SetDepthM,
    SetOffsetM       := SetOffsetM,
    SelectedTargetNum_IHM := GVL_IHM.TranslationM3.Cmd.SelTarget,

    // Retour dédié Kobold — distinct du mou de câble.
    KoboldContactFond   := PRG_INPUTS_LD.KoboldContactFond,
    LimitLegalReached   := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM    := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M,
    WinchSyncError      := PRG_06_WinchControl.instWinchSync.Error,
    WinchSyncDeltaM     := PRG_06_WinchControl.instWinchSync.DeltaPosM,
    M1_CablePosM        := PRG_02_Encoders.instEncoderScaleM1.CablePosM,
    M2_CablePosM        := PRG_02_Encoders.instEncoderScaleM2.CablePosM,
    M1_MeasuredSpeedMps := PRG_02_Encoders.M1MeasuredSpeed_Mps,
    M2_MeasuredSpeedMps := PRG_02_Encoders.M2MeasuredSpeed_Mps,
    SpeedMismatchThresholdMps := SpeedMismatchThresholdMps,
    SpeedMismatchTimeout      := SpeedMismatchTimeout,
    CableLimitM1AscentM       := _WinchM1CfgPersist.CfgCableLimitAscent_M,

    // Position translation — 🆕 REX 2026-07-18 : Fosse1/Fosse2 renommés P1/P2 (AF_Partie-02 v2.12 §3bis)
    Translation_At_P1       := PRG_ACQUISITION_CFC.TranslationPosP1,
    Translation_At_P2       := PRG_ACQUISITION_CFC.TranslationPosP2,
    Translation_At_Maintenance := PRG_ACQUISITION_CFC.TranslationPosMaintenance,
    Translation_At_Tremie   := PRG_ACQUISITION_CFC.TranslationPosTremie,
    Translation_Busy        := PRG_07_TranslationControl.instTranslationM3.Busy,
    Translation_Done        := PRG_07_TranslationControl.instTranslationM3.Done,

    // Mouvements mâchoires benne (gérés par instBucket)
    Benne_Busy        := PRG_06_WinchControl.instBucket.Busy,
    Benne_Done        := PRG_06_WinchControl.instBucket.Done,
    Benne_IsOpen      := _BucketState.IsOpen,
    Benne_IsClosed    := _BucketState.IsClosed
);

GVL_IHM.Cycle.State.SpeedMismatch_Mps       := instCycle.SpeedMismatchMps;
GVL_IHM.Cycle.State.SpeedMismatchActive     := instCycle.SpeedMismatchActive;
GVL_IHM.Cycle.State.SpeedMismatchConfirmed  := instCycle.SpeedMismatchConfirmed;

// 🧹 Les commandes restent impulsionnelles même si GVL_IHM est RETAIN.
GVL_IHM.Cycle.Cmd.BtnStart := FALSE;
GVL_IHM.Cycle.Cmd.BtnPause := FALSE;
GVL_IHM.Cycle.Cmd.BtnAbort := FALSE;
GVL_IHM.Cycle.Cmd.BtnReset := FALSE;
