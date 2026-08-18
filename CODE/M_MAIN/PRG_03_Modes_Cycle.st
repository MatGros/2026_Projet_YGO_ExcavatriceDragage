(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_03_Modes_Cycle — Gestion, Modes Machine et Séquenceur de Cycle
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après PRG_02_Acquisition).
   📄 Docs : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.0.md
            DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md
   🎯 Rôle unique : Instancier FB_Modes, distribuer le bus ST_Modes_Autorisations,
      et instancier les 2 séquenceurs de cycle (maintenance + semi-auto).
   ⚠️ Retard d'un scan : FB_Cycle (rang 03) lit les feedbacks de PRG_04/05
      (rangs 04/05) du scan PRÉCÉDENT — documenté, cohérent avec la pratique
      existante (PRG_04 « lag 1 scan »). Les demandes produites sont consommées
      par PRG_04/05 dans le MÊME scan (producteur avant consommateur).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Modes_Cycle

VAR
    instModes : FB_Modes;  // Arbitrage mode + bus autorisations
END_VAR

VAR_OUTPUT
    Auth : ST_Modes_Autorisations;  // Bus d'autorisations (producteur unique)
    // Deux instances du séquenceur de cycle (D1) — gating sorties par mode.
    // ⚠️ VAR_OUTPUT (pas VAR) : PRG_04/05 y accèdent via PRG_03_Modes_Cycle.instCycleSemiAuto
    // (une variable locale d'un PROGRAM n'est pas accessible depuis un autre PROGRAM).
    instCycleMaintenance : FB_Cycle;  // utilisé en MAINT_N1/N2
    instCycleSemiAuto    : FB_Cycle;  // utilisé en SEMI_AUTO
END_VAR

// === 🔀 §1 ARBITRAGE DES MODES MACHINE ===

instModes(
    Enable                  := TRUE,
    Reset                   := GVL_IHM.Modes.Cmd.BtnModeReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    SelMode                 := GVL_IHM.Modes.Cmd.SelMode,
    SelSyncEnable           := GVL_IHM.M1M2Sync.Cmd.SelSyncEnable,
    InhibitM1Request        := GVL_IHM.M1TreuilRetenue.Cmd.BtnInhibit,
    InhibitM2Request        := GVL_IHM.M2TreuilBenne.Cmd.BtnInhibit,
    SelHomingApproachEnable := GVL_IHM.Commun.Cfg.SelHomingApproachEnable,
    EncoderFaultPresent     := (PRG_02_Acquisition.HwIn.Winch.COD1_DeviceState <> DEVICE_STATE.RUNNING) OR (PRG_02_Acquisition.HwIn.Winch.COD2_DeviceState <> DEVICE_STATE.RUNNING),
    JoystickWinchSelectRequest := GVL_IHM.Modes.Cmd.SelJoystickWinch,
    SelMaintenanceZoneAccess := GVL_IHM.TranslationM3.Cmd.TglMaintenanceZoneAccess
);


// === 🔄 §2 SÉQUENCEURS DE CYCLE (2 instances, D1) ===
// 🕹️ CycleMotionPermit = manche défléchi (non centré) — D2
// ⚠️ Entrées sans source définie câblées en fail-safe documenté :
//    - SpeedMismatchThresholdMps := 0 / SpeedMismatchTimeout := T#0ms (contrôle désactivé)
//    - Benne_IsRoughlyClosed := Benne_IsClosed (fallback sûr : exige fermé)
//    - HomingRequest := bouton homing IHM (BtnHome M1 OU M2)

