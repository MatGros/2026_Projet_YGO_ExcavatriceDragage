(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_03_Modes_Cycle — Gestion, Modes Machine et Séquenceur de Cycle
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après PRG_02_Acquisition).
   📄 Docs : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
            DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   🎯 Rôle unique : Instancier FB_Modes, distribuer le bus ST_fbModes_Autorisations,
      et instancier les 2 séquenceurs de cycle (maintenance + semi-auto).
   ⚠️ Retard d'un scan : FB_Cycle (rang 03) lit les feedbacks de PRG_04/05
      (rangs 04/05) du scan PRÉCÉDENT — documenté, cohérent avec la pratique
      existante (PRG_04 « lag 1 scan »). Les demandes produites sont consommées
      par PRG_04/05 dans le MÊME scan (producteur avant consommateur).
   ═══════════════════════════════════════════════════════════════ *)

PROGRAM PRG_03_Modes_Cycle

VAR_INPUT
    // === 📥 ENTRÉES PROGRAMME (AUCUNE - PILOTÉ VIA GVL_IHM & PRG_02) ===
END_VAR

VAR_OUTPUT
    // === 🎚️ BUS D'AUTORISATIONS & DEMANDES DE CYCLE ===
    Data              : ST_ModesCycleInterPrg;  // <-- [BUS] Structure publique unique du programme de modes et cycle
END_VAR

VAR
    // === 🧩 SOUS-INSTANCES FB INTERNES ===
    instModes              : FB_Modes;              // * [INST] Arbitrage des modes machine et calcul autorisations
    instCycleSemiAuto      : FB_Cycle;              // * [INST] Séquenceur de cycle semi-automatique (privé)
    instDiveSearch         : FB_DiveSearch;         // * [INST] Assistance plongée et recherche fond Kobold
    instExtractionSequence : FB_ExtractionSequence; // * [INST] Séquence d'extraction et remontée assistée

    // === 🎛️ VARIABLES LOCALES & DÉTECTEURS ===
    CoupledUserRequestActive      : BOOL;   // . [LOC] Intention de mouvement couplé active (joystick ou boutons)
    CoupledUserRequestDirection   : INT;    // . [LOC] Sens mouvement couplé (-1: Descente, 0: Neutre, +1: Montée)
    ManualBottomPositionConfirmed : BOOL;   // . [LOC] Confirmation manuelle "fond touché" opérateur
    BottomPositionConfirmed       : BOOL;   // . [LOC] Synthèse fond touché (Kobold OR Manuel OR Bypass)
    BypassKoboldBottomTouched     : BOOL;   // . [LOC] Détection fond sur front Kobold en mode bypass
    BypassKoboldFallEdge          : F_TRIG; // . [LOC] Détecteur front descendant Kobold sous bypass
END_VAR

// === 🔀 §1 ARBITRAGE DES MODES MACHINE & INTENTION OPÉRATEUR ===
{region "§1 Modes machine"}

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

// Qualification de l'intention opérateur couplée (M1+M2) dans le même scan
IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    CoupledUserRequestDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
    CoupledUserRequestActive := PRG_02_Acquisition.HwIn.Operator.JoyBtnRaw
                                     AND (instModes.Auth.JoystickWinchSelectArbitrated = 0);
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        CoupledUserRequestDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        CoupledUserRequestDirection := -1;
    ELSE
        CoupledUserRequestDirection := 0;
    END_IF;
    CoupledUserRequestActive := (CoupledUserRequestDirection <> 0);
END_IF;

{endregion}


// === 🤿 §2 ASSISTANTS DE DRAGAGE (PLONGÉE & EXTRACTION) ===
{region "§2 Assistants de dragage"}

// 1. Garde-clear de la confirmation manuelle et bypass fond touché
IF NOT (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)) THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
    BypassKoboldBottomTouched := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

// 2. Détection front descendant Kobold sous bypass
BypassKoboldFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
IF GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
   AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)
   AND BypassKoboldFallEdge.Q THEN
    BypassKoboldBottomTouched := TRUE;
END_IF;
GVL_IHM.DredgingAssist.State.BypassDiveActive          := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
GVL_IHM.DredgingAssist.State.BypassKoboldBottomTouched := BypassKoboldBottomTouched;

