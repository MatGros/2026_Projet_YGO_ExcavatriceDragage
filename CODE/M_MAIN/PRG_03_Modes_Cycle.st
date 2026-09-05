(* ═══════════════════════════════════════════════════════════════
   🎚️ PRG_03_Modes_Cycle — Gestion, Modes Machine et Séquenceur de Cycle
   ───────────────────────────────────────────────────────────────
   ⚙️ Exécuté par la tâche PLC en position 3 (après PRG_02_Acquisition).
   📄 Docs : DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
            DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   🎯 Rôle unique : Instancier FB_Modes, distribuer le bus ST_Modes_Autorisations,
      et instancier les 2 séquenceurs de cycle (maintenance + semi-auto).
   ⚠️ Retard d'un scan : FB_CycleSemiAuto (rang 03) lit les feedbacks de PRG_04/05
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
    instCycleSemiAuto      : FB_CycleSemiAuto;              // * [INST] Séquenceur de cycle semi-automatique (privé)

    // === 🎛️ VARIABLES LOCALES & DÉTECTEURS ===
    WinchBothMotionActive      : BOOL;   // . [LOC] Intention de mouvement both active (joystick ou boutons)
    WinchBothMotionDirection   : INT;    // . [LOC] Sens mouvement both (-1: Descending, 0: Neutre, +1: Ascending)
    ManualBottomPositionConfirmed : BOOL;   // . [LOC] Confirmation manuelle "fond touché" opérateur
    BottomPositionConfirmed       : BOOL;   // . [LOC] Synthèse fond touché (Kobold OR Manuel OR Bypass)
    BypassKoboldBottomTouched     : BOOL;   // . [LOC] Détection fond sur front Kobold en mode bypass
    BypassKoboldFallEdge          : F_TRIG; // . [LOC] Détecteur front descendant Kobold sous bypass
    DumpAtTremieActive            : BOOL;   // . [LOC] Option vidage à la trémie activée IHM
    DumpAtTremieAssistActive      : BOOL;   // . [LOC] Assistance vidage trémie active
    DumpAtTremieBucketOpenArmed   : BOOL;   // . [LOC] Armement ouverture benne à la trémie
    CycleInitPositionOk           : BOOL;   // . [LOC] Posture de départ cycle SEMI_AUTO : chariot P1 + treuils au capteur haut (± CST_CycleInitWindowM)
    CycleWinchesAtTopOk           : BOOL;   // . [LOC] Treuils M1 ET M2 dans la fenêtre FDC logiciel haut (± CST_CycleInitWindowM) - surveillé en AX2
END_VAR

VAR CONSTANT
    CST_CycleInitWindowM : REAL := 0.4;    // Plage d'acceptation posture de départ cycle (m)
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
    // T248 — sequencement auto benne en couple (force temporairement le sel. a 2)
    CoupledBucketSeqEnable  := GVL_IHM.Commun.Cfg.TglEnableCoupledBucketSequencing,
    M3AtTremie              := PRG_05_Translation.Data.TranslationState.LimitSwitchTremie,
    AllowWinchMoveAtTremie  := GVL_IHM.TranslationM3.Cmd.TglAllowWinchMoveAtTremie,
    JoystickPull            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionPositive,
    JoystickPush            := PRG_02_Acquisition.Data.Joystick.AxisY.DirectionNegative,
    BucketIsOpen            := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen,
    BucketIsClosed          := PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed,
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
                             AND (instModes.Auth.JoystickWinchSelectArbitrated = 0)
                             AND (instModes.Auth.Mode <> E_Mode.SEMI_AUTO);
ELSE
    IF GVL_IHM.Commun.BtnWinchBothAscent THEN
        WinchBothMotionDirection := 1;
    ELSIF GVL_IHM.Commun.BtnWinchBothDescent THEN
        WinchBothMotionDirection := -1;
    ELSE
        WinchBothMotionDirection := 0;
    END_IF;
    WinchBothMotionActive := (WinchBothMotionDirection <> 0)
                             AND (instModes.Auth.Mode <> E_Mode.SEMI_AUTO);
END_IF;

// Posture de départ du cycle SEMI_AUTO (condition AX1_INIT) : treuil porteur M1 ou M2 ayant
// atteint la limite haute logicielle (CableLimitAscent) OU dans la fenêtre haute (± CST_CycleInitWindowM)
// ET état mécanique benne qualifié (IsClosed ou IsOpen via FB_Bucket, les sécurités gérant les écarts anormaux)
// ET chariot M3 PAS à droite de P1 (côté maintenance interdit). Le positionnement fin
// sur P1 est fait ensuite en AX2. Calculé ici — FB_CycleSemiAuto ne fait que consommer.
CycleWinchesAtTopOk :=
    (PRG_04_Treuils_Benne.Data.WinchM1Safety.CableLimitAscent
     OR PRG_04_Treuils_Benne.Data.WinchM2Safety.CableLimitAscent
     OR (ABS(PRG_02_Acquisition.Data.EncoderM1.Measurement.CablePosM - _CommunCfgPersist.CfgCableLimitAscent_M) <= CST_CycleInitWindowM))
    AND (PRG_04_Treuils_Benne.Data.BucketState.MechState.IsClosed OR PRG_04_Treuils_Benne.Data.BucketState.MechState.IsOpen);

// Posture de départ complète (AX1_INIT) = treuils en haut ET chariot M3 PAS à droite de P1.
CycleInitPositionOk := NOT PRG_05_Translation.Data.M3_AtMaintenanceStable AND CycleWinchesAtTopOk;

{endregion}


// === 🤿 §2 ASSISTANTS DE DRAGAGE (PLONGÉE & EXTRACTION) ===
{region "§2 Assistants de dragage"}

// Assistants FB_DiveSearch/FB_ExtractionAssist retires (legacy, jamais actives) : plus de
// commande IHM de confirmation fond ni de bypass Kobold associee.
ManualBottomPositionConfirmed := FALSE;
BypassKoboldBottomTouched := FALSE;
BottomPositionConfirmed := FALSE;

{endregion}


// === 🔄 §3 SÉQUENCEUR DE CYCLE SEMI-AUTOMATIQUE ===
{region "§3 Séquenceur de cycle"}
// 🕹️ JoystickDeflected = manche défléchi (non centré) — D2
// ⚠️ Entrées consommées sur les bus publics Data (retard N-1 admis AF-02) :

instCycleSemiAuto(
    Enable                  := (instModes.Auth.Mode = E_Mode.SEMI_AUTO),
    Reset                   := GVL_IHM.CycleSemiAuto.Cmd.BtnReset,
    PowerContactorEngaged   := PRG_02_Acquisition.HwIn.Machine.PowerContactorEngaged_DI,
    EncoderFaultPresent     := (PRG_02_Acquisition.HwIn.Winch.COD1_DeviceState <> DEVICE_STATE.RUNNING) OR (PRG_02_Acquisition.HwIn.Winch.COD2_DeviceState <> DEVICE_STATE.RUNNING),
    Mode                    := instModes.Auth.Mode,
    JoystickDeflected       := NOT PRG_02_Acquisition.Data.Joystick.AtNeutralXY,
    DeadmanArmed            := PRG_02_Acquisition.Data.Joystick.DeadmanArmed,
    HeartbeatIhmOk          := GVL_IHM.Commun.HeartbeatIhmOk,
    StartCycle              := GVL_IHM.CycleSemiAuto.Cmd.BtnStart,
    AbortCycle              := GVL_IHM.CycleSemiAuto.Cmd.BtnAbort,
    SelTarget               := GVL_IHM.TranslationM3.Cmd.SelTarget,
    SetDepthM               := GVL_IHM.CycleSemiAuto.Cfg.SetDepth_M,
    SetOffsetM              := GVL_IHM.CycleSemiAuto.Cfg.SetOffset_M,
    KoboldContactFond       := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI,
    KoboldImmersed          := PRG_02_Acquisition.HwIn.Machine.M1_M2_KoboldBottomTouch_DI, // DI brut Kobold (fronts AX6/AX7) - convention a confirmer au banc
    KoboldContactorFeedback := TRUE, // TODO banc : cabler le retour contacteur Kobold reel ; TRUE = init reputee OK (verif AX5 dormante)
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
    InitPositionOk          := CycleInitPositionOk,
    WinchesAtTopWindow      := CycleWinchesAtTopOk,
    HomingRequest           := GVL_IHM.M1TreuilRetenue.Cmd.BtnHome OR GVL_IHM.M2TreuilBenne.Cmd.BtnHome,
    CfgDrainTime            := GVL_IHM.CycleSemiAuto.Cfg.DrainTime,
    SkipDrainRequest        := GVL_IHM.CycleSemiAuto.Cmd.BtnSkipDrain,
    RepositionRequest       := GVL_IHM.CycleSemiAuto.Cmd.BtnReposition,
    CfgCommissioningEnable  := GVL_IHM.CycleSemiAuto.Cmd.TglCommissioning,
    CfgForceStepTarget      := GVL_IHM.CycleSemiAuto.Cfg.ForceStepTarget,
    CfgForceStepApply       := GVL_IHM.CycleSemiAuto.Cmd.BtnForceStepApply,
    // Config diving / extraction (GEL 2026-09-03)
    DiveStartMinM           := GVL_IHM.CycleSemiAuto.Cfg.DiveStartMin_M, // altimetrie lancement Kobold (AT4)
    CfgRaiseOffBottomM      := GVL_IHM.CycleSemiAuto.Cfg.RaiseOffBottom_M,   // GEL Q16 : decollement du fond AX8 (reglable IHM)
    CfgCtrlAscentMaxStep    := GVL_IHM.CycleSemiAuto.Cfg.CtrlAscentMaxStep,  // GEL Q16 : palier max montee controle AX11 [1..2]
    M1_SpeedStepApplied     := PRG_04_Treuils_Benne.Data.WinchM1State.StepNumber, // palier applique (0..5) : garde palier<>4 en plongee (GT-dive-retry) + cause 8 (palier 5)
    M2_SpeedStepApplied     := PRG_04_Treuils_Benne.Data.WinchM2State.StepNumber,
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
Data.WinchBothIntent.ReqAscent  := WinchBothMotionDirection > 0;
Data.WinchBothIntent.ReqDescend := WinchBothMotionDirection < 0;

// 2. Demandes programme et état public de séquence
IF instModes.Auth.Mode = E_Mode.SEMI_AUTO THEN
    // Demandes treuils M1 / M2 — copie struct entière : FB_CycleSemiAuto produit directement
    // le type de contrat inter-PRG (ST_Program*Request). Plus de re-mapping
    // champ-à-champ ni de DUT ST_fbCycle_*CmdDemand redondants (NC-090).
    Data.ReqProgram.ReqWinchM1 := instCycleSemiAuto.WinchM1Cmd;
    Data.ReqProgram.ReqWinchM2 := instCycleSemiAuto.WinchM2Cmd;

    // Demande translation M3
    Data.ReqProgram.ReqTranslation := instCycleSemiAuto.TranslationCmd;

    // Demande benne — FB_CycleSemiAuto fournit aussi les champs assistants neutres
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
    Data.SequenceState.CurrentCycleElapsed    := instCycleSemiAuto.CurrentCycleElapsed;
    Data.SequenceState.LastCycleDuration      := instCycleSemiAuto.LastCycleDuration;
    Data.SequenceState.BottomTouchConfirmed   := FALSE;

    // === RESET ÉTATS ASSISTANTS (neutralisation déterministe au passage SEMI_AUTO) ===
    // Aucun assistant de dragage n'est actif en SEMI_AUTO : mêmes valeurs neutres que la branche DISABLE.
    Data.SequenceState.WinchDescentAuth_M3           := TRUE;

ELSIF (instModes.Auth.Mode = E_Mode.MAINT_N1 OR instModes.Auth.Mode = E_Mode.MAINT_N2) THEN
    // Mode Manuel / Maintenance : Publication des requêtes issues des assistants
    Data.ReqProgram.ReqWinchM1.RunRequest := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqAscent := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDescend := FALSE;
    Data.ReqProgram.ReqWinchM1.StepTgt  := 0;

    Data.ReqProgram.ReqWinchM2.RunRequest := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqAscent := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDescend := FALSE;
    Data.ReqProgram.ReqWinchM2.StepTgt  := 0;

    // Cycle de homing machine (MAINT_N2 uniquement) : route ses ordres treuil couple
    // M1+M2 palier 1 (HX2 montee / HX3 descente). Le FB gate deja sur permis operateur
    // maintenu (homme-mort + joystick) et ne commande qu'en HX2/HX3 ; PRG_04 conserve
    // ses interlocks maintenance. Copie struct entiere (ST_ProgramWinchRequest).
    IF instModes.Auth.Mode = E_Mode.MAINT_N2
       AND PRG_02_Acquisition.Data.MachineHoming.Active THEN
        Data.ReqProgram.ReqWinchM1 := PRG_02_Acquisition.Data.MachineHoming.CmdWinchM1;
        Data.ReqProgram.ReqWinchM2 := PRG_02_Acquisition.Data.MachineHoming.CmdWinchM2;
    END_IF;

    Data.ReqProgram.ReqTranslation.ReqStart    := FALSE;
    Data.ReqProgram.ReqTranslation.PositionTgt := 0;

    // Requêtes benne et assistants — DumpAtTremie recode (toggle IHM independant du verrou descente)
    DumpAtTremieActive := GVL_IHM.M2TreuilBenne.Bucket.Cmd.TglEnableDumpAtTremie;
    DumpAtTremieAssistActive := DumpAtTremieActive;
    DumpAtTremieBucketOpenArmed := DumpAtTremieAssistActive AND PRG_05_Translation.Data.M3_AtTremieStable;

    Data.ReqProgram.ReqBucket.ReqOpen                     := DumpAtTremieBucketOpenArmed;
    Data.ReqProgram.ReqBucket.ReqClose                    := FALSE;
    // Assistants dragage retires (FB_DiveSearch/FB_ExtractionAssist supprimes) : sorties neutres.
    Data.ReqProgram.ReqBucket.ReqKoboldMeasureEnable      := FALSE;
    Data.ReqProgram.ReqBucket.DescendPermitDiveBucketOpen := TRUE;
    Data.ReqProgram.ReqBucket.ExtractionControlActive     := FALSE;
    Data.ReqProgram.ReqBucket.AscentPermit                := FALSE;
    Data.ReqProgram.ReqBucket.MinStepDown                 := 0;

    // Cycle de homing machine (MAINT_N2) : ordres benne palier 1 sans FDC soft (HX4).
    // Mutuellement exclusifs cote FB. Route OVERRIDE (pas un OR) quand le cycle homing est
    // engage : evite le cumul ReqOpen+ReqClose si un assistant (DumpAtTremie / Extraction)
    // etait actif au meme instant. Hors cycle homing : demandes assistants inchangees.
    IF instModes.Auth.Mode = E_Mode.MAINT_N2
       AND PRG_02_Acquisition.Data.MachineHoming.Active THEN
        Data.ReqProgram.ReqBucket.ReqOpen  := PRG_02_Acquisition.Data.MachineHoming.CmdBucketOpen;
        Data.ReqProgram.ReqBucket.ReqClose := PRG_02_Acquisition.Data.MachineHoming.CmdBucketClose;
    END_IF;

    // États de séquence — assistants FB_DiveSearch/FB_ExtractionAssist retires : neutre.
    Data.SequenceState.SequenceId        := E_ProgramSequence.NONE;
    Data.SequenceState.OperatorActionId  := 0;
    Data.SequenceState.OperatorAction    := '';

    Data.SequenceState.Ready                  := TRUE;
    Data.SequenceState.Lifecycle.Busy         := FALSE;
    Data.SequenceState.Lifecycle.Done         := FALSE;
    Data.SequenceState.Fault.Error            := FALSE;
    Data.SequenceState.Fault.ErrorId          := 0;
    Data.SequenceState.Fault.Latched          := FALSE;
    Data.SequenceState.Step                   := E_AutoCycleStep.AX0_REPOS;
    Data.SequenceState.StepStr                := 'ASSIST_MODE';
    Data.SequenceState.StepAtFault            := E_AutoCycleStep.AX0_REPOS;
    Data.SequenceState.ExpectedAxis           := E_OperatorAxis.JOYSTICK_Y;
    Data.SequenceState.ExpectedDirection      := WinchBothMotionDirection;
    Data.SequenceState.WaitingForOperator     := FALSE;
    Data.SequenceState.WaitingForProcess      := FALSE;
    Data.SequenceState.RequestActive          := WinchBothMotionActive;
    Data.SequenceState.SpeedMismatchMps       := 0.0;
    Data.SequenceState.SpeedMismatchActive    := FALSE;
    Data.SequenceState.SpeedMismatchConfirmed := FALSE;
    Data.SequenceState.CurrentCycleElapsed    := T#0s;
    Data.SequenceState.LastCycleDuration      := T#0s;
    Data.SequenceState.BottomTouchConfirmed       := BottomPositionConfirmed;
    // Verrou descente treuil = GENERAL en MAINT (plus seulement pendant l'assist vidage) :
    // descente M1/M2 interdite tant que le pont M3 n'est pas ARRETE STABLE a P1 (travail)
    // ou a Maintenance. En transit / PV / P2 / Tremie -> pas de paye de cable. Echappatoire
    // MES : bypass FdC M3 (LimitSwitch) ou bypass global M3.
    // Position de travail = STATIQUE (mot capteurs M3), pas le jeton de franchissement :
    // au boot PLC, pont deja pose a P1/Maintenance -> descente autorisee sans devoir
    // franchir un capteur d'abord (M3_AtWorkPositionStable couvre M3_AtP1/Maint jetons
    // + lecture directe mot 00011 / 00000).
    Data.SequenceState.WinchDescentAuth_M3     :=
        PRG_05_Translation.Data.M3_AtWorkPositionStable
        OR GVL_IHM.TranslationM3.Bypass.LimitSwitch
        OR GVL_IHM.TranslationM3.Bypass.Global;

ELSE
    // Neutralisation déterministe (DISABLE)
    Data.ReqProgram.ReqWinchM1.RunRequest := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqAscent := FALSE;
    Data.ReqProgram.ReqWinchM1.ReqDescend := FALSE;
    Data.ReqProgram.ReqWinchM1.StepTgt  := 0;

    Data.ReqProgram.ReqWinchM2.RunRequest := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqAscent := FALSE;
    Data.ReqProgram.ReqWinchM2.ReqDescend := FALSE;
    Data.ReqProgram.ReqWinchM2.StepTgt  := 0;

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
    Data.SequenceState.Step                    := E_AutoCycleStep.AX0_REPOS;
    Data.SequenceState.StepStr                 := 'AX0_REPOS';
    Data.SequenceState.StepAtFault             := E_AutoCycleStep.AX0_REPOS;
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
    Data.SequenceState.CurrentCycleElapsed     := T#0s;
    Data.SequenceState.LastCycleDuration       := T#0s;
    Data.SequenceState.BottomTouchConfirmed       := FALSE;
    Data.SequenceState.WinchDescentAuth_M3           := TRUE;
END_IF;

{endregion}

END_PROGRAM
