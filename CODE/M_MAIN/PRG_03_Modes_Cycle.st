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
    instExtractionAssist : FB_ExtractionAssist; // * [INST] Séquence d'extraction et remontée assistée

    // === 🎛️ VARIABLES LOCALES & DÉTECTEURS ===
    DiveSearchInputs           : ST_fbDiveSearch_Inputs; // . [LOC] Bus d'entrée struct FB_DiveSearch (interface refactorée)
    WinchBothMotionActive      : BOOL;   // . [LOC] Intention de mouvement both active (joystick ou boutons)
    WinchBothMotionDirection   : INT;    // . [LOC] Sens mouvement both (-1: Descending, 0: Neutre, +1: Ascending)
    ManualBottomPositionConfirmed : BOOL;   // . [LOC] Confirmation manuelle "fond touché" opérateur
    BottomPositionConfirmed       : BOOL;   // . [LOC] Synthèse fond touché (Kobold OR Manuel OR Bypass)
    BypassKoboldBottomTouched     : BOOL;   // . [LOC] Détection fond sur front Kobold en mode bypass
    BypassKoboldFallEdge          : F_TRIG; // . [LOC] Détecteur front descendant Kobold sous bypass
    DumpAtTremieActive            : BOOL;   // . [LOC] Option vidage à la trémie activée IHM
    DumpAtTremieAssistActive      : BOOL;   // . [LOC] Assistance vidage trémie active
    DumpAtTremieBucketOpenArmed   : BOOL;   // . [LOC] Armement ouverture benne à la trémie
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
    SelMaintenanceZoneAccess := GVL_IHM.TranslationM3.Cmd.TglMaintenanceZoneAccess,
    // Arrêt mécanique confirmé des treuils (condition de bascule N1/N2, AF-05 §4bis)
    M1ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M1_ContactorsReleased_DI,
    M1BrakeIsOpen             := PRG_02_Acquisition.HwIn.Winch.M1_BrakeIsOpen_DI,
    M1SpeedAbsMps             := PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps,
    M2ContactorsReleased      := PRG_02_Acquisition.HwIn.Winch.M2_ContactorsReleased_DI,
    M2BrakeIsOpen             := PRG_02_Acquisition.HwIn.Winch.M2_BrakeIsOpen_DI,
    M2SpeedAbsMps             := PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps,
    // États homing (levée du re-homing obligatoire)
    M1HomingDone              := PRG_02_Acquisition.Data.EncoderM1.Measurement.HomingLifecycle.Done,
    M1Homed                   := PRG_02_Acquisition.Data.EncoderM1.Homed,
    M1HomingSuspect           := PRG_02_Acquisition.Data.EncoderM1.HomingSuspect,
    M2HomingDone              := PRG_02_Acquisition.Data.EncoderM2.Measurement.HomingLifecycle.Done,
    M2Homed                   := PRG_02_Acquisition.Data.EncoderM2.Homed,
    M2HomingSuspect           := PRG_02_Acquisition.Data.EncoderM2.HomingSuspect,
    // Usage effectif d'un override/bypass de position (producteur PRG_04, lag 1 scan
    // assumé : PRG_04 est de rang 04, ce programme de rang 03)
    M1PositionLimitOverridden := PRG_04_Treuils_Benne.Data.PositionLimitOverriddenM1,
    M2PositionLimitOverridden := PRG_04_Treuils_Benne.Data.PositionLimitOverriddenM2,
    MachineHomed     := PRG_02_Acquisition.Data.MachineHoming.Homed,
    // Restauration boot des drapeaux de re-homing (miroir PERSISTENT)
    BootHomingRequiredM1      := GVL_PERSISTENT._MaintM1HomingRequired,
    BootHomingRequiredM2      := GVL_PERSISTENT._MaintM2HomingRequired
);