// 3. Instance FB_DiveSearch (Recherche de fond Kobold)
instDiveSearch(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := instModes.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BucketIsOpen := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    KoboldImmersed := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    DiveStartMin_M := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M,
    ImmersionUpper_M := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M,
    ImmersionLower_M := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M,
    BypassPreconditions := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
);

// Synthèse de confirmation fond
BottomPositionConfirmed := instDiveSearch.BottomTouchConfirmed OR ManualBottomPositionConfirmed OR BypassKoboldBottomTouched;
GVL_IHM.DredgingAssist.State.BottomTouchConfirmed := BottomPositionConfirmed;
GVL_IHM.DredgingAssist.State.DiveReady            := instDiveSearch.Ready;
GVL_IHM.DredgingAssist.State.DiveBusy             := instDiveSearch.Lifecycle.Busy;
GVL_IHM.DredgingAssist.State.DiveDone             := instDiveSearch.Lifecycle.Done;
GVL_IHM.DredgingAssist.State.DiveError            := instDiveSearch.Fault.Error;
GVL_IHM.DredgingAssist.State.DiveErrorId          := instDiveSearch.Fault.ErrorId;
GVL_IHM.DredgingAssist.State.DiveState            := instDiveSearch.DiveState;

// 4. Instance FB_ExtractionSequence (Fermeture et décollage assisté)
instExtractionSequence(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := instModes.Auth.Mode,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection := CoupledUserRequestDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    BucketBusy := PRG_04_Treuils_Benne.Data.BucketBusy,
    BucketError := PRG_04_Treuils_Benne.Data.BucketError,
    WinchSyncError := PRG_04_Treuils_Benne.Data.WinchSyncError,
    M1Position_M := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    M1MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M1.SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Acquisition.Data.Encoders.M2.SpeedValid,
    PositionsValid := NOT PRG_02_Acquisition.Data.M1_EncoderFault
                       AND NOT PRG_02_Acquisition.Data.M2_EncoderFault,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M
);

IF instExtractionSequence.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

GVL_IHM.DredgingAssist.State.ExtractionReady   := instExtractionSequence.Ready;
GVL_IHM.DredgingAssist.State.ExtractionBusy    := instExtractionSequence.Lifecycle.Busy;
GVL_IHM.DredgingAssist.State.ExtractionDone    := instExtractionSequence.Lifecycle.Done;
GVL_IHM.DredgingAssist.State.ExtractionError   := instExtractionSequence.Fault.Error;
GVL_IHM.DredgingAssist.State.ExtractionErrorId := instExtractionSequence.Fault.ErrorId;
GVL_IHM.DredgingAssist.State.ExtractionState   := instExtractionSequence.ExtractionState;

{endregion}


// === 🔄 §3 SÉQUENCEUR DE CYCLE SEMI-AUTOMATIQUE ===
{region "§3 Séquenceur de cycle"}
// 🕹️ CycleMotionPermit = manche défléchi (non centré) — D2
// ⚠️ Entrées consommées sur les bus publics Data (retard N-1 admis AF-02) :

