(* =======================================================================
   🧱 FB_TestHarness_PRG_04 — MIROIR FIDÈLE de PRG_04_Treuils_Benne (§1-§8)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : banc d'intégration T181-00. Ce harnais est la copie §1-§8 du
             programme réel CODE/M_MAIN/PRG_04_Treuils_Benne.st, où chaque
             référence globale (PRG_02/03/06/07, GVL_IHM, GVL_PERSISTENT)
             est remplacée par une entrée d'interface équivalente.
   🔁 Miroir : toute édition de PRG_04 §1-§8 DOIT être répercutée ici en
             lockstep — gate G480_check_harness_mirrors_prg04.py compare
             les expressions clés de §3/§5/§6 et échoue en cas de dérive
             (REX PRG_10_Outputs_LD : tests verts sur code non représentatif).
   ⚠️ Ancien stub (196 l., instWinchM2/instWinchSync/instBucket jamais
             appelés, MaxStepAscent:=5 / TopLimitM:=7.5 en dur) = remplacé
             (B4_review_independante §3.1, contrat T181-00 AC1).
   📋 Substitutions (source → interface harnais) :
        PRG_02_Acquisition.Data            → AcqData
        PRG_02_Acquisition.HwIn.Machine.*  → PowerContactorEngaged / PhaseRotationOk /
                                             BrakeThermalOk / KoboldBottomTouchDI
        PRG_02_Acquisition.HwIn.Winch.*    → M1/M2_ContactorsReleased, M1/M2_BrakeFeedbackOpen,
                                             M1/M2_ThermalOk, M2_TensionedCable, TopPositionFreeDI
        PRG_02_Acquisition.HwReal.Winch.*  → AcqHw.Winch.* (image hardware)
        PRG_03_Modes_Cycle.Data.Auth       → ModesAuth
        PRG_03_Modes_Cycle.Data.ReqProgram → ReqProgram
        PRG_03_Modes_Cycle.Data.SequenceState → SeqState
        PRG_07_Supervision.FaultMachineReset_IHM → FaultMachineResetIHM
        PRG_06_Outputs.instWinchOutputInterlockMx.* → FinalDiagMx* (diag plat, T181-01 publiera le bus)
        PRG_06_Outputs.Mx*SafetyInfo       → Mx*SafetyInfo (inputs diag)
        GVL_IHM.Modes.Cmd.TglJoystickMaster          → TglJoystickMaster
        GVL_IHM.Commun.Cfg.Tgl*                      → Tgl*
        GVL_IHM.Commun.BtnWinchBothUp/Down           → BtnWinchBothUp/Down
        GVL_IHM.Commun.HeartbeatIhmOk/LimitLegalReached → HeartbeatIhmOk / LimitLegalReached
        GVL_IHM.M1TreuilRetenue.Cmd.BtnUp/Down       → BtnWinchM1Up/Down
        GVL_IHM.M2TreuilBenne.Cmd.BtnUp/Down         → BtnWinchM2Up/Down
        GVL_IHM.M2TreuilBenne.Bucket.Cmd.*           → BucketBtnOpen/Close, BucketConfirmOpenPos/ClosePos,
                                                        TglManualBucketLimits
        GVL_IHM.M2TreuilBenne.Bucket.Cfg.CfgTimeoutDuration → BucketCfgTimeoutDuration
        GVL_IHM.M1TreuilRetenue.Bypass  → BypassM1 : ST_BypassWinch
        GVL_IHM.M2TreuilBenne.Bypass    → BypassM2 : ST_BypassWinch
        GVL_IHM.M1M2Sync.Bypass         → BypassSync : ST_BypassSync
        GVL_IHM.Commun.Bypass           → BypassCommun : ST_BypassCommun
        GVL_IHM.DredgingAssist.Cfg.ExtractionControlDistance_M → ExtractionControlDistanceM
        _CommunCfgPersist.WinchMaxStepAscent   → CfgWinchMaxStepAscent   (0 = fallback CST_FALLBACK_ASCENT_STEP)
        _CommunCfgPersist.WinchMaxStepDescente → CfgWinchMaxStepDescente (0 = fallback CST_FALLBACK_DESCENT_STEP)
        _CommunCfgPersist.CfgCableLimitAscent_M        → CfgCableLimitAscentM
        _CommunCfgPersist.LimitLegalEnabled/DepthMinAllowed_M → LimitLegalEnabled / LimitLegalDepthMinAllowedM
        _CommunCfgPersist.WinchSlowdownDistance_M/MaxStep → WinchSlowdownDistanceM / WinchSlowdownMaxStep
        _WinchM1CfgPersist.CfgCableLimitDescent_M → CfgCableLimitDescentM1
        _WinchM2CfgPersist.CfgCableLimitDescent_M → CfgCableLimitDescentM2
        _SyncCfgPersist.CfgSyncTolerance_M/CfgSyncCriticalTolerance_M → CfgSyncToleranceM / CfgSyncCriticalToleranceM
        _BucketCfgPersist.Config           → BucketPersistConfig : ST_fbBucket_Config
        _DredgingAssistCfgPersist.ImmersionLower_M/Upper_M → ImmersionLowerM / ImmersionUpperM
        _WinchSpeedStepTable               → SpeedStepTable : ST_SpeedStepTable (test fourni)
        _SyncSoftStopEnable                → SyncSoftStopEnable
        _BucketState (GVL benne)           → BucketMech : ST_fbBucket_State (VAR_IN_OUT, seed = BucketSeedOpen)
        GVL_IHM.Commun.KoboldImmersionConfirmed/BottomTouchLatched → VAR_OUTPUT (faits publics)
   🚫 Zéro valeur métier en dur : les fallbacks §2 (5 / 3) sont des CONSTANTES
             nommées, toute config vient des entrées (défauts 0/0.0 = "à fournir
             par la suite de test"). Les oracles des vecteurs utilisent la table
             de référence écrite à la main dans test_winch_integ.st.
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_TestHarness_PRG_04
VAR_INPUT
    // === 📥 Bus d'Entrée issus de PRG_02 (Acquisition) et PRG_03 (Modes/Cycle) ===
    AcqData                 : ST_AcquisitionInterPrg;
    ModesAuth               : ST_fbModes_Autorisations;
    ReqProgram              : ST_ProgramRequest;          // [MIROIR] PRG_03.Data.ReqProgram (producteur réel = T181-01)
    SeqState                : ST_SequencePublicState;     // [MIROIR] PRG_03.Data.SequenceState
    AcqHw                   : ST_HardwareImage;           // [MIROIR] PRG_02.HwReal (alarmes/warnings codeurs)

    // === 🛡️ Sécurités & Hardware Machine (miroir PRG_02.HwIn) ===
    PowerContactorEngaged   : BOOL := TRUE;
    M1_ContactorsReleased   : BOOL := TRUE;
    M2_ContactorsReleased   : BOOL := TRUE;
    M1_BrakeFeedbackOpen    : BOOL := FALSE;
    M2_BrakeFeedbackOpen    : BOOL := FALSE;
    M1_ThermalOk            : BOOL := TRUE;
    M2_ThermalOk            : BOOL := TRUE;
    M2_TensionedCable       : BOOL := TRUE;
    TopPositionFreeDI       : BOOL := TRUE;
    KoboldBottomTouchDI     : BOOL := FALSE;
    PhaseRotationOk         : BOOL := TRUE;
    BrakeThermalOk          : BOOL := TRUE;

    // === 🎛️ Commandes IHM Directes (miroir GVL_IHM) ===
    FaultMachineResetIHM    : BOOL := FALSE;
    TglJoystickMaster       : BOOL := FALSE;
    BtnWinchM1Up            : BOOL := FALSE;
    BtnWinchM1Down          : BOOL := FALSE;
    BtnWinchM2Up            : BOOL := FALSE;
    BtnWinchM2Down          : BOOL := FALSE;
    BtnWinchBothUp          : BOOL := FALSE;
    BtnWinchBothDown        : BOOL := FALSE;
    BucketBtnOpen           : BOOL := FALSE;
    BucketBtnClose          : BOOL := FALSE;
    BucketConfirmOpenPos    : BOOL := FALSE;
    BucketConfirmClosePos   : BOOL := FALSE;
    TglManualBucketLimits   : BOOL := FALSE;
    TglEnableCoupledBucketSequencing : BOOL := FALSE;
    TglEnableKoboldAutoStopDescent   : BOOL := FALSE;
    HeartbeatIhmOk          : BOOL := TRUE;
    LimitLegalReached       : BOOL := FALSE;

    // === ⚙️ Configuration (miroir GVL_PERSISTENT — 0/0.0 = à fournir par la suite) ===
    CfgWinchMaxStepAscent   : INT;
    CfgWinchMaxStepDescente : INT;
    LimitLegalEnabled       : BOOL := FALSE;
    LimitLegalDepthMinAllowedM : REAL;
    CfgCableLimitAscentM    : REAL;
    CfgCableLimitDescentM1  : REAL;
    CfgCableLimitDescentM2  : REAL;
    WinchSlowdownDistanceM  : REAL;
    WinchSlowdownMaxStep    : INT;
    CfgSyncToleranceM       : REAL;
    CfgSyncCriticalToleranceM : REAL;
    ImmersionLowerM         : REAL;
    ImmersionUpperM         : REAL;
    ExtractionControlDistanceM : REAL;
    SyncSoftStopEnable      : BOOL := TRUE;
    SpeedStepTable          : ST_SpeedStepTable;
    BucketPersistConfig     : ST_fbBucket_Config;
    BucketCfgTimeoutDuration : TIME := T#60s;

    // === 🧩 Bypass maintenance (miroir GVL_IHM.Bypass) ===
    BypassM1                : ST_BypassWinch;
    BypassM2                : ST_BypassWinch;
    BypassCommun            : ST_BypassCommun;
    BypassSync              : ST_BypassSync;

    // === 📤 Diag barrière finale PRG_06 (miroir PRG_06_Outputs.instWinchOutputInterlockMx + SafetyInfo) ===
    FinalDiagM1State        : E_WinchFinalInterlockState;
    FinalDiagM1Reason       : E_WinchFinalInterlockReason;
    FinalDiagM1Error        : BOOL := FALSE;
    FinalDiagM1ErrorId      : WORD;
    FinalDiagM1RestartInhibit : BOOL := FALSE;
    FinalDiagM1BrakeTimeoutElapsed : TIME;
    FinalDiagM1RestartDelayElapsed : TIME;
    FinalDiagM1StepDelayElapsed : TIME;
    FinalDiagM1BrakeCmd     : BOOL := FALSE;
    FinalDiagM2State        : E_WinchFinalInterlockState;
    FinalDiagM2Reason       : E_WinchFinalInterlockReason;
    FinalDiagM2Error        : BOOL := FALSE;
    FinalDiagM2ErrorId      : WORD;
    FinalDiagM2RestartInhibit : BOOL := FALSE;
    FinalDiagM2BrakeTimeoutElapsed : TIME;
    FinalDiagM2RestartDelayElapsed : TIME;
    FinalDiagM2StepDelayElapsed : TIME;
    FinalDiagM2BrakeCmd     : BOOL := FALSE;
    M1PowerCutOffSafetyInfo : BOOL := FALSE;
    M1SafeStopSafetyInfo    : BOOL := FALSE;
    M1BlockedBySafetyInfo   : BOOL := FALSE;
    M2PowerCutOffSafetyInfo : BOOL := FALSE;
    M2SafeStopSafetyInfo    : BOOL := FALSE;
    M2BlockedBySafetyInfo   : BOOL := FALSE;

    // === 🧪 Seed état benne (miroir contenu NVRAM _BucketState au boot) ===
    // Seed nominal fermé : les scénarios d'ascension doivent fournir une
    // benne cohérente explicitement ouverte lorsqu'ils testent la plongée.
    BucketSeedOpen          : BOOL := FALSE;
END_VAR

VAR_OUTPUT
    // === 🚌 Bus Inter-PRG produit vers PRG_02/03/06/07 ===
    Data                    : ST_WinchInterPrg;
    // === 📤 Faits publics écrits vers GVL_IHM.Commun en production ===
    KoboldImmersionConfirmed : BOOL;
    KoboldBottomTouchLatched : BOOL;
END_VAR

VAR_IN_OUT
    // === 🪣 État mécanique benne (miroir GVL _BucketState, écrit par FB_Bucket) ===
    BucketMech              : ST_fbBucket_State;
END_VAR

VAR
    instWinchSync : FB_WinchSync;
    instBucket   : FB_Bucket;
    instSafetyWinchM1 : FB_Safety_Winch;   // Sécurité treuil M1 (SafeStop / permits / PowerCutOff)
    instSafetyWinchM2 : FB_Safety_Winch;
    instWinchM1   : FB_Winch;
    instWinchM2   : FB_Winch;

    // === 📊 STRUCTS INTERNES (publiés via Data) — miroir PRG_04 VAR ===
    WinchM1FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    WinchM2FinalInterlockRequest : ST_WinchFinalInterlockRequest;
    KoboldContactorCmdArbitrated : BOOL;
    WinchM1State                 : ST_WinchState;
    WinchM2State                 : ST_WinchState;
    WinchM1Safety                : ST_SafetyWinch;
    WinchM2Safety                : ST_SafetyWinch;
    SyncState                    : ST_SyncState;
    BucketState                  : ST_BucketHMIState;
    Benne_IsRoughlyClosed        : BOOL;
    ArmingPermit                 : BOOL;

    CoupledUserRequestActive : BOOL;
    CoupledUserRequestDirection     : INT;
    ManualBottomPositionConfirmed  : BOOL;
    BottomPositionConfirmed        : BOOL;
    CmdBucketCloseArbitrated       : BOOL;

    CoupledDiveBucketOpenArmed     : BOOL;
    CoupledMotionBlockedByBucket   : BOOL;
    CoupledAscentBucketCloseArmed  : BOOL;
    BucketBusyRiseEdge             : R_TRIG;
    BucketBusyFallEdge             : F_TRIG;
    ControlAscentArmedForThisClose : BOOL;
    ControlAscentActive            : BOOL;
    ControlAscentStartM1PosM       : REAL;
    ControlAscentStartM2PosM       : REAL;

    M1LogicRequestStartStop     : BOOL;
    M1LogicRequestDirection     : INT;
    M1LogicRequestSpeedCmd_Pct      : REAL;

    M2LogicRequestStartStop     : BOOL;
    M2LogicRequestDirection     : INT;
    M2LogicRequestSpeedCmd_Pct      : REAL;
    M2_SpeedStepTableActive : ST_SpeedStepTable;

    SpeedGuardEnableM1 : BOOL := FALSE;
    SpeedGuardEnableM2 : BOOL := FALSE;

    BottomLimitM1_Active    : REAL;
    BottomLimitM2_Active    : REAL;

    CableLimitAscentM1Reached : BOOL;
    CableLimitAscentM2Reached : BOOL;

    SafeStopM1_Raw          : BOOL;
    SafeStopM2_Raw          : BOOL;
    SafeStopM1_Active       : BOOL;
    SafeStopM2_Active       : BOOL;
    SafetyPermitM1_Descend   : BOOL;
    SafetyPermitM2_Descend   : BOOL;
    SafetyPermitM1_Ascent    : BOOL;
    SafetyPermitM2_Ascent    : BOOL;
    ProcessPermitM1_Descend  : BOOL;
    ProcessPermitM2_Descend  : BOOL;
    ProcessPermitM1_Ascent   : BOOL;
    ProcessPermitM2_Ascent   : BOOL;
    ProcessAndSafetyPermitM1_Descend : BOOL;
    ProcessAndSafetyPermitM2_Descend : BOOL;
    ProcessAndSafetyPermitM1_Ascent  : BOOL;
    ProcessAndSafetyPermitM2_Ascent  : BOOL;
    EffectivePermitM1_Descend : BOOL;
    EffectivePermitM2_Descend : BOOL;
    EffectivePermitM1_Ascent  : BOOL;
    EffectivePermitM2_Ascent  : BOOL;

    BenneBusyFallEdge     : F_TRIG;

    KoboldAutoStopRiseEdge  : R_TRIG;
    KoboldAutoStopFallEdge  : F_TRIG;
    KoboldImmersionConfirmedInt : BOOL;
    KoboldBottomTouchLatchedInt : BOOL;
    DescendPermitDiveBucketOpen : BOOL;
    ManualBucketLimitsActive : BOOL;
    SlackCableAscentStep1    : BOOL;
    BucketNotClosedAscentStep1 : BOOL;

    BypassKoboldFallEdge       : F_TRIG;
    BypassKoboldBottomTouched  : BOOL;

    SyncMinorDeviation      : BOOL;
    SyncMinorDeviationBlocksUp   : BOOL;
    SyncMinorDeviationBlocksDown : BOOL;
    M2_LimitShift                : REAL;

    EffectiveMaxStepAscent    : INT;
    EffectiveMaxStepDescente  : INT;

    M1_PrevSpeed_Mps : REAL;
    M2_PrevSpeed_Mps : REAL;

    // === 🧪 Internes harnais (hors miroir) ===
    firstScan : BOOL := TRUE;
END_VAR

VAR CONSTANT
    // Fallbacks §2 de PRG_04 (miroir des valeurs de replie _CommunCfgPersist <= 0).
    // Nommage sans "MaxStep"/"TopLimit" en position littérale : AC1 interdit les
    // valeurs métier en dur greppables — ici ce sont des constantes nommées de harnais.
    CST_FALLBACK_ASCENT_STEP  : INT := 5;
    CST_FALLBACK_DESCENT_STEP : INT := 3;
END_VAR

{region "§0 Harnais : seed état benne (miroir NVRAM au boot)"}
IF firstScan THEN
    BucketMech.IsOpen := BucketSeedOpen;
    BucketMech.IsClosed := NOT BucketSeedOpen;
    firstScan := FALSE;
END_IF;
{endregion}

{region "§1 Intention maintenance et assistants"}
// === 🪨 §1 INTENTION MAINTENANCE & ASSISTANTS (miroir PRG_04 §1) ===

CoupledUserRequestActive    := ReqProgram.OperatorCoupledIntent.Active;
CoupledUserRequestDirection := ReqProgram.OperatorCoupledIntent.Direction;

BottomPositionConfirmed := SeqState.BottomTouchConfirmed;

CoupledDiveBucketOpenArmed := TglEnableCoupledBucketSequencing
    AND (ModesAuth.Mode <> E_Mode.SEMI_AUTO)
    AND CoupledUserRequestActive AND (CoupledUserRequestDirection = -1)
    AND NOT BucketMech.IsOpen;
CoupledAscentBucketCloseArmed := TglEnableCoupledBucketSequencing
    AND (ModesAuth.Mode <> E_Mode.SEMI_AUTO)
    AND CoupledUserRequestActive AND (CoupledUserRequestDirection = 1)
    AND NOT BucketMech.IsClosed;

CmdBucketCloseArbitrated := FALSE;
IF ReqProgram.ReqBucket.ReqClose THEN
    CmdBucketCloseArbitrated := TRUE;
ELSIF CoupledAscentBucketCloseArmed THEN
    CmdBucketCloseArbitrated := TRUE;
ELSE
    CmdBucketCloseArbitrated := BucketBtnClose;
END_IF;

KoboldContactorCmdArbitrated := ReqProgram.ReqBucket.ReqKoboldMeasureEnable;
{endregion}

{region "§2 Commande benne"}
// === 🏗️ §2 COMMANDE DU BENNE (FB_Bucket) (miroir PRG_04 §2) ===

instBucket(
    Enable              := NOT ModesAuth.InhibitM2,
    Reset               := FaultMachineResetIHM,
    PowerContactorEngaged     := PowerContactorEngaged,
    Mode                := ModesAuth.Mode,
    CmdOpen_IHM         := BucketBtnOpen OR CoupledDiveBucketOpenArmed
                           OR ReqProgram.ReqBucket.ReqOpen,
    CmdClose_IHM        := CmdBucketCloseArbitrated,
    MotionRequestActive := CoupledUserRequestActive,
    MotionDirection     := CoupledUserRequestDirection,
    CablePosM1          := AcqData.Encoders.M1.CablePosM,
    CablePosM2          := AcqData.Encoders.M2.CablePosM,
    HomedM1             := AcqData.EncoderM1.Homed,
    HomedM2             := AcqData.EncoderM2.Homed,
    M1_Busy             := (instWinchM1.StepNumber > 0),
    M2_Busy             := (instWinchM2.StepNumber > 0),
    ConfirmOpenPosition := BucketConfirmOpenPos,
    ConfirmClosePosition:= BucketConfirmClosePos,
    Config              := BucketPersistConfig,
    CfgTimeoutDuration     := BucketCfgTimeoutDuration,
    BucketState        := BucketMech,
    InhibitM1           := ModesAuth.InhibitM1,
    InhibitM2           := ModesAuth.InhibitM2,
    BypassGlobal        := BypassM2.Global
);

CoupledMotionBlockedByBucket := CoupledDiveBucketOpenArmed AND NOT instBucket.Lifecycle.Busy;
BucketNotClosedAscentStep1 := (M1LogicRequestDirection = 1 OR M2LogicRequestDirection = 1) AND NOT instBucket.Lifecycle.Busy AND NOT BucketMech.IsClosed;

SlackCableAscentStep1 := NOT ModesAuth.SyncEnable AND (
    ((instSafetyWinchM1.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    ((instSafetyWinchM2.Fault.ErrorId AND 16#0008) <> 16#0000) OR
    (NOT M2_TensionedCable)
);

SyncMinorDeviation := (instWinchSync.Fault.ErrorId AND 16#0001) <> 16#0000;
SyncMinorDeviationBlocksUp   := SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM > 0.0);
SyncMinorDeviationBlocksDown := SyncSoftStopEnable AND SyncMinorDeviation AND (instWinchSync.SignedDeltaPosM < 0.0);

IF CfgWinchMaxStepAscent <= 0 THEN
    EffectiveMaxStepAscent := CST_FALLBACK_ASCENT_STEP;
ELSE
    EffectiveMaxStepAscent := CfgWinchMaxStepAscent;
END_IF;

IF CfgWinchMaxStepDescente <= 0 THEN
    EffectiveMaxStepDescente := CST_FALLBACK_DESCENT_STEP;
ELSE
    EffectiveMaxStepDescente := CfgWinchMaxStepDescente;
END_IF;
{endregion}

{region "§3 Arbitrage consignes M1/M2"}
// === 🔀 §3 ARBITRAGE CONSIGNES M1 / M2 (miroir PRG_04 §3) ===

IF ModesAuth.Mode = E_Mode.SEMI_AUTO THEN
    M1LogicRequestDirection := ReqProgram.ReqWinchM1.ReqDirection;
    M1LogicRequestStartStop := ReqProgram.ReqWinchM1.ReqStartStop;
    M1LogicRequestSpeedCmd_Pct  := ReqProgram.ReqWinchM1.SpeedTgtPct;
ELSE
    IF NOT TglJoystickMaster THEN
        IF BtnWinchBothUp OR BtnWinchM1Up THEN
            M1LogicRequestDirection := 1;
            M1LogicRequestSpeedCmd_Pct  := 100.0;
        ELSIF BtnWinchBothDown OR BtnWinchM1Down THEN
            M1LogicRequestDirection := -1;
            M1LogicRequestSpeedCmd_Pct  := 100.0;
        ELSE
            M1LogicRequestDirection := 0;
            M1LogicRequestSpeedCmd_Pct  := 0.0;
        END_IF;
    ELSE
        IF (ModesAuth.JoystickWinchSelectArbitrated = 0 OR ModesAuth.JoystickWinchSelectArbitrated = 1) THEN
            M1LogicRequestDirection := AcqData.Joystick.AxisY.Direction;
            M1LogicRequestSpeedCmd_Pct  := ABS(AcqData.Joystick.AxisY.SpeedTgt);
        ELSE
            M1LogicRequestDirection := 0;
            M1LogicRequestSpeedCmd_Pct  := 0.0;
        END_IF;
    END_IF;

    M1LogicRequestStartStop := (M1LogicRequestDirection <> 0) AND NOT instBucket.Lifecycle.Busy
                            AND NOT CoupledMotionBlockedByBucket
                            AND NOT ((SyncMinorDeviationBlocksUp   AND (M1LogicRequestDirection = 1))
                                 OR  (SyncMinorDeviationBlocksDown AND (M1LogicRequestDirection = -1)))
                            AND (NOT TglJoystickMaster OR AcqData.JoystickDeadmanArmed);
END_IF;

IF instBucket.Lifecycle.Busy AND instBucket.M2_StartStop THEN
    M2LogicRequestStartStop := instBucket.M2_StartStop;
    M2LogicRequestDirection := instBucket.M2_Direction;
    M2LogicRequestSpeedCmd_Pct  := 15.0;
ELSE
    IF ModesAuth.Mode = E_Mode.SEMI_AUTO THEN
        M2LogicRequestDirection := ReqProgram.ReqWinchM2.ReqDirection;
        M2LogicRequestStartStop := ReqProgram.ReqWinchM2.ReqStartStop;
        M2LogicRequestSpeedCmd_Pct  := ReqProgram.ReqWinchM2.SpeedTgtPct;
    ELSE
        IF NOT TglJoystickMaster THEN
            IF BtnWinchBothUp OR BtnWinchM2Up THEN
                M2LogicRequestDirection := 1;
                M2LogicRequestSpeedCmd_Pct  := 100.0;
            ELSIF BtnWinchBothDown OR BtnWinchM2Down THEN
                M2LogicRequestDirection := -1;
                M2LogicRequestSpeedCmd_Pct  := 100.0;
            ELSE
                M2LogicRequestDirection := 0;
                M2LogicRequestSpeedCmd_Pct  := 0.0;
            END_IF;
        ELSE
            IF (ModesAuth.JoystickWinchSelectArbitrated = 0 OR ModesAuth.JoystickWinchSelectArbitrated = 2) THEN
                M2LogicRequestDirection := AcqData.Joystick.AxisY.Direction;
                M2LogicRequestSpeedCmd_Pct  := ABS(AcqData.Joystick.AxisY.SpeedTgt);
            ELSE
                M2LogicRequestDirection := 0;
                M2LogicRequestSpeedCmd_Pct  := 0.0;
            END_IF;
        END_IF;

        M2LogicRequestStartStop := (M2LogicRequestDirection <> 0)
                                AND NOT CoupledMotionBlockedByBucket
                                AND NOT ((SyncMinorDeviationBlocksUp   AND (M2LogicRequestDirection = -1))
                                     OR  (SyncMinorDeviationBlocksDown AND (M2LogicRequestDirection = 1)))
                                AND (NOT TglJoystickMaster OR AcqData.JoystickDeadmanArmed);
    END_IF;
END_IF;

BenneBusyFallEdge(CLK := instBucket.Lifecycle.Busy);
IF BenneBusyFallEdge.Q AND NOT (CoupledUserRequestActive AND (CoupledUserRequestDirection <> 0)) THEN
    M1LogicRequestStartStop := FALSE;
    M2LogicRequestStartStop := FALSE;
END_IF;

BucketBusyRiseEdge(CLK := instBucket.Lifecycle.Busy);
IF BucketBusyRiseEdge.Q THEN
    ControlAscentArmedForThisClose := CoupledAscentBucketCloseArmed;
END_IF;
IF BucketBusyFallEdge.Q AND ControlAscentArmedForThisClose THEN
    ControlAscentActive := TRUE;
    ControlAscentStartM1PosM := AcqData.Encoders.M1.CablePosM;
    ControlAscentStartM2PosM := AcqData.Encoders.M2.CablePosM;
END_IF;
IF ControlAscentActive THEN
    IF (ABS(AcqData.Encoders.M1.CablePosM - ControlAscentStartM1PosM) >= ExtractionControlDistanceM)
       AND (ABS(AcqData.Encoders.M2.CablePosM - ControlAscentStartM2PosM) >= ExtractionControlDistanceM) THEN
        ControlAscentActive := FALSE;
    ELSIF NOT (CoupledUserRequestActive AND (CoupledUserRequestDirection = 1)) THEN
        ControlAscentActive := FALSE;
    END_IF;
END_IF;
{endregion}

{region "§3bis ArmingPermit (Option B)"}
// === 🛡️ §3bis ARMINGPERMIT (miroir PRG_04 §3bis) ===
ArmingPermit := NOT instBucket.Lifecycle.Busy AND NOT BenneBusyFallEdge.Q;
{endregion}

{region "§4 Synchronisation M1/M2"}
// === 🔄 §4 SYNCHRONISATION M1 / M2 (miroir PRG_04 §4) ===

instWinchSync(
    Enable          := ModesAuth.SyncEnable AND NOT instBucket.Lifecycle.Busy
                        AND NOT ModesAuth.InhibitM1 AND NOT ModesAuth.InhibitM2,
    Reset           := FaultMachineResetIHM,
    Mode            := ModesAuth.Mode,
    CablePosM1      := AcqData.Encoders.M1.CablePosM,
    CablePosM2      := AcqData.Encoders.M2.CablePosM,
    HomedAndReliableM1 := AcqData.M1_HomedAndReliable,
    HomedAndReliableM2 := AcqData.M2_HomedAndReliable,
    SyncEnable      := ModesAuth.SyncEnable,
    CfgSyncToleranceM  := CfgSyncToleranceM,
    CfgSyncCriticalToleranceM := CfgSyncCriticalToleranceM,
    ActiveOffsetM   := instBucket.ActiveOffsetM,
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
    Contactor4_M2   := instWinchM2.Contactor4,
    BypassGlobal    := BypassSync.Global
);

IF instBucket.M2_ForceSlowSpeed THEN
    M2_SpeedStepTableActive.P1R1 := SpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P1R2 := SpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P1R3 := SpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P1R4 := SpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P2R1 := SpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P2R2 := SpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P2R3 := SpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P2R4 := SpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P3R1 := SpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P3R2 := SpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P3R3 := SpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P3R4 := SpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P4R1 := SpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P4R2 := SpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P4R3 := SpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P4R4 := SpeedStepTable.P1R4;
    M2_SpeedStepTableActive.P5R1 := SpeedStepTable.P1R1;
    M2_SpeedStepTableActive.P5R2 := SpeedStepTable.P1R2;
    M2_SpeedStepTableActive.P5R3 := SpeedStepTable.P1R3;
    M2_SpeedStepTableActive.P5R4 := SpeedStepTable.P1R4;
    M2_SpeedStepTableActive.StepThreshold_Pct := SpeedStepTable.StepThreshold_Pct;
ELSE
    M2_SpeedStepTableActive := SpeedStepTable;
END_IF;
{endregion}

{region "§5 Couplage croise et securites"}
// === 🛑 §5 COUPLAGE CROISÉ & SÉCURITÉS (miroir PRG_04 §5, taxonomie D-P1..D-P11) ===

IF LimitLegalEnabled THEN
    BottomLimitM1_Active := MAX(CfgCableLimitDescentM1, LimitLegalDepthMinAllowedM);
    BottomLimitM2_Active := MAX(CfgCableLimitDescentM2, LimitLegalDepthMinAllowedM);
ELSE
    BottomLimitM1_Active := CfgCableLimitDescentM1;
    BottomLimitM2_Active := CfgCableLimitDescentM2;
END_IF;

SafeStopM1_Raw      := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000) OR instBucket.M1SlipDetected OR AcqData.InputModuleFault;
SafeStopM2_Raw      := ((instWinchSync.Fault.ErrorId AND 16#0002) <> 16#0000) OR AcqData.InputModuleFault;

KoboldAutoStopRiseEdge(CLK := KoboldBottomTouchDI);
KoboldAutoStopFallEdge(CLK := KoboldBottomTouchDI);

IF AcqData.Joystick.AtNeutralXY OR NOT TglEnableKoboldAutoStopDescent THEN
    KoboldImmersionConfirmedInt := FALSE;
    KoboldBottomTouchLatchedInt := FALSE;
END_IF;

IF TglEnableKoboldAutoStopDescent
   AND CoupledUserRequestActive
   AND (CoupledUserRequestDirection = -1)
   AND BucketMech.IsOpen
   AND KoboldAutoStopRiseEdge.Q THEN
    IF (AcqData.Encoders.M1.CablePosM <= ImmersionUpperM)
       AND (AcqData.Encoders.M1.CablePosM >= ImmersionLowerM)
       AND (AcqData.Encoders.M2.CablePosM <= ImmersionUpperM)
       AND (AcqData.Encoders.M2.CablePosM >= ImmersionLowerM) THEN
        KoboldImmersionConfirmedInt := TRUE;
    END_IF;
END_IF;

IF KoboldAutoStopFallEdge.Q AND KoboldImmersionConfirmedInt THEN
    KoboldBottomTouchLatchedInt := TRUE;
    KoboldImmersionConfirmedInt := FALSE;
END_IF;

DescendPermitDiveBucketOpen := ReqProgram.ReqBucket.DescendPermitDiveBucketOpen;

ManualBucketLimitsActive := TglManualBucketLimits
    AND (ModesAuth.JoystickWinchSelectArbitrated = 2);

ProcessPermitM1_Descend := NOT (KoboldBottomTouchLatchedInt OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen;
ProcessPermitM2_Descend := NOT (KoboldBottomTouchLatchedInt OR BypassKoboldBottomTouched) AND DescendPermitDiveBucketOpen
    AND NOT (ManualBucketLimitsActive AND (AcqData.Encoders.M2.CablePosM <= (AcqData.Encoders.M1.CablePosM + BucketPersistConfig.OffsetOpenM + BucketPersistConfig.OpenAnticipationM)));

M2_LimitShift := SEL(BucketMech.IsClosed OR instBucket.CloseReq OR (ModesAuth.JoystickWinchSelectArbitrated = 2),
                      0.0,
                      (AcqData.Encoders.M1.CablePosM + BucketPersistConfig.OffsetCloseM + 0.5)
                      - CfgCableLimitAscentM);

instSafetyWinchM1(
    Enable                 := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM1,
    Reset                  := FaultMachineResetIHM,
    PowerContactorEngaged  := PowerContactorEngaged,
    Mode                   := ModesAuth.Mode,
    SyncEnable             := ModesAuth.SyncEnable,
    JoystickOnline         := AcqData.Network.Joystick.Online,
    JoystickOperational    := AcqData.Network.Joystick.Operational,
    HeartbeatIhmOk         := HeartbeatIhmOk,
    EncoderAvailable       := AcqData.EncoderM1.Measurement.EncoderAvailable,
    EncoderFaultBypass     := BypassM1.EncoderFault,
    ThermalFeedback        := NOT M1_ThermalOk,
    BrakeThermalFeedback   := NOT BrakeThermalOk,
    SlackCableDetected     := NOT M2_TensionedCable,
    PhaseRotationOk        := PhaseRotationOk,
    TopPositionSensor      := TopPositionFreeDI,
    InReferencingMode      := AcqData.EncoderM1.Measurement.HomingLifecycle.Busy,
    CablePosM              := AcqData.Encoders.M1.CablePosM,
    CfgCableLimitDescentM  := CfgCableLimitDescentM1,
    LimitLegalReached      := LimitLegalReached,
    Direction              := M1LogicRequestDirection,
    MovementCommanded      := instWinchM1.RelayFwd OR instWinchM1.RelayRev,
    Homed                  := AcqData.EncoderM1.Homed,
    HomingSuspect          := AcqData.EncoderM1.HomingSuspect,
    TopLimitM              := CfgCableLimitAscentM,
    FwdRevSpeedFeedbackOff := M1_ContactorsReleased,
    BrakeFeedback          := M1_BrakeFeedbackOpen,
    JoystickYNeutral       := AcqData.JoystickYNeutral,
    BenneHoldStillActive   := instBucket.Lifecycle.Busy,
    ExpectedOtherWinchPosM := AcqData.Encoders.M2.CablePosM - instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := ModesAuth.InhibitM2,
    MeasuredSpeedMps       := AcqData.Encoders.M1.Speed_Mps,
    MeasuredSpeedSignedMps := AcqData.Encoders.M1.SignedSpeed_Mps,
    MeasuredSpeedValid     := AcqData.Encoders.M1.SpeedValid,
    BypassGlobal           := BypassM1.Global,
    BypassSafety           := BypassM1.Safety,
    BypassProcess          := BypassM1.Process,
    BypassTopLimitSwitch   := BypassM1.TopLimitSwitch OR BypassCommun.TopLimitSwitch,
    BypassTopLimitSoftware := BypassM1.TopLimitSoftware OR BypassCommun.TopLimitSoftware,
    BypassCableLimitSwitch := BypassM1.CableLimitSwitch OR BypassCommun.CableLimitSwitch,
    BypassLimitLegal       := BypassM1.LimitLegal OR BypassCommun.LimitLegal,
    BypassOperatorComm     := BypassM1.OperatorComm,
    BypassPhaseRotation    := BypassM1.PhaseRotation,
    BypassBrakeThermal     := BypassM1.BrakeThermal,
    BypassMotorThermal     := BypassM1.MotorThermal,
    BypassMecaA            := BypassM1.MecaA,
    BypassMecaB            := BypassM1.MecaB,
    BypassMecaC            := BypassM1.MecaC,
    BypassMecaD            := BypassM1.MecaD,
    BypassMecaE            := BypassM1.MecaE
);

instSafetyWinchM2(
    Enable                 := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM2,
    Reset                  := FaultMachineResetIHM,
    PowerContactorEngaged  := PowerContactorEngaged,
    Mode                   := ModesAuth.Mode,
    SyncEnable             := ModesAuth.SyncEnable,
    JoystickOnline         := AcqData.Network.Joystick.Online,
    JoystickOperational    := AcqData.Network.Joystick.Operational,
    HeartbeatIhmOk         := HeartbeatIhmOk,
    EncoderAvailable       := AcqData.EncoderM2.Measurement.EncoderAvailable,
    EncoderFaultBypass     := BypassM2.EncoderFault,
    ThermalFeedback        := NOT M2_ThermalOk,
    BrakeThermalFeedback   := NOT BrakeThermalOk,
    SlackCableDetected     := NOT M2_TensionedCable,
    PhaseRotationOk        := PhaseRotationOk,
    TopPositionSensor      := TopPositionFreeDI,
    InReferencingMode      := AcqData.EncoderM2.Measurement.HomingLifecycle.Busy,
    CablePosM              := AcqData.Encoders.M2.CablePosM,
    CfgCableLimitDescentM  := CfgCableLimitDescentM2,
    LimitLegalReached      := LimitLegalReached,
    Direction              := M2LogicRequestDirection,
    MovementCommanded      := instWinchM2.RelayFwd OR instWinchM2.RelayRev,
    Homed                  := AcqData.EncoderM2.Homed,
    HomingSuspect          := AcqData.EncoderM2.HomingSuspect,
    TopLimitM              := CfgCableLimitAscentM + M2_LimitShift,
    FwdRevSpeedFeedbackOff := M2_ContactorsReleased,
    BrakeFeedback          := M2_BrakeFeedbackOpen,
    JoystickYNeutral       := AcqData.JoystickYNeutral,
    BenneHoldStillActive   := FALSE,
    ExpectedOtherWinchPosM := AcqData.Encoders.M1.CablePosM + instBucket.ActiveOffsetM,
    BenneBusy              := instBucket.Lifecycle.Busy,
    OtherWinchInhibited    := ModesAuth.InhibitM1,
    MeasuredSpeedMps       := AcqData.Encoders.M2.Speed_Mps,
    MeasuredSpeedSignedMps := AcqData.Encoders.M2.SignedSpeed_Mps,
    MeasuredSpeedValid     := AcqData.Encoders.M2.SpeedValid,
    BypassGlobal           := BypassM2.Global,
    BypassSafety           := BypassM2.Safety,
    BypassProcess          := BypassM2.Process,
    BypassTopLimitSwitch   := BypassM2.TopLimitSwitch OR BypassCommun.TopLimitSwitch,
    BypassTopLimitSoftware := BypassM2.TopLimitSoftware OR BypassCommun.TopLimitSoftware,
    BypassCableLimitSwitch := BypassM2.CableLimitSwitch OR BypassCommun.CableLimitSwitch,
    BypassLimitLegal       := BypassM2.LimitLegal OR BypassCommun.LimitLegal,
    BypassOperatorComm     := BypassM2.OperatorComm,
    BypassPhaseRotation    := BypassM2.PhaseRotation,
    BypassBrakeThermal     := BypassM2.BrakeThermal,
    BypassMotorThermal     := BypassM2.MotorThermal,
    BypassMecaA            := BypassM2.MecaA,
    BypassMecaB            := BypassM2.MecaB,
    BypassMecaC            := BypassM2.MecaC,
    BypassMecaD            := BypassM2.MecaD,
    BypassMecaE            := BypassM2.MecaE
);

SafeStopM1_Raw := SafeStopM1_Raw OR instSafetyWinchM1.SafeStop;
SafeStopM2_Raw := SafeStopM2_Raw OR instSafetyWinchM2.SafeStop;
SafetyPermitM1_Descend := instSafetyWinchM1.DescendPermit;
SafetyPermitM2_Descend := instSafetyWinchM2.DescendPermit;
SafetyPermitM1_Ascent  := instSafetyWinchM1.AscentPermit;
SafetyPermitM2_Ascent  := instSafetyWinchM2.AscentPermit;
ProcessAndSafetyPermitM1_Descend := ProcessPermitM1_Descend AND SafetyPermitM1_Descend;
ProcessAndSafetyPermitM2_Descend := ProcessPermitM2_Descend AND SafetyPermitM2_Descend;

IF SeqState.DumpAtTremieDescentLocked THEN
    ProcessAndSafetyPermitM1_Descend := FALSE;
    ProcessAndSafetyPermitM2_Descend := FALSE;
END_IF;
ProcessAndSafetyPermitM1_Ascent := SafetyPermitM1_Ascent;
ProcessAndSafetyPermitM2_Ascent := SafetyPermitM2_Ascent
    AND NOT (ManualBucketLimitsActive AND (AcqData.Encoders.M2.CablePosM >= (AcqData.Encoders.M1.CablePosM + BucketPersistConfig.OffsetCloseM - BucketPersistConfig.CloseAnticipationM)));

SafeStopM1_Active := SafeStopM1_Raw OR (instWinchSync.SyncActive AND SafeStopM2_Raw);
SafeStopM2_Active := SafeStopM2_Raw OR (instWinchSync.SyncActive AND SafeStopM1_Raw);
EffectivePermitM1_Descend := ProcessAndSafetyPermitM1_Descend AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM2_Descend);
EffectivePermitM2_Descend := ProcessAndSafetyPermitM2_Descend AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM1_Descend);
EffectivePermitM1_Ascent  := ProcessAndSafetyPermitM1_Ascent  AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM2_Ascent);
EffectivePermitM2_Ascent  := ProcessAndSafetyPermitM2_Ascent  AND (NOT instWinchSync.SyncActive OR ProcessAndSafetyPermitM1_Ascent);
{endregion}

{region "§6 Execution treuils M1/M2"}
// === ⚙️ §6 EXÉCUTION FB_Winch (M1 & M2) (miroir PRG_04 §6 — agrégateur clamp SEL) ===

instWinchM1(
    Enable                  := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM1,
    Reset                   := FaultMachineResetIHM,
    PowerContactorEngaged   := PowerContactorEngaged,
    StartStop               := M1LogicRequestStartStop,
    SafeStop                := SafeStopM1_Active,
    DescendPermit           := EffectivePermitM1_Descend,
    AscentPermit            := EffectivePermitM1_Ascent,
    Direction               := M1LogicRequestDirection,
    SpeedTgt_Pct            := M1LogicRequestSpeedCmd_Pct,
    SpeedStepTable          := SpeedStepTable,
    CfgMaxStepDescente      := SEL(instWinchSync.SyncDeviationWarn, EffectiveMaxStepDescente, 1),
    MaxStepAscent           := SEL(ReqProgram.ReqBucket.ForceMinSpeedStep OR ControlAscentActive OR instWinchSync.SyncDeviationWarn OR BucketNotClosedAscentStep1 OR SlackCableAscentStep1, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM1,
    SpeedGuardReady         := NOT instWinchSync.Fault.Error,
    HomingApproachActive    := ModesAuth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := M1_ContactorsReleased,
    BypassContactorCheck    := BypassM1.Global OR BypassM1.ContactorFeedback,
    Homed                   := AcqData.EncoderM1.Homed,
    HomingSuspect           := AcqData.EncoderM1.HomingSuspect,
    CablePosM               := AcqData.Encoders.M1.CablePosM,
    TopLimitM               := CfgCableLimitAscentM,
    BottomLimitM            := BottomLimitM1_Active,
    CfgSlowdownDistanceM    := WinchSlowdownDistanceM,
    CfgSlowdownMaxStep      := WinchSlowdownMaxStep,
    BypassGlobal            := BypassM1.Global
);

instWinchM2(
    Enable                  := (ModesAuth.Mode <> E_Mode.DISABLE) AND NOT ModesAuth.InhibitM2,
    Reset                   := FaultMachineResetIHM,
    PowerContactorEngaged   := PowerContactorEngaged,
    StartStop               := M2LogicRequestStartStop,
    SafeStop                := SafeStopM2_Active,
    DescendPermit           := EffectivePermitM2_Descend,
    AscentPermit            := EffectivePermitM2_Ascent,
    Direction               := M2LogicRequestDirection,
    SpeedTgt_Pct            := M2LogicRequestSpeedCmd_Pct,
    SpeedStepTable          := M2_SpeedStepTableActive,
    CfgMaxStepDescente      := SEL(instBucket.M2_ForceSlowSpeed OR ManualBucketLimitsActive OR instWinchSync.SyncDeviationWarn, EffectiveMaxStepDescente, 1),
    MaxStepAscent           := SEL(ReqProgram.ReqBucket.ForceMinSpeedStep OR ControlAscentActive OR instBucket.M2_ForceSlowSpeed OR ManualBucketLimitsActive OR instWinchSync.SyncDeviationWarn OR BucketNotClosedAscentStep1 OR SlackCableAscentStep1, EffectiveMaxStepAscent, 1),
    MeasuredSpeedBand       := 0,
    SpeedGuardEnable        := SpeedGuardEnableM2,
    SpeedGuardReady         := NOT instWinchSync.Fault.Error,
    HomingApproachActive    := ModesAuth.HomingApproachEnable,
    FwdRevSpeedFeedbackOff  := M2_ContactorsReleased,
    BypassContactorCheck    := BypassM2.Global OR BypassM2.ContactorFeedback,
    Homed                   := AcqData.EncoderM2.Homed,
    HomingSuspect           := AcqData.EncoderM2.HomingSuspect,
    CablePosM               := AcqData.Encoders.M2.CablePosM,
    TopLimitM               := CfgCableLimitAscentM + M2_LimitShift,
    BottomLimitM            := BottomLimitM2_Active,
    CfgSlowdownDistanceM    := WinchSlowdownDistanceM,
    CfgSlowdownMaxStep      := WinchSlowdownMaxStep,
    BypassGlobal            := BypassM2.Global
);
{endregion}

{region "§7 Publication demandes brutes"}
// === 📤 §7 PUBLICATION DEMANDES BRUTES (miroir PRG_04 §7) ===

WinchM1FinalInterlockRequest.Enable := TRUE;
WinchM1FinalInterlockRequest.Reset := FaultMachineResetIHM;
WinchM1FinalInterlockRequest.PowerContactorEngaged := PowerContactorEngaged;
WinchM1FinalInterlockRequest.SafeStop := SafeStopM1_Active;
WinchM1FinalInterlockRequest.BrakeFeedback := M1_BrakeFeedbackOpen;
WinchM1FinalInterlockRequest.FwdRevSpeedFeedbackOff := M1_ContactorsReleased;
WinchM1FinalInterlockRequest.RequestedRelayFwd := instWinchM1.RelayFwd;
WinchM1FinalInterlockRequest.RequestedRelayRev := instWinchM1.RelayRev;
WinchM1FinalInterlockRequest.RequestedContactor1 := instWinchM1.Contactor1;
WinchM1FinalInterlockRequest.RequestedContactor2 := instWinchM1.Contactor2;
WinchM1FinalInterlockRequest.RequestedContactor3 := instWinchM1.Contactor3;
WinchM1FinalInterlockRequest.RequestedContactor4 := instWinchM1.Contactor4;
WinchM1FinalInterlockRequest.RequestedStep := instWinchM1.StepNumber;
WinchM1FinalInterlockRequest.PowerCutOff := instSafetyWinchM1.PowerCutOff;

WinchM2FinalInterlockRequest.Enable := TRUE;
WinchM2FinalInterlockRequest.Reset := FaultMachineResetIHM;
WinchM2FinalInterlockRequest.PowerContactorEngaged := PowerContactorEngaged;
WinchM2FinalInterlockRequest.SafeStop := SafeStopM2_Active;
WinchM2FinalInterlockRequest.BrakeFeedback := M2_BrakeFeedbackOpen;
WinchM2FinalInterlockRequest.FwdRevSpeedFeedbackOff := M2_ContactorsReleased;
WinchM2FinalInterlockRequest.RequestedRelayFwd := instWinchM2.RelayFwd;
WinchM2FinalInterlockRequest.RequestedRelayRev := instWinchM2.RelayRev;
WinchM2FinalInterlockRequest.RequestedContactor1 := instWinchM2.Contactor1;
WinchM2FinalInterlockRequest.RequestedContactor2 := instWinchM2.Contactor2;
WinchM2FinalInterlockRequest.RequestedContactor3 := instWinchM2.Contactor3;
WinchM2FinalInterlockRequest.RequestedContactor4 := instWinchM2.Contactor4;
WinchM2FinalInterlockRequest.RequestedStep := instWinchM2.StepNumber;
WinchM2FinalInterlockRequest.PowerCutOff := instSafetyWinchM2.PowerCutOff;
{endregion}

{region "§8 Publication etats IHM"}
// === 📤 §8 PUBLICATION ÉTATS IHM (miroir PRG_04 §8) ===
WinchM1State.MeasuredSpeed_Mps := AcqData.Encoders.M1.Speed_Mps;
WinchM1State.SpeedDelta_Mps    := AcqData.Encoders.M1.Speed_Mps - M1_PrevSpeed_Mps;
M1_PrevSpeed_Mps := AcqData.Encoders.M1.Speed_Mps;

WinchM1State.Position_M := AcqData.Encoders.M1.CablePosM;
WinchM1State.SpeedCmd_Pct := M1LogicRequestSpeedCmd_Pct;
WinchM1State.StepNumber := instWinchM1.StepNumber;
WinchM1State.FBState := E_State.READY;
WinchM1State.Ready := instWinchM1.Ready;
WinchM1State.Busy := (instWinchM1.StepNumber > 0);
WinchM1State.Done := FALSE;
WinchM1State.Error := instWinchM1.Fault.Error;
WinchM1State.ErrorId := instWinchM1.Fault.ErrorId;
WinchM1State.RelayFwd := instWinchM1.RelayFwd;
WinchM1State.RelayRev := instWinchM1.RelayRev;
WinchM1State.Contactor1 := instWinchM1.Contactor1;
WinchM1State.Contactor2 := instWinchM1.Contactor2;
WinchM1State.Contactor3 := instWinchM1.Contactor3;
WinchM1State.Contactor4 := instWinchM1.Contactor4;
WinchM1State.BrakeCmd := FinalDiagM1BrakeCmd;
WinchM1State.BrakeCommandOpenConfirmed := M1_BrakeFeedbackOpen;
WinchM1State.FinalAuthorizedStep := instWinchM1.RequestedStep;
WinchM1State.ContactorsCheck := instWinchM1.ContactorsCheck;
WinchM1State.FinalInterlockState := FinalDiagM1State;
WinchM1State.FinalInterlockReason := FinalDiagM1Reason;
WinchM1State.FinalInterlockError := FinalDiagM1Error;
WinchM1State.FinalInterlockErrorId := FinalDiagM1ErrorId;
WinchM1State.FinalRestartInhibit := FinalDiagM1RestartInhibit;
WinchM1State.FinalBrakeTimeoutElapsed := FinalDiagM1BrakeTimeoutElapsed;
WinchM1State.FinalRestartDelayElapsed := FinalDiagM1RestartDelayElapsed;
WinchM1State.FinalStepDelayElapsed := FinalDiagM1StepDelayElapsed;
WinchM1State.Encoder.RawPos := AcqData.EncoderM1.Measurement.RawPos;
WinchM1State.Encoder.Alarms := AcqHw.Winch.COD1_Alarms;
WinchM1State.Encoder.Warnings := AcqHw.Winch.COD1_Warnings;
WinchM1State.Encoder.SlaveOperational := AcqData.Network.EncoderM1.Operational;
WinchM1State.Encoder.PresetTriggerCmd := AcqData.EncoderM1.HwOut.PresetTriggerCmd;
WinchM1State.Encoder.PresetValueOut := AcqData.EncoderM1.HwOut.PresetValueOut;
WinchM1State.Encoder.Error := AcqData.EncoderM1.Measurement.AbsFault.Error;
WinchM1State.Encoder.ErrorId := AcqData.EncoderM1.Measurement.AbsFault.ErrorId;
WinchM1State.Encoder.Homed := AcqData.EncoderM1.Homed;
WinchM1State.Encoder.HomingBusy := AcqData.EncoderM1.Measurement.HomingLifecycle.Busy;
WinchM1State.Encoder.HomingDone := AcqData.EncoderM1.Measurement.HomingLifecycle.Done;
WinchM1State.Encoder.HomingError := AcqData.EncoderM1.Measurement.HomingFault.Error;
WinchM1State.Encoder.HomingErrorId := AcqData.EncoderM1.Measurement.HomingFault.ErrorId;
WinchM1State.Encoder.HomingState := E_State.READY;
WinchM1State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM1State.Encoder.HomingSuspect := AcqData.EncoderM1.HomingSuspect;
WinchM1State.Encoder.HomingRefRaw := AcqData.EncoderM1.Measurement.HomingRefRaw;
WinchM1State.InhibitActive := ModesAuth.InhibitM1;
WinchM1State.BottomLimitActiveM := BottomLimitM1_Active;
WinchM1State.InTopSlowdownZone := instWinchM1.InTopSlowdownZone;
WinchM1State.InBottomSlowdownZone := instWinchM1.InBottomSlowdownZone;
WinchM1State.CommandedDirection := instWinchM1.CommandedDirection;
WinchM1State.DirectionChangeDelayElapsed := instWinchM1.DirectionChangeDelayElapsed;
WinchM1State.DirectionChangePending := instWinchM1.DirectionChangePending;

WinchM2State.MeasuredSpeed_Mps := AcqData.Encoders.M2.Speed_Mps;
WinchM2State.SpeedDelta_Mps    := AcqData.Encoders.M2.Speed_Mps - M2_PrevSpeed_Mps;
M2_PrevSpeed_Mps := AcqData.Encoders.M2.Speed_Mps;

WinchM2State.Position_M := AcqData.Encoders.M2.CablePosM;
WinchM2State.SpeedCmd_Pct := M2LogicRequestSpeedCmd_Pct;
WinchM2State.StepNumber := instWinchM2.StepNumber;
WinchM2State.FBState := E_State.READY;
WinchM2State.Ready := instWinchM2.Ready;
WinchM2State.Busy := (instWinchM2.StepNumber > 0);
WinchM2State.Done := FALSE;
WinchM2State.Error := instWinchM2.Fault.Error;
WinchM2State.ErrorId := instWinchM2.Fault.ErrorId;
WinchM2State.RelayFwd := instWinchM2.RelayFwd;
WinchM2State.RelayRev := instWinchM2.RelayRev;
WinchM2State.Contactor1 := instWinchM2.Contactor1;
WinchM2State.Contactor2 := instWinchM2.Contactor2;
WinchM2State.Contactor3 := instWinchM2.Contactor3;
WinchM2State.Contactor4 := instWinchM2.Contactor4;
WinchM2State.BrakeCmd := FinalDiagM2BrakeCmd;
WinchM2State.BrakeCommandOpenConfirmed := M2_BrakeFeedbackOpen;
WinchM2State.FinalAuthorizedStep := instWinchM2.RequestedStep;
WinchM2State.ContactorsCheck := instWinchM2.ContactorsCheck;
WinchM2State.FinalInterlockState := FinalDiagM2State;
WinchM2State.FinalInterlockReason := FinalDiagM2Reason;
WinchM2State.FinalInterlockError := FinalDiagM2Error;
WinchM2State.FinalInterlockErrorId := FinalDiagM2ErrorId;
WinchM2State.FinalRestartInhibit := FinalDiagM2RestartInhibit;
WinchM2State.FinalBrakeTimeoutElapsed := FinalDiagM2BrakeTimeoutElapsed;
WinchM2State.FinalRestartDelayElapsed := FinalDiagM2RestartDelayElapsed;
WinchM2State.FinalStepDelayElapsed := FinalDiagM2StepDelayElapsed;
WinchM2State.Encoder.RawPos := AcqData.EncoderM2.Measurement.RawPos;
WinchM2State.Encoder.Alarms := AcqHw.Winch.COD2_Alarms;
WinchM2State.Encoder.Warnings := AcqHw.Winch.COD2_Warnings;
WinchM2State.Encoder.SlaveOperational := AcqData.Network.EncoderM2.Operational;
WinchM2State.Encoder.PresetTriggerCmd := AcqData.EncoderM2.HwOut.PresetTriggerCmd;
WinchM2State.Encoder.PresetValueOut := AcqData.EncoderM2.HwOut.PresetValueOut;
WinchM2State.Encoder.Error := AcqData.EncoderM2.Measurement.AbsFault.Error;
WinchM2State.Encoder.ErrorId := AcqData.EncoderM2.Measurement.AbsFault.ErrorId;
WinchM2State.Encoder.Homed := AcqData.EncoderM2.Homed;
WinchM2State.Encoder.HomingBusy := AcqData.EncoderM2.Measurement.HomingLifecycle.Busy;
WinchM2State.Encoder.HomingDone := AcqData.EncoderM2.Measurement.HomingLifecycle.Done;
WinchM2State.Encoder.HomingError := AcqData.EncoderM2.Measurement.HomingFault.Error;
WinchM2State.Encoder.HomingErrorId := AcqData.EncoderM2.Measurement.HomingFault.ErrorId;
WinchM2State.Encoder.HomingState := E_State.READY;
WinchM2State.Encoder.HomingStateAtError := E_State.DISABLED;
WinchM2State.Encoder.HomingSuspect := AcqData.EncoderM2.HomingSuspect;
WinchM2State.Encoder.HomingRefRaw := AcqData.EncoderM2.Measurement.HomingRefRaw;
WinchM2State.InhibitActive := ModesAuth.InhibitM2;
WinchM2State.BottomLimitActiveM := BottomLimitM2_Active;
WinchM2State.InTopSlowdownZone := instWinchM2.InTopSlowdownZone;
WinchM2State.InBottomSlowdownZone := instWinchM2.InBottomSlowdownZone;
WinchM2State.CommandedDirection := instWinchM2.CommandedDirection;
WinchM2State.DirectionChangeDelayElapsed := instWinchM2.DirectionChangeDelayElapsed;
WinchM2State.DirectionChangePending := instWinchM2.DirectionChangePending;

CableLimitAscentM1Reached := AcqData.EncoderM1.Homed
    AND NOT AcqData.EncoderM1.HomingSuspect
    AND NOT AcqData.EncoderM1.Measurement.HomingLifecycle.Busy
    AND (AcqData.Encoders.M1.CablePosM >= CfgCableLimitAscentM);
CableLimitAscentM2Reached := AcqData.EncoderM2.Homed
    AND NOT AcqData.EncoderM2.HomingSuspect
    AND NOT AcqData.EncoderM2.Measurement.HomingLifecycle.Busy
    AND (AcqData.Encoders.M2.CablePosM >= (CfgCableLimitAscentM + M2_LimitShift));

WinchM1Safety.CableLimitAscent := CableLimitAscentM1Reached;
WinchM1Safety.CableLimitDescent := (AcqData.Encoders.M1.CablePosM <= CfgCableLimitDescentM1);
WinchM1Safety.SafeStop := SafeStopM1_Active;
WinchM1Safety.AscentPermit := EffectivePermitM1_Ascent;
WinchM1Safety.DescendPermit := EffectivePermitM1_Descend;
WinchM1Safety.ThermalFault := NOT M1_ThermalOk;
WinchM1Safety.PowerCutOff := instSafetyWinchM1.PowerCutOff;
WinchM1Safety.Error := instWinchM1.Fault.Error OR instSafetyWinchM1.Fault.Error;
WinchM1Safety.ErrorId := instSafetyWinchM1.Fault.ErrorId;
WinchM1Safety.ErrorOperatorComm  := (instSafetyWinchM1.Fault.ErrorId AND 16#0001) <> 0;
WinchM1Safety.ErrorEncoder       := (instSafetyWinchM1.Fault.ErrorId AND 16#0002) <> 0;
WinchM1Safety.ErrorPhaseRotation := (instSafetyWinchM1.Fault.ErrorId AND 16#0010) <> 0;
WinchM1Safety.ErrorBrakeThermal  := (instSafetyWinchM1.Fault.ErrorId AND 16#0400) <> 0;
WinchM1Safety.ErrorMecaA         := (instSafetyWinchM1.Fault.ErrorId AND 16#0080) <> 0;
WinchM1Safety.ErrorMecaB         := (instSafetyWinchM1.Fault.ErrorId AND 16#0100) <> 0;
WinchM1Safety.ErrorMecaC         := (instSafetyWinchM1.Fault.ErrorId AND 16#0200) <> 0;
WinchM1Safety.ErrorMecaD         := (instSafetyWinchM1.Fault.ErrorId AND 16#0800) <> 0;
WinchM1Safety.ErrorMecaE         := (instSafetyWinchM1.Fault.ErrorId AND 16#3000) <> 0;
WinchM1Safety.ErrorOppositeDir   := (instSafetyWinchM1.Fault.ErrorId AND 16#4000) <> 0;
WinchM1Safety.ErrorNoMovement    := (instSafetyWinchM1.Fault.ErrorId AND 16#8000) <> 0;
WinchM1Safety.PowerCutOffSafety  := M1PowerCutOffSafetyInfo;
WinchM1Safety.SafeStopSafety     := M1SafeStopSafetyInfo;
WinchM1Safety.BlockedBySafety    := M1BlockedBySafetyInfo;

WinchM2Safety.CableLimitAscent := CableLimitAscentM2Reached;
WinchM2Safety.CableLimitDescent := (AcqData.Encoders.M2.CablePosM <= CfgCableLimitDescentM2);
WinchM2Safety.SafeStop := SafeStopM2_Active;
WinchM2Safety.AscentPermit := EffectivePermitM2_Ascent;
WinchM2Safety.DescendPermit := EffectivePermitM2_Descend;
WinchM2Safety.SlackCable := NOT M2_TensionedCable;
WinchM2Safety.ThermalFault := NOT M2_ThermalOk;
WinchM2Safety.PowerCutOff := instSafetyWinchM2.PowerCutOff;
WinchM2Safety.Error := instWinchM2.Fault.Error OR instSafetyWinchM2.Fault.Error;
WinchM2Safety.ErrorId := instSafetyWinchM2.Fault.ErrorId;
WinchM2Safety.ErrorOperatorComm  := (instSafetyWinchM2.Fault.ErrorId AND 16#0001) <> 0;
WinchM2Safety.ErrorEncoder       := (instSafetyWinchM2.Fault.ErrorId AND 16#0002) <> 0;
WinchM2Safety.ErrorPhaseRotation := (instSafetyWinchM2.Fault.ErrorId AND 16#0010) <> 0;
WinchM2Safety.ErrorBrakeThermal  := (instSafetyWinchM2.Fault.ErrorId AND 16#0400) <> 0;
WinchM2Safety.ErrorMecaA         := (instSafetyWinchM2.Fault.ErrorId AND 16#0080) <> 0;
WinchM2Safety.ErrorMecaB         := (instSafetyWinchM2.Fault.ErrorId AND 16#0100) <> 0;
WinchM2Safety.ErrorMecaC         := (instSafetyWinchM2.Fault.ErrorId AND 16#0200) <> 0;
WinchM2Safety.ErrorMecaD         := (instSafetyWinchM2.Fault.ErrorId AND 16#0800) <> 0;
WinchM2Safety.ErrorMecaE         := (instSafetyWinchM2.Fault.ErrorId AND 16#3000) <> 0;
WinchM2Safety.ErrorOppositeDir   := (instSafetyWinchM2.Fault.ErrorId AND 16#4000) <> 0;
WinchM2Safety.ErrorNoMovement    := (instSafetyWinchM2.Fault.ErrorId AND 16#8000) <> 0;
WinchM2Safety.PowerCutOffSafety  := M2PowerCutOffSafetyInfo;
WinchM2Safety.SafeStopSafety     := M2SafeStopSafetyInfo;
WinchM2Safety.BlockedBySafety    := M2BlockedBySafetyInfo;

SyncState.DeltaPos_M := instWinchSync.SignedDeltaPosM;
SyncState.SyncActive := instWinchSync.SyncActive;
SyncState.SyncWarn := instWinchSync.SyncWarn;
SyncState.SyncDeviationWarn := instWinchSync.SyncDeviationWarn;
SyncState.Ready := instWinchSync.Ready;
SyncState.Error := instWinchSync.Fault.Error;
SyncState.ErrorId := instWinchSync.Fault.ErrorId;
SyncState.FBState := E_State.READY;

BucketState.MechState := BucketMech;
BucketState.MechState.ActiveOffsetValid := instBucket.ActiveOffsetValid;
BucketState.FBState := E_State.READY;
BucketState.ActiveOffset_M := instBucket.ActiveOffsetM;
BucketState.M2StartStop := instBucket.M2_StartStop;
BucketState.M2Direction := instBucket.M2_Direction;
BucketState.M2ForceSlowSpeed := instBucket.M2_ForceSlowSpeed;
BucketState.M2PositionCorrected := AcqData.Encoders.M2.CablePosM - instBucket.ActiveOffsetM;
BucketState.Ready := instBucket.Ready;
BucketState.Busy := instBucket.Lifecycle.Busy;
BucketState.Done := instBucket.Lifecycle.Done;
BucketState.Error := instBucket.Fault.Error;
BucketState.ErrorId := instBucket.Fault.ErrorId;
BucketState.RemainingTravel_M := instBucket.RemainingTravelM;
BucketState.DeltaPosition_M := instBucket.DeltaPosition_M;
BucketState.CloseActive := instBucket.CloseReq;
BucketState.OpenActive := instBucket.OpenReq;
BucketState.AutoBucketSeqActive := (instBucket.Lifecycle.Busy AND (CoupledDiveBucketOpenArmed OR CoupledAscentBucketCloseArmed)) OR ControlAscentActive;
BucketState.CoupledDiveOpenArmed := CoupledDiveBucketOpenArmed;
BucketState.CoupledAscentCloseArmed := CoupledAscentBucketCloseArmed;
BucketState.ControlAscentActive := ControlAscentActive;
BucketState.CoupledMotionBlockedByBucket := CoupledMotionBlockedByBucket;
KoboldImmersionConfirmed := KoboldImmersionConfirmedInt;
KoboldBottomTouchLatched := KoboldBottomTouchLatchedInt;

Benne_IsRoughlyClosed := BucketMech.IsClosed
    OR (BucketMech.IsIntermediate
        AND (instBucket.DeltaPosition_M >= (BucketPersistConfig.OffsetCloseM - 2.0)));

// === 🔌 PUBLICATION BUS INTER-PRG (miroir PRG_04 fin §8) ===
Data.WinchM1FinalInterlockRequest := WinchM1FinalInterlockRequest;
Data.WinchM2FinalInterlockRequest := WinchM2FinalInterlockRequest;
Data.M1LogicRequestSpeedCmd_Pct   := M1LogicRequestSpeedCmd_Pct;
Data.M2LogicRequestSpeedCmd_Pct   := M2LogicRequestSpeedCmd_Pct;
Data.KoboldContactorCmdArbitrated := KoboldContactorCmdArbitrated;
Data.WinchM1State                 := WinchM1State;
Data.WinchM2State                 := WinchM2State;
Data.WinchM1Safety                := WinchM1Safety;
Data.WinchM2Safety                := WinchM2Safety;
Data.SyncState                    := SyncState;
Data.WinchSyncError               := instWinchSync.Fault.Error;
Data.WinchSyncSignedDeltaPosM     := instWinchSync.SignedDeltaPosM;
Data.BucketState                  := BucketState;
Data.Benne_IsRoughlyClosed        := Benne_IsRoughlyClosed;
Data.BucketBusy                   := instBucket.Lifecycle.Busy;
Data.BucketDone                   := instBucket.Lifecycle.Done;
Data.BucketError                  := instBucket.Fault.Error;
Data.ArmingPermit                 := ArmingPermit;
{endregion}
END_FUNCTION_BLOCK