// Miroir persistant du re-homing obligatoire (pattern FB_MirrorBypassRetain) :
// FB_Modes est le producteur unique de la décision ; GVL_PERSISTENT n'est que la mémoire.
GVL_PERSISTENT._MaintM1HomingRequired := instModes.Auth.HomingRequiredM1;
GVL_PERSISTENT._MaintM2HomingRequired := instModes.Auth.HomingRequiredM2;

// Qualification de l'intention opérateur both (M1+M2) dans le même scan.
// Homme-mort QUALIFIÉ (Data.Joystick.DeadmanArmed) — même source que l'arbitrage
// (Joystick.DeadmanArmed) : les assistants et la commande réelle partagent
// la même décision, plus de divergence raw/qualifié.
IF GVL_IHM.Modes.Cmd.TglJoystickMaster THEN
    WinchBothMotionDirection := PRG_02_Acquisition.Data.Joystick.AxisY.Direction;
    WinchBothMotionActive := PRG_02_Acquisition.Data.Joystick.DeadmanArmed
                                     AND (instModes.Auth.JoystickWinchSelectArbitrated = 0);
ELSE
    IF GVL_IHM.Commun.BtnWinchBothUp THEN
        WinchBothMotionDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDown THEN
        WinchBothMotionDirection := -1;
    ELSE
        WinchBothMotionDirection := 0;
    END_IF;
    WinchBothMotionActive := (WinchBothMotionDirection <> 0);
END_IF;

{endregion}


// === 🤿 §2 ASSISTANTS DE DRAGAGE (PLONGÉE & EXTRACTION) ===
{region "§2 Assistants de dragage"}