instCycleSemiAuto(
    Enable                  := (instModes.Auth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := GVL_IHM.Cycle.Cmd.BtnReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode                    := instModes.Auth.Mode,
    CycleMotionPermit       := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    DeadmanArmed            := PRG_02_Acquisition.Data.JoystickDeadmanArmed,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    StartCycle              := GVL_IHM.Cycle.Cmd.BtnStart,
    AbortCycle              := GVL_IHM.Cycle.Cmd.BtnAbort,
    SelTarget               := GVL_IHM.TranslationM3.Cmd.SelTarget,
    SetDepthM               := GVL_IHM.Cycle.Cfg.SetDepth_M,
    SetOffsetM              := GVL_IHM.Cycle.Cfg.SetOffset_M,
    KoboldContactFond       := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    LimitLegalReached       := GVL_IHM.Commun.LimitLegalReached,
    LimitLegalDepthM        := _CommunCfgPersist.LimitLegalDepthMinAllowed_M,
    WinchSyncError          := PRG_04_Treuils_Benne.Data.WinchSyncError,
    WinchSyncDeltaM         := PRG_04_Treuils_Benne.Data.WinchSyncSignedDeltaPosM,
    M1_CablePosM            := PRG_02_Acquisition.Data.Encoders.M1.CablePosM,
    M2_CablePosM            := PRG_02_Acquisition.Data.Encoders.M2.CablePosM,
    M1_MeasuredSpeedMps     := PRG_02_Acquisition.Data.Encoders.M1.Speed_Mps,
    M2_MeasuredSpeedMps     := PRG_02_Acquisition.Data.Encoders.M2.Speed_Mps,
    SpeedMismatchThresholdMps := 1.5,   // Seuil écart vitesse M1/M2 (revue : ~1-2 m/s, retenu 1.5)
    SpeedMismatchTimeout    := T#500ms, // Tempo confirmation écart vitesse (revue)
    CableLimitM1AscentM     := _CommunCfgPersist.CfgCableLimitAscent_M,
    Translation_At_P1       := PRG_05_Translation.Data.M3_AtP1Stable,
    Translation_At_Tremie   := PRG_05_Translation.Data.M3_AtTremieStable,
    Translation_At_Maintenance := PRG_05_Translation.Data.M3_AtMaintenanceStable,
    Translation_Busy        := PRG_05_Translation.Data.TranslationBusy,
    Translation_Done        := PRG_05_Translation.Data.TranslationDone,
    Benne_Busy              := PRG_04_Treuils_Benne.Data.BucketBusy,
    Benne_Done              := PRG_04_Treuils_Benne.Data.BucketDone,
    Benne_IsOpen            := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    Benne_IsClosed          := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    Benne_IsRoughlyClosed   := PRG_04_Treuils_Benne.Data.Benne_IsRoughlyClosed,  // Tolérance matière 2m
    HomedM1                 := PRG_02_Acquisition.Data.EncoderM1.Homed,
    HomedM2                 := PRG_02_Acquisition.Data.EncoderM2.Homed,
    TopPositionSensor       := PRG_02_Acquisition.HwIn.Winch.M1M2_TopPositionFree_DI,
    HomingRequest           := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHome,
    SampleCount            := _CycleSampleCount
);

{endregion}


// === 📤 §4 PUBLICATION DU BUS INTER-PRG & AUTORISATIONS ===
{region "§4 Publication bus public"}

// 1. Autorisations machine
Data.Auth := instModes.Auth;

// 2. Demandes programme et état public de séquence
IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Demandes treuils M1 / M2
    Data.ReqProgram.ReqWinchM1.ReqStartStop := instCycleSemiAuto.WinchM1Cmd.StartStop;
    Data.ReqProgram.ReqWinchM1.ReqDirection := instCycleSemiAuto.WinchM1Cmd.Direction;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := instCycleSemiAuto.WinchM1Cmd.SpeedPct;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := instCycleSemiAuto.WinchM2Cmd.StartStop;
    Data.ReqProgram.ReqWinchM2.ReqDirection := instCycleSemiAuto.WinchM2Cmd.Direction;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := instCycleSemiAuto.WinchM2Cmd.SpeedPct;

    // Demande translation M3
    Data.ReqProgram.ReqTranslation.ReqStart    := instCycleSemiAuto.TranslationCmd.Start;
    Data.ReqProgram.ReqTranslation.PositionTgt := instCycleSemiAuto.TranslationCmd.Target;

    // Demande benne
    Data.ReqProgram.ReqBucket.ReqOpen                     := instCycleSemiAuto.BucketCmd.Open;
    Data.ReqProgram.ReqBucket.ReqClose                    := instCycleSemiAuto.BucketCmd.Close;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable      := instCycleSemiAuto.BucketCmd.KoboldContactorCmd;
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := TRUE;
    Data.ReqProgram.ReqBucket.ForceMinSpeedStep           := FALSE;

    // État séquence active
    IF instCycleSemiAuto.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId := E_ProgramSequence.MAIN_CYCLE;
    ELSE
        Data.SequenceState.SequenceId := E_ProgramSequence.NONE;
    END_IF;

    Data.SequenceState.Ready                  := instCycleSemiAuto.Ready;
    Data.SequenceState.Lifecycle              := instCycleSemiAuto.Lifecycle;
    Data.SequenceState.Fault                  := instCycleSemiAuto.Fault;
    Data.SequenceState.Step                   := instCycleSemiAuto.CycleStep;
    Data.SequenceState.StepStr                := instCycleSemiAuto.CycleStateStr;
    Data.SequenceState.StepAtFault            := instCycleSemiAuto.CycleStepAtError;
    Data.SequenceState.OperatorActionId       := instCycleSemiAuto.OperatorActionId;
    Data.SequenceState.OperatorAction         := instCycleSemiAuto.OperatorAction;
    Data.SequenceState.ExpectedAxis           := instCycleSemiAuto.ExpectedAxis;
    Data.SequenceState.ExpectedDirection      := instCycleSemiAuto.ExpectedDirection;
    Data.SequenceState.WaitingForOperator     := instCycleSemiAuto.WaitingForOperator;
    Data.SequenceState.WaitingForProcess      := instCycleSemiAuto.WaitingForProcess;
    Data.SequenceState.RequestActive          := instCycleSemiAuto.RequestActive;
    Data.SequenceState.SpeedMismatchMps       := instCycleSemiAuto.SpeedMismatchMps;
    Data.SequenceState.SpeedMismatchActive    := instCycleSemiAuto.SpeedMismatchActive;
    Data.SequenceState.SpeedMismatchConfirmed := instCycleSemiAuto.SpeedMismatchConfirmed;
    Data.SequenceState.DiveState              := E_DiveSearchState.WAIT_PRECONDITIONS;
    Data.SequenceState.BottomTouchConfirmed   := FALSE;
    Data.SequenceState.ExtractionState        := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;

ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2) THEN
    // Mode Manuel / Maintenance : Publication des requêtes issues des assistants
    Data.ReqProgram.ReqWinchM1.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqTranslation.ReqStart    := FALSE;
    Data.ReqProgram.ReqTranslation.PositionTgt := 0;

    // Requêtes benne et assistants
    Data.ReqProgram.ReqBucket.ReqOpen                     := FALSE;
    Data.ReqProgram.ReqBucket.ReqClose                    := instExtractionSequence.BucketCloseRequest;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable      := instDiveSearch.KoboldMeasureEnable
                                                            OR (GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
                                                                AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1));
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := NOT (instDiveSearch.Enable AND CoupledUserRequestActive
                                                                AND (CoupledUserRequestDirection = -1)
                                                                AND NOT PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen);
    Data.ReqProgram.ReqBucket.ForceMinSpeedStep           := instExtractionSequence.ForceMinSpeedStep;

    // États de séquence
    IF instDiveSearch.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId        := E_ProgramSequence.DIVE_SEARCH;
        Data.SequenceState.OperatorActionId  := instDiveSearch.OperatorActionId;
        Data.SequenceState.OperatorAction    := instDiveSearch.OperatorAction;
    ELSIF instExtractionSequence.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId        := E_ProgramSequence.EXTRACTION;
        Data.SequenceState.OperatorActionId  := instExtractionSequence.OperatorActionId;
        Data.SequenceState.OperatorAction    := instExtractionSequence.OperatorAction;
    ELSE
        Data.SequenceState.SequenceId        := E_ProgramSequence.NONE;
        Data.SequenceState.OperatorActionId  := 0;
        Data.SequenceState.OperatorAction    := '';
    END_IF;

    Data.SequenceState.Ready                  := instDiveSearch.Ready OR instExtractionSequence.Ready;
    Data.SequenceState.Lifecycle.Busy         := instDiveSearch.Lifecycle.Busy OR instExtractionSequence.Lifecycle.Busy;
    Data.SequenceState.Lifecycle.Done         := instDiveSearch.Lifecycle.Done OR instExtractionSequence.Lifecycle.Done;
    Data.SequenceState.Fault.Error            := instDiveSearch.Fault.Error OR instExtractionSequence.Fault.Error;
    IF instDiveSearch.Fault.Error THEN
        Data.SequenceState.Fault.ErrorId      := instDiveSearch.Fault.ErrorId;
    ELSIF instExtractionSequence.Fault.Error THEN
        Data.SequenceState.Fault.ErrorId      := instExtractionSequence.Fault.ErrorId;
    ELSE
        Data.SequenceState.Fault.ErrorId      := 0;
    END_IF;
    Data.SequenceState.Fault.Latched          := instDiveSearch.Fault.Latched OR instExtractionSequence.Fault.Latched;
    Data.SequenceState.Step                   := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.StepStr                := 'ASSIST_MODE';
    Data.SequenceState.StepAtFault            := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.ExpectedAxis           := E_OperatorAxis.JOYSTICK_Y;
    Data.SequenceState.ExpectedDirection      := CoupledUserRequestDirection;
    Data.SequenceState.WaitingForOperator     := FALSE;
    Data.SequenceState.WaitingForProcess      := FALSE;
    Data.SequenceState.RequestActive          := CoupledUserRequestActive;
    Data.SequenceState.SpeedMismatchMps       := 0.0;
    Data.SequenceState.SpeedMismatchActive    := FALSE;
    Data.SequenceState.SpeedMismatchConfirmed := FALSE;
    Data.SequenceState.DiveState              := instDiveSearch.DiveState;
    Data.SequenceState.BottomTouchConfirmed   := BottomPositionConfirmed;
    Data.SequenceState.ExtractionState        := instExtractionSequence.ExtractionState;

    // Miroir pour GVL_IHM.DredgingAssist.State.OperatorActionId
    GVL_IHM.DredgingAssist.State.OperatorActionId := Data.SequenceState.OperatorActionId;
    GVL_IHM.DredgingAssist.State.OperatorAction   := Data.SequenceState.OperatorAction;