instCycleMaintenance(
    Enable                  := (Auth.Mode = E_Mode.MAINT_N1 OR Auth.Mode = E_Mode.MAINT_N2),
    Reset                   := GVL_IHM.Cycle.Cmd.BtnReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := Auth.Mode,
    CycleMotionPermit       := NOT PRG_02_Acquisition.instJoystick.AtNeutral,
    DeadmanArmed            := PRG_02_Acquisition.JoystickDeadmanArmed,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    StartCycle              := GVL_IHM.Cycle.Cmd.BtnStart,
    AbortCycle              := GVL_IHM.Cycle.Cmd.BtnAbort,
    SelTarget               := GVL_IHM.TranslationM3.Cmd.SelTarget,
    SetDepthM               := GVL_IHM.Cycle.Cfg.SetDepth_M,
    SetOffsetM              := GVL_IHM.Cycle.Cfg.SetOffset_M,
    KoboldContactFond       := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    LimitLegalReached       := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM        := _CommunCfgPersist.LimitLegalDepthMinAllowed_M,
    WinchSyncError          := PRG_04_Treuils_Benne.instWinchSync.Error,
    WinchSyncDeltaM         := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM,
    M1_CablePosM            := PRG_02_Acquisition.CablePosM1,
    M2_CablePosM            := PRG_02_Acquisition.CablePosM2,
    M1_MeasuredSpeedMps     := PRG_02_Acquisition.M1_Speed_Mps,
    M2_MeasuredSpeedMps     := PRG_02_Acquisition.M2_Speed_Mps,
    SpeedMismatchThresholdMps := 1.5,   // Seuil écart vitesse M1/M2 (revue : ~1-2 m/s, retenu 1.5)
    SpeedMismatchTimeout    := T#500ms, // Tempo confirmation écart vitesse (revue)
    CableLimitM1AscentM     := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    Translation_At_P1       := PRG_05_Translation.M3_AtP1Stable,
    Translation_At_Tremie   := PRG_05_Translation.M3_AtTremieStable,
    Translation_At_Maintenance := PRG_05_Translation.M3_AtMaintenanceStable,
    Translation_Busy        := PRG_05_Translation.instTranslationM3.Busy,
    Translation_Done        := PRG_05_Translation.instTranslationM3.Done,
    Benne_Busy              := PRG_04_Treuils_Benne.instBucket.Busy,
    Benne_Done              := PRG_04_Treuils_Benne.instBucket.Done,
    Benne_IsOpen            := PRG_04_Treuils_Benne.BucketState.MechState.IsOpen,
    Benne_IsClosed          := PRG_04_Treuils_Benne.BucketState.MechState.IsClosed,
    Benne_IsRoughlyClosed   := PRG_04_Treuils_Benne.Benne_IsRoughlyClosed,  // Tolérance matière 2m
    HomedM1                 := PRG_02_Acquisition.instHomingM1.Homed,
    HomedM2                 := PRG_02_Acquisition.instHomingM2.Homed,
    TopPositionSensor       := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    HomingRequest           := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHome,
    SampleCount            := _CycleSampleCount
);

instCycleSemiAuto(
    Enable                  := (Auth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := GVL_IHM.Cycle.Cmd.BtnReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := Auth.Mode,
    CycleMotionPermit       := NOT PRG_02_Acquisition.instJoystick.AtNeutral,
    DeadmanArmed            := PRG_02_Acquisition.JoystickDeadmanArmed,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    StartCycle              := GVL_IHM.Cycle.Cmd.BtnStart,
    AbortCycle              := GVL_IHM.Cycle.Cmd.BtnAbort,
    SelTarget               := GVL_IHM.TranslationM3.Cmd.SelTarget,
    SetDepthM               := GVL_IHM.Cycle.Cfg.SetDepth_M,
    SetOffsetM              := GVL_IHM.Cycle.Cfg.SetOffset_M,
    KoboldContactFond       := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    LimitLegalReached       := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM        := _CommunCfgPersist.LimitLegalDepthMinAllowed_M,
    WinchSyncError          := PRG_04_Treuils_Benne.instWinchSync.Error,
    WinchSyncDeltaM         := PRG_04_Treuils_Benne.instWinchSync.SignedDeltaPosM,
    M1_CablePosM            := PRG_02_Acquisition.CablePosM1,
    M2_CablePosM            := PRG_02_Acquisition.CablePosM2,
    M1_MeasuredSpeedMps     := PRG_02_Acquisition.M1_Speed_Mps,
    M2_MeasuredSpeedMps     := PRG_02_Acquisition.M2_Speed_Mps,
    SpeedMismatchThresholdMps := 1.5,   // Seuil écart vitesse M1/M2 (revue : ~1-2 m/s, retenu 1.5)
    SpeedMismatchTimeout    := T#500ms, // Tempo confirmation écart vitesse (revue)
    CableLimitM1AscentM     := _WinchM1CfgPersist.CfgCableLimitAscent_M,
    Translation_At_P1       := PRG_05_Translation.M3_AtP1Stable,
    Translation_At_Tremie   := PRG_05_Translation.M3_AtTremieStable,
    Translation_At_Maintenance := PRG_05_Translation.M3_AtMaintenanceStable,
    Translation_Busy        := PRG_05_Translation.instTranslationM3.Busy,
    Translation_Done        := PRG_05_Translation.instTranslationM3.Done,
    Benne_Busy              := PRG_04_Treuils_Benne.instBucket.Busy,
    Benne_Done              := PRG_04_Treuils_Benne.instBucket.Done,
    Benne_IsOpen            := PRG_04_Treuils_Benne.BucketState.MechState.IsOpen,
    Benne_IsClosed          := PRG_04_Treuils_Benne.BucketState.MechState.IsClosed,
    Benne_IsRoughlyClosed   := PRG_04_Treuils_Benne.Benne_IsRoughlyClosed,  // Tolérance matière 2m
    HomedM1                 := PRG_02_Acquisition.instHomingM1.Homed,
    HomedM2                 := PRG_02_Acquisition.instHomingM2.Homed,
    TopPositionSensor       := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    HomingRequest           := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHome,
    SampleCount            := _CycleSampleCount
);


// === 📤 §3 PUBLICATION DU BUS AUTORISATIONS ===

Auth := instModes.Auth;

END_PROGRAM