// 1. Garde-clear de la confirmation manuelle et bypass fond touché
IF NOT (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
   OR NOT PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI
   OR PRG_07_Supervision.FaultMachineReset_IHM
   OR (WinchBothMotionActive AND (WinchBothMotionDirection = -1)) THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
    BypassKoboldBottomTouched := FALSE;
END_IF;
ManualBottomPositionConfirmed := GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed;

// 2. Détection front descendant Kobold sous bypass
BypassKoboldFallEdge(CLK := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI);
IF GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
   AND WinchBothMotionActive AND (WinchBothMotionDirection = -1)
   AND BypassKoboldFallEdge.Q THEN
    BypassKoboldBottomTouched := TRUE;
END_IF;

// 3. Instance FB_DiveSearch (Recherche de fond Kobold)
// Interface refactorée en bus struct : remplissage champ par champ du bus d'entrée
// (CODESYS 3.5 refuse l'init anonyme en appel), puis passage via Inputs := DiveSearchInputs.
DiveSearchInputs.PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI;
DiveSearchInputs.Mode                  := instModes.Auth.Mode;
DiveSearchInputs.MotionRequestActive   := WinchBothMotionActive;
DiveSearchInputs.MotionDirection       := WinchBothMotionDirection;
DiveSearchInputs.BucketIsOpen          := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen;
DiveSearchInputs.KoboldImmersed        := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI;
DiveSearchInputs.M1Position_M          := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM;
DiveSearchInputs.M2Position_M          := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM;
DiveSearchInputs.PositionsValid        := NOT PRG_02_Acquisition.Data.EncoderM1.EncoderFault
                                          AND NOT PRG_02_Acquisition.Data.EncoderM2.EncoderFault;
// Palier actuel M1 reellement commande (public PRG_04 §8). PRG_03 est de rang 03,
// PRG_04 de rang 04 : lecture du scan PRECEDENT (lag 1 scan assume, meme pratique que
// le reste de PRG_03). Rend effectif le refus interne du Palier 5 en plongee Kobold.
DiveSearchInputs.CurrentSpeedStep      := PRG_04_Treuils_Benne.Data.WinchM1State.StepNumber;
DiveSearchInputs.DiveStartMin_M        := GVL_IHM.DredgingAssist.Cfg.DiveStartMin_M;
DiveSearchInputs.ImmersionUpper_M      := GVL_IHM.DredgingAssist.Cfg.ImmersionUpper_M;
DiveSearchInputs.ImmersionLower_M      := GVL_IHM.DredgingAssist.Cfg.ImmersionLower_M;
DiveSearchInputs.CableLimitAscent_M    := GVL_IHM.Commun.Cfg.CfgCableLimitAscent_M;
DiveSearchInputs.LimitLegalDepthMin_M  := GVL_IHM.Commun.Cfg.LimitLegalDepthMinAllowed_M;
// Plancher palier descente Kobold : non rendu reglable IHM, valeur roadmap 3.
DiveSearchInputs.CfgDiveFloorStep      := 3;
DiveSearchInputs.CycleTime             := T#10ms;
DiveSearchInputs.BypassPreconditions   := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
// Config : defaults du DUT ST_fbDiveSearch_Config conserves (DiveSpeedMin_Mps=0.15,
// TimeoutMarginFactor=1.5, TimeoutMinCourse_M=1.0, TimeoutMaxCourse_M=200.0, SecToMs=1000.0).

instDiveSearch(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableDiveSearch,
    Reset  := PRG_07_Supervision.FaultMachineReset_IHM,
    Inputs := DiveSearchInputs
);

// Synthèse de confirmation fond
BottomPositionConfirmed := instDiveSearch.Outputs.BottomTouchConfirmed OR ManualBottomPositionConfirmed OR BypassKoboldBottomTouched;

// 4. Instance FB_ExtractionAssist (Fermeture et décollage assisté)
instExtractionAssist(
    Enable := (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2)
              AND GVL_IHM.DredgingAssist.Cmd.TglEnableExtractionSequence,
    Reset := PRG_07_Supervision.FaultMachineReset_IHM,
    PowerContactorEngaged := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    Mode := instModes.Auth.Mode,
    MotionRequestActive := WinchBothMotionActive,
    MotionDirection := WinchBothMotionDirection,
    BottomPositionConfirmed := BottomPositionConfirmed,
    BucketIsClosed := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
    BucketBusy := PRG_04_Treuils_Benne.Data.BucketBusy,
    BucketError := PRG_04_Treuils_Benne.Data.BucketError,
    WinchSyncError := PRG_04_Treuils_Benne.Data.WinchSyncError,
    M1Position_M := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
    M2Position_M := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
    M1MeasuredSpeedValid := PRG_02_Acquisition.Data.EncoderM1.Measurement.SpeedValid,
    M2MeasuredSpeedValid := PRG_02_Acquisition.Data.EncoderM2.Measurement.SpeedValid,
    PositionsValid := NOT PRG_02_Acquisition.Data.EncoderM1.EncoderFault
                       AND NOT PRG_02_Acquisition.Data.EncoderM2.EncoderFault,
    ControlAscentDistance_M := GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M,
    CfgBucketCloseTimeout := T#75s,
    BucketMoveTimeout := GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration,
    CycleTime := T#10ms
);

IF instExtractionAssist.BottomConfirmationConsumed THEN
    GVL_IHM.DredgingAssist.Cmd.TglBucketAtBottomConfirmed := FALSE;
END_IF;

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
    DeadmanArmed            := PRG_02_Acquisition.Data.Joystick.DeadmanArmed,
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
    M1_CablePosM            := PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM,
    M2_CablePosM            := PRG_02_Acquisition.Data.EncoderM2.Measurement.CablePosM,
    M1_MeasuredSpeedMps     := PRG_02_Acquisition.Data.EncoderM1.Measurement.Speed_Mps,
    M2_MeasuredSpeedMps     := PRG_02_Acquisition.Data.EncoderM2.Measurement.Speed_Mps,
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
// 1bis. Défauts de l'arbitre de mode (refus Semi-Auto, changement de mode refusé) —
// publiés pour que l'IHM les affiche : un interlock invisible est un interlock contourné.
Data.ModesFault := instModes.Fault;

// 1bis. Intention both continue opérateur (inconditionnelle, TOUS modes) — source unique
Data.WinchBothIntent.Active    := WinchBothMotionActive;
Data.WinchBothIntent.Direction := WinchBothMotionDirection;

// 2. Demandes programme et état public de séquence
IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Demandes treuils M1 / M2 — copie struct entière : FB_Cycle produit directement
    // le type de contrat inter-PRG (ST_Program*Request). Plus de re-mapping
    // champ-à-champ ni de DUT ST_fbCycle_*CmdDemand redondants (NC-090).
    Data.ReqProgram.ReqWinchM1 := instCycleSemiAuto.WinchM1Cmd;
    Data.ReqProgram.ReqWinchM2 := instCycleSemiAuto.WinchM2Cmd;

    // Demande translation M3
    Data.ReqProgram.ReqTranslation := instCycleSemiAuto.TranslationCmd;

    // Demande benne — FB_Cycle fournit aussi les champs assistants neutres
    // (DescendPermitDiveBucketOpen=TRUE, ExtractionControlActive=FALSE, AscentPermit=FALSE, MinStepDown=0).
    Data.ReqProgram.ReqBucket := instCycleSemiAuto.BucketCmd;

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
    Data.SequenceState.DiveStepAtFault        := E_DiveSearchState.WAIT_PRECONDITIONS;
    Data.SequenceState.BottomTouchConfirmed   := FALSE;
    Data.SequenceState.ExtractionState        := E_ExtractionAssistState.WAIT_BOTTOM_CONFIRMATION;
    Data.SequenceState.ExtractionStepAtFault  := E_ExtractionAssistState.WAIT_BOTTOM_CONFIRMATION;

    // === RESET ÉTATS ASSISTANTS (neutralisation déterministe au passage SEMI_AUTO) ===
    // Aucun assistant de dragage n'est actif en SEMI_AUTO : mêmes valeurs neutres que la branche DISABLE.
    Data.SequenceState.DiveReady                  := FALSE;
    Data.SequenceState.DiveBusy                   := FALSE;
    Data.SequenceState.DiveDone                   := FALSE;
    Data.SequenceState.DiveError                  := FALSE;
    Data.SequenceState.DiveErrorId                := 0;
    Data.SequenceState.ExtractionReady             := FALSE;
    Data.SequenceState.ExtractionBusy              := FALSE;
    Data.SequenceState.ExtractionDone              := FALSE;
    Data.SequenceState.ExtractionError             := FALSE;
    Data.SequenceState.ExtractionErrorId           := 0;
    Data.SequenceState.DumpAtTremieArmed           := FALSE;
    Data.SequenceState.DumpAtTremieAssistActive      := FALSE;
    Data.SequenceState.DumpAtTremieAtTremie          := FALSE;
    Data.SequenceState.DumpAtTremieBucketOpenArmed   := FALSE;
    Data.SequenceState.DumpAtTremieDescentLocked     := FALSE;
    Data.SequenceState.BypassDiveActive            := FALSE;
    Data.SequenceState.BypassKoboldBottomTouched   := FALSE;

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
    DumpAtTremieActive := GVL_IHM.DredgingAssist.Cmd.TglEnableDumpAtTremie;
    DumpAtTremieAssistActive := DumpAtTremieActive;
    DumpAtTremieBucketOpenArmed := DumpAtTremieAssistActive AND PRG_05_Translation.Data.M3_AtTremieStable;

    Data.ReqProgram.ReqBucket.ReqOpen                     := DumpAtTremieBucketOpenArmed;
    Data.ReqProgram.ReqBucket.ReqClose                    := instExtractionAssist.BucketCloseRequest;
    // Contacteur Kobold : sortie FB_DiveSearch consommee (plus de recalcul inline).
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable      := instDiveSearch.Outputs.KoboldContactorCmd
                                                            OR (GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence
                                                                AND WinchBothMotionActive AND (WinchBothMotionDirection = -1));
    // Permis de descente plongee : sortie FB_DiveSearch consommee. Hors plongee (Enable=FALSE),
    // la descente reste libre ; pendant la plongee, elle n'est autorisee que si l'assistant la
    // delivre (Outputs.DescendPermit, qui integre la precondition benne ouverte).
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := (NOT instDiveSearch.Enable) OR instDiveSearch.Outputs.DescendPermit;
    Data.ReqProgram.ReqBucket.ExtractionControlActive     := instExtractionAssist.ExtractionControlActive;
    // Permis de remontee assistee : sortie FB_ExtractionAssist consommee (PRG_04 §5).
    Data.ReqProgram.ReqBucket.AscentPermit                := instExtractionAssist.AscentPermit;
    // Plancher de plongee : produit par FB_DiveSearch, consomme par PRG_04 §5ter.
    Data.ReqProgram.ReqBucket.MinStepDown                 := instDiveSearch.Outputs.MinStepDown;

    // États de séquence
    IF instDiveSearch.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId        := E_ProgramSequence.DIVE_SEARCH;
        Data.SequenceState.OperatorActionId  := instDiveSearch.Outputs.OperatorActionId;
        Data.SequenceState.OperatorAction    := instDiveSearch.Outputs.OperatorAction;
    ELSIF instExtractionAssist.Lifecycle.Busy THEN
        Data.SequenceState.SequenceId        := E_ProgramSequence.EXTRACTION;
        Data.SequenceState.OperatorActionId  := instExtractionAssist.OperatorActionId;
        Data.SequenceState.OperatorAction    := instExtractionAssist.OperatorAction;
    ELSE
        Data.SequenceState.SequenceId        := E_ProgramSequence.NONE;
        Data.SequenceState.OperatorActionId  := 0;
        Data.SequenceState.OperatorAction    := '';
    END_IF;

    Data.SequenceState.Ready                  := instDiveSearch.Ready OR instExtractionAssist.Ready;
    Data.SequenceState.Lifecycle.Busy         := instDiveSearch.Lifecycle.Busy OR instExtractionAssist.Lifecycle.Busy;
    Data.SequenceState.Lifecycle.Done         := instDiveSearch.Lifecycle.Done OR instExtractionAssist.Lifecycle.Done;
    Data.SequenceState.Fault.Error            := instDiveSearch.Fault.Error OR instExtractionAssist.Fault.Error;
    IF instDiveSearch.Fault.Error THEN
        Data.SequenceState.Fault.ErrorId      := instDiveSearch.Fault.ErrorId;
        Data.SequenceState.Fault.Latched      := instDiveSearch.Fault.Latched;
    ELSIF instExtractionAssist.Fault.Error THEN
        Data.SequenceState.Fault.ErrorId      := instExtractionAssist.Fault.ErrorId;
        Data.SequenceState.Fault.Latched      := instExtractionAssist.Fault.Latched;
    ELSE
        Data.SequenceState.Fault.ErrorId      := 0;
        Data.SequenceState.Fault.Latched      := FALSE;
    END_IF;
    Data.SequenceState.Step                   := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.StepStr                := 'ASSIST_MODE';
    Data.SequenceState.StepAtFault            := E_CycleStep.X0_PREPARATION;
    Data.SequenceState.ExpectedAxis           := E_OperatorAxis.JOYSTICK_Y;
    Data.SequenceState.ExpectedDirection      := WinchBothMotionDirection;
    Data.SequenceState.WaitingForOperator     := FALSE;
    Data.SequenceState.WaitingForProcess      := FALSE;
    Data.SequenceState.RequestActive          := WinchBothMotionActive;
    Data.SequenceState.SpeedMismatchMps       := 0.0;
    Data.SequenceState.SpeedMismatchActive    := FALSE;
    Data.SequenceState.SpeedMismatchConfirmed := FALSE;
    Data.SequenceState.DiveReady                  := instDiveSearch.Ready;
    Data.SequenceState.DiveBusy                   := instDiveSearch.Lifecycle.Busy;
    Data.SequenceState.DiveDone                   := instDiveSearch.Lifecycle.Done;
    Data.SequenceState.DiveError                  := instDiveSearch.Fault.Error;
    Data.SequenceState.DiveErrorId                := instDiveSearch.Fault.ErrorId;
    Data.SequenceState.DiveState                  := instDiveSearch.Outputs.StepState;
    Data.SequenceState.DiveStepAtFault             := instDiveSearch.Outputs.StepAtFault;
    Data.SequenceState.BottomTouchConfirmed       := BottomPositionConfirmed;
    Data.SequenceState.ExtractionReady             := instExtractionAssist.Ready;
    Data.SequenceState.ExtractionBusy              := instExtractionAssist.Lifecycle.Busy;
    Data.SequenceState.ExtractionDone              := instExtractionAssist.Lifecycle.Done;
    Data.SequenceState.ExtractionError             := instExtractionAssist.Fault.Error;
    Data.SequenceState.ExtractionErrorId           := instExtractionAssist.Fault.ErrorId;
    Data.SequenceState.ExtractionState             := instExtractionAssist.ExtractionState;
    Data.SequenceState.ExtractionStepAtFault       := instExtractionAssist.StepAtFault;
    Data.SequenceState.DumpAtTremieArmed           := DumpAtTremieActive;
    Data.SequenceState.DumpAtTremieAssistActive      := DumpAtTremieAssistActive;
    Data.SequenceState.DumpAtTremieAtTremie          := PRG_05_Translation.Data.M3_AtTremieStable;
    Data.SequenceState.DumpAtTremieBucketOpenArmed   := DumpAtTremieBucketOpenArmed;
    Data.SequenceState.DumpAtTremieDescentLocked     := DumpAtTremieAssistActive AND NOT (PRG_05_Translation.Data.M3_AtP1Stable OR PRG_05_Translation.Data.M3_AtMaintenanceStable);
    Data.SequenceState.BypassDiveActive            := GVL_IHM.DredgingAssist.Cmd.TglBypassDiveSearchSequence;
    Data.SequenceState.BypassKoboldBottomTouched   := BypassKoboldBottomTouched;

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
    Data.ReqProgram.ReqBucket.ExtractionControlActive     := FALSE;
    Data.ReqProgram.ReqBucket.AscentPermit                := FALSE;
    // DISABLE : plancher neutre (0 = aucun).
    Data.ReqProgram.ReqBucket.MinStepDown                 := 0;

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
    Data.SequenceState.DiveReady                  := FALSE;
    Data.SequenceState.DiveBusy                   := FALSE;
    Data.SequenceState.DiveDone                   := FALSE;
    Data.SequenceState.DiveError                  := FALSE;
    Data.SequenceState.DiveErrorId                := 0;
    Data.SequenceState.DiveState                  := E_DiveSearchState.WAIT_PRECONDITIONS;
    Data.SequenceState.DiveStepAtFault            := E_DiveSearchState.WAIT_PRECONDITIONS;
    Data.SequenceState.BottomTouchConfirmed       := FALSE;
    Data.SequenceState.ExtractionReady             := FALSE;
    Data.SequenceState.ExtractionBusy              := FALSE;
    Data.SequenceState.ExtractionDone              := FALSE;
    Data.SequenceState.ExtractionError             := FALSE;
    Data.SequenceState.ExtractionErrorId           := 0;
    Data.SequenceState.ExtractionState             := E_ExtractionAssistState.WAIT_BOTTOM_CONFIRMATION;
    Data.SequenceState.ExtractionStepAtFault       := E_ExtractionAssistState.WAIT_BOTTOM_CONFIRMATION;
    Data.SequenceState.DumpAtTremieArmed           := FALSE;
    Data.SequenceState.DumpAtTremieAssistActive      := FALSE;
    Data.SequenceState.DumpAtTremieAtTremie          := FALSE;
    Data.SequenceState.DumpAtTremieBucketOpenArmed   := FALSE;
    Data.SequenceState.DumpAtTremieDescentLocked     := FALSE;
    Data.SequenceState.BypassDiveActive            := FALSE;
    Data.SequenceState.BypassKoboldBottomTouched   := FALSE;
END_IF;

{endregion}

END_PROGRAM