ELSE
    // Neutralisation déterministe (DISABLE)
    Data.ReqProgram.ReqWinchM1.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM1.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqWinchM2.ReqStartStop := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDirection := 0;
    Data.ReqProgram.ReqWinchM2.SpeedTgtPct  := 0.0;

    Data.ReqProgram.ReqTranslation.ReqStart    := FALSE;
    Data.ReqProgram.ReqTranslation.PositionTgt := 0;

    Data.ReqProgram.ReqBucket.ReqOpen                     := FALSE;
    Data.ReqProgram.ReqBucket.ReqClose                    := FALSE;
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable      := FALSE;
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := TRUE;
    Data.ReqProgram.ReqBucket.ForceMinSpeedStep           := FALSE;

    Data.SequenceState.SequenceId              := E_ProgramSequence.NONE;
    Data.SequenceState.Ready                   := FALSE;
    Data.SequenceState.Lifecycle.Busy          := FALSE;
    Data.SequenceState.Lifecycle.Done          := FALSE;
    Data.SequenceState.Fault.Error             := FALSE;
    Data.SequenceState.Fault.ErrorId           := 0;
    Data.SequenceState.Fault.Latched           := FALSE;
    Data.SequenceState.Step                    := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.StepStr                 := 'X0_PREPARATION';
    Data.SequenceState.StepAtFault             := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.OperatorActionId        := 0;
    Data.SequenceState.OperatorAction          := '';
    Data.SequenceState.ExpectedAxis            := E_OperatorAxis.NONE;
    Data.SequenceState.ExpectedDirection       := 0;
    Data.SequenceState.WaitingForOperator      := FALSE;
    Data.SequenceState.WaitingForProcess       := FALSE;
    Data.SequenceState.RequestActive           := FALSE;
    Data.SequenceState.SpeedMismatchMps        := 0.0;
    Data.SequenceState.SpeedMismatchActive     := FALSE;
    Data.SequenceState.SpeedMismatchConfirmed  := FALSE;
    Data.SequenceState.DiveState              := E_DiveSearchState.WAIT_PRECONDITIONS;
    Data.SequenceState.BottomTouchConfirmed   := FALSE;
    Data.SequenceState.ExtractionState        := E_ExtractionSequenceState.WAIT_BOTTOM_CONFIRMATION;

    GVL_IHM.DredgingAssist.State.OperatorActionId := 0;
    GVL_IHM.DredgingAssist.State.OperatorAction   := '';
END_IF;

{endregion}

END_PROGRAM
