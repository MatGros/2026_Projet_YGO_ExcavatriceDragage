(* =======================================================================
   🎯 FB_CycleMachineHoming — Cycle de referencement machine M1/M2/benne
   ───────────────────────────────────────────────────────────────
   Role : GRAFCET sequentiel 5 etapes (HX0..HX4 + HX7_FAILED) :
          - HX0_REPOS : N1 libre bloque si NOT Homed, M3 verrouille N1/SEMI
            (echappatoire N2), entree par 5s BP joystick au neutre (N1) ou
            BtnStart (N2). Jamais relanceable si MachineHomed = TRUE.
          - HX1_BUCKET_PREPARE : M2 seul palier 1, ouv + ferm sans butees
            soft, garde continue 20s + decompte message, BtnValidate neutre.
          - HX2_CLIMB_TO_TOP : Couple M1+M2 palier 1, montee lente + detente
            cable max 2s par geste, viser avant TOP sans le toucher.
          - HX3_TOP_CLEARANCE : Contact TOP = surcourse/perdu -> coupure
            montee, descente ~4s accumulee apres relachement TOP -> retour HX1.
          - HX4_FINAL_CONFIRM : Arret avant TOP + avertissement + BtnValidate
            neutre -> preset 8.5m M1 + (8.5m + OffsetCloseM) M2 + CommitClose.
   Doc metier : DOC/WFLOW/MISE_EN_SERVICE/PLAN_REFONTE_GRAFCET_HOMING_20261118_v1.0.md
                + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_CycleMachineHoming
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale
    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut / abandon cycle (front)

    // === MODE ARBITRE ===
    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (MAINT_N1 ou MAINT_N2 autorises)
    BootReady                   : BOOL;                                      // --> [HW] Acquisition + codeurs valides apres boot

    // === PERMIS SECURITE ===
    TopPositionSensor           : BOOL;                                      // --> [SAFE] Capteur haut commun M1/M2 (TRUE = atteint)
    WinchesMechanicallyStopped  : BOOL;                                      // --> [SAFE] M1 ET M2 arret mecanique confirme

    // === ACQUISITION HOMING (M1 / M2) ===
    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1
    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2

    // === ETAT BENNE ===
    BucketOffsetValid           : BOOL;                                      // --> [HW] Reference benne persistante valide

    // === PERMIS OPERATEUR (joystick + homme-mort) ===
    DeadmanArmed                : BOOL;                                      // --> [CMD] Homme-mort arme
    RawDeadmanButton            : BOOL := FALSE;                             // --> [HW] BP joystick brut (sert en HX0 N1 quand ArmingPermit=FALSE)
    JoystickDeflected           : BOOL;                                      // --> [CMD] Joystick deflechi (X ou Y hors neutre)
    JoystickPull                : BOOL;                                      // --> [CMD] Manche tire = montee / fermeture benne
    JoystickPush                : BOOL;                                      // --> [CMD] Manche pousse = descente / ouverture benne

    // === VALIDATION OPERATEUR ===
    BtnValidation               : BOOL;                                      // --> [CMD] Bouton validation IHM unifie (HX1, HX2->HX4, HX4)
    StartRequest                : BOOL;                                      // --> [CMD] Bouton Start IHM (HX0 en MAINT_N2)
    BtnConfirmHomingBucket      : BOOL;                                      // --> [CMD] Compat bouton IHM historique HX1

    // === INTERLOCK COUPLAGE E1 & RETOUR ARBITRAGE ===
    JoystickWinchSelectArbitrated : INT;                                     // --> [CMD] Selecteur treuil arbitre aval (0=couple, 2=M2)

    // === MESURES POSITIONS ===
    CablePosM1                  : REAL;                                      // --> [MEAS] Position cable M1 (m)
    CablePosM2                  : REAL;                                      // --> [MEAS] Position cable M2 (m)
    CoherenceLimitM             : REAL := 1.0;                               // --> [CFG] Coherence (compat)

    // === MISE EN SERVICE : forcage de step (encadre) ===
    CfgCommissioningEnable      : BOOL;                                      // --> [CFG] Case mise en service
    CfgForceStepTarget          : INT;                                       // --> [CFG] Step cible [0..5]
    CfgForceStepApply           : BOOL;                                      // --> [CMD] Front d'application forcage

    // === REGLAGES & CONFIGURATION ===
    Cfg                         : ST_fbMachineHomingCycle_Cfg;               // --> [CFG] Reglages + temporisations
END_VAR
VAR_OUTPUT
    // === CONTRAT STANDARD ===
    Ready                       : BOOL;
    Fault                       : ST_Fault;
    Lifecycle                   : ST_Lifecycle;

    // === QUALIFICATION MACHINE ===
    MachineHomed                : BOOL;
    MachineHomingStep           : E_MachineHomingStep := E_MachineHomingStep.IDLE;
    MachineHomingStepAtError    : E_MachineHomingStep := E_MachineHomingStep.IDLE;
    MachineHomingSeqStep        : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingInstruction    : STRING(120);
    MachineHomingActive         : BOOL;
    MachineHomingLossSafeStop   : BOOL;
    MachineHomingFailed         : BOOL;
    HomingModeBActive           : BOOL;

    // === DEMANDES HOMING (M1 / M2) ===
    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;
    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;

    // === ORDRES / PERMIS VERS PRG_03 / PRG_04 ===
    CmdWinchM1                  : ST_ProgramWinchRequest;
    CmdWinchM2                  : ST_ProgramWinchRequest;
    CmdBucketOpen               : BOOL;
    CmdBucketClose              : BOOL;
    CmdWinchSelect              : INT := -1;
    AllowAscent                 : BOOL;
    AllowDescend                : BOOL;
    SoftLimitsOff               : BOOL;
    InvalidateProvisionalDatum  : BOOL;

    // === COMMIT BENNE ===
    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;

    // === VERROU TRANSLATION ===
    M3Locked                    : BOOL;

    // === LATCH & COMPTEUR CONTACT TOP HOMING ===
    TopContactLatched           : BOOL;
    TopContactCount             : UINT;
END_VAR
VAR
    // === SOUS-INSTANCES ===
    instFault                   : FB_FaultCore;
    ResetEdge                   : R_TRIG;
    LatchedEdge                 : R_TRIG;
    StartEdge                   : R_TRIG;
    BtnValidationEdge           : R_TRIG;
    HomingBucketConfirmEdge     : R_TRIG;
    ForceStepApplyEdge          : R_TRIG;

    instCauses                  : ARRAY[0..15] OF ST_FaultCause;

    // === GRAFCET & ETATS INTERNES ===
    SeqStep                     : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS;
    CommitPublished             : BOOL;
    CycleRunning                : BOOL;
    FirstScanDone               : BOOL;
    RawBtnSeenReleased          : BOOL;
    Step1MoveCutoff             : BOOL;
    Step1PresetIssued           : BOOL;
    Step2SlackCutoff            : BOOL;
    Step3ClearanceDone          : BOOL;
    Step4PresetIssued           : BOOL;
    ProvisionalDatumActive      : BOOL;
    ProvisionalAborted          : BOOL;
    ForceStepClamped            : INT;

    // === TEMPORISATIONS ===
    EntryHoldTimer              : TON;
    StepValidateHoldTimer       : TON;
    Step1MoveTimer              : TON;
    Step2SlackTimer             : TON;
    Step3Timer                  : TON;
    Step3AccumTime              : TIME;
    Step3SegTime                : TIME;
    Step3RemainingTime          : TIME;
    Step3TimerRunning           : BOOL;
    ClimbTimer                  : TON;
    HomeAxesTimer               : TON;
    CouplingSettleTimer         : TON;
    CouplingViolationTimer      : TON;
    SettleGraceTimer            : TON;

    // === CALCULS AFFICHAGE ===
    EntryRemSec                 : INT;
    ValRemSec                   : INT;
    Step1RemSec                 : INT;
    Step3RemSec                 : INT;

    // === CONDITIONS INTERMEDIAIRES ===
    BothAxesHomed               : BOOL;
    CommitOrOffsetValid         : BOOL;
    ClimbPermit                 : BOOL;
    Step1MovingCmd              : BOOL;
    Step2SlackCmd               : BOOL;
    Step3DescendEngaged         : BOOL;
    StepValidateAllowed         : BOOL;
    StepValidateHoldActive      : BOOL;
    IsInMovePhase               : BOOL;
    AxisHomingError             : BOOL;
    MotionOutOfPhase            : BOOL;
    ModeChangedInCycle          : BOOL;
    ClimbTimedOut               : BOOL;
    HomeAxesTimedOut            : BOOL;
    TransactionAbort            : BOOL;
    ReHomingAckRequired         : BOOL;
    MachineWasHomed             : BOOL;
    HomingLossLatched           : BOOL;
    MachineHomedRaw             : BOOL;
    AxesDatumRaw                : BOOL;

    // === CONTEXTE MODES & INTERLOCKS ===
    PrevMode                    : E_Mode := E_Mode.DISABLE;
    ModeIsMaint1                : BOOL;
    ModeIsMaint2                : BOOL;
    MaintenanceActive           : BOOL;
    ClimbStepActive             : BOOL;
    ClimbCommandActive          : BOOL;
    CouplingInterlockFault      : BOOL;
    ValidatePressed             : BOOL;
END_VAR
VAR CONSTANT
    CST_CauseHomingLostInMotion : INT := 0;
    CST_CauseClimbTimeout       : INT := 1;
    CST_CauseMotionOutOfPhase   : INT := 2;
    CST_CauseHomingErrorM1      : INT := 3;
    CST_CauseHomingErrorM2      : INT := 4;
    CST_CauseHomeAxesTimeout    : INT := 5;
    CST_CauseCouplingFault      : INT := 6;

    CST_SettleGrace             : TIME := T#3s;
END_VAR

{region "§1 Fronts, remises a zero de tete de scan"}
IF NOT FirstScanDone THEN
    SeqStep              := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingFailed  := FALSE;
    HomingModeBActive    := FALSE;
    RawBtnSeenReleased   := NOT RawDeadmanButton;
    Step1MoveCutoff      := FALSE;
    Step1PresetIssued    := FALSE;
    Step2SlackCutoff     := FALSE;
    Step3ClearanceDone   := FALSE;
    Step3AccumTime       := T#0s;
    Step3SegTime         := T#0s;
    Step3RemainingTime   := T#0s;
    Step3TimerRunning    := FALSE;
    Step3Timer(IN := FALSE, PT := T#0s);
    StepValidateHoldTimer(IN := FALSE, PT := T#0s);
    Step4PresetIssued    := FALSE;
    ProvisionalDatumActive := FALSE;
    ProvisionalAborted     := FALSE;
    TopContactLatched      := FALSE;
    TopContactCount        := 0;
    PrevMode             := Mode;
END_IF;

// Sorties impulsionnelles et permis remis a zero en tete de scan
M1Demand.HomeReq := FALSE; M1Demand.UseDynamicTarget := FALSE; M1Demand.DynamicTarget_M := 0.0; M1Demand.Provisional := FALSE;
M2Demand.HomeReq := FALSE; M2Demand.UseDynamicTarget := FALSE; M2Demand.DynamicTarget_M := 0.0; M2Demand.Provisional := FALSE;
BucketCommit.CommitOpen       := FALSE;
BucketCommit.CommitClose      := FALSE;
BucketCommit.CommitInvalidate := FALSE;
InvalidateProvisionalDatum    := FALSE;
CmdBucketOpen  := FALSE;
CmdBucketClose := FALSE;
CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
CmdWinchSelect := -1;
AllowAscent    := FALSE;
AllowDescend   := FALSE;
SoftLimitsOff  := FALSE;

ResetEdge(CLK := Reset);
LatchedEdge(CLK := Fault.Latched);
StartEdge(CLK := StartRequest);
BtnValidationEdge(CLK := BtnValidation);
HomingBucketConfirmEdge(CLK := BtnConfirmHomingBucket);
ValidatePressed := BtnValidationEdge.Q OR HomingBucketConfirmEdge.Q;

ModeIsMaint1 := (Mode = E_Mode.MAINT_N1);
ModeIsMaint2 := (Mode = E_Mode.MAINT_N2);
MaintenanceActive := ModeIsMaint1 OR ModeIsMaint2;

CycleRunning  := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);
IsInMovePhase := (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE)
              OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP)
              OR (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE);
{endregion}

{region "§2 Conditions intermediaires"}
BothAxesHomed       := M1Status.HomedAndReliable AND M2Status.HomedAndReliable;
CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
ClimbPermit         := DeadmanArmed AND JoystickPull AND NOT JoystickPush;

// Grace deceleration en HX4 / HX7
SettleGraceTimer(IN := (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM)
                       OR (SeqStep = E_MachineHomingTxState.HX7_FAILED), PT := CST_SettleGrace);

AxisHomingError  := M1Status.HomingError OR M2Status.HomingError;
MotionOutOfPhase := CycleRunning AND NOT IsInMovePhase
                    AND NOT WinchesMechanicallyStopped AND SettleGraceTimer.Q;

// Garde de montee HX2 (consommee UNIQUEMENT pendant la montee commandee, gate G511)
ClimbStepActive    := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP);
ClimbCommandActive := ClimbStepActive AND ClimbPermit;
ClimbTimer(IN := ClimbCommandActive, PT := Cfg.CfgTimeoutClimb);
ClimbTimedOut := ClimbStepActive AND (Cfg.CfgTimeoutClimb > T#0s) AND ClimbTimer.Q;
CouplingSettleTimer(IN := ClimbStepActive AND (JoystickWinchSelectArbitrated = 0), PT := T#300ms);

// Garde prise de reference provisoire HX1 (0m) et finale HX4 (8.5m)
HomeAxesTimer(
    IN := ((SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) AND Step1PresetIssued)
          OR ((SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) AND Step4PresetIssued
              AND NOT (M1Status.HomingDone AND M2Status.HomingDone AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy)),
    PT := Cfg.CfgTimeoutHomeAxes
);
HomeAxesTimedOut := (((SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) AND Step1PresetIssued)
                     OR ((SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) AND Step4PresetIssued
                         AND NOT (M1Status.HomingDone AND M2Status.HomingDone AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy)))
                    AND (Cfg.CfgTimeoutHomeAxes > T#0s)
                    AND HomeAxesTimer.Q;

// Violation couplage / selecteur (HX1=M2 seul, HX2/HX3=M1+M2 couple)
CouplingViolationTimer(
    IN := ((((SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP)
             OR (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE))
            AND (JoystickWinchSelectArbitrated <> 0))
           OR ((SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE)
               AND (JoystickWinchSelectArbitrated <> 2)))
          AND (JoystickPull OR JoystickPush),
    PT := T#600ms
);
CouplingInterlockFault := CouplingViolationTimer.Q;

// Changement de mode en cours de cycle (N1<->N2, DISABLE, SEMI_AUTO) : reset propre du graphe vers HX0
ModeChangedInCycle := FirstScanDone AND (Mode <> PrevMode)
                      AND (SeqStep <> E_MachineHomingTxState.HX0_REPOS)
                      AND (SeqStep <> E_MachineHomingTxState.HX7_FAILED);
TransactionAbort := CycleRunning
                    AND NOT ModeChangedInCycle
                    AND (AxisHomingError OR MotionOutOfPhase OR ClimbTimedOut
                         OR HomeAxesTimedOut OR CouplingInterlockFault);
{endregion}

{region "§3 Detection perte de datum"}
AxesDatumRaw    := BothAxesHomed;
MachineHomedRaw := AxesDatumRaw AND CommitOrOffsetValid AND NOT ProvisionalDatumActive
                   AND NOT ProvisionalAborted
                   AND NOT M1Status.HomingProvisional AND NOT M2Status.HomingProvisional
                   AND NOT ReHomingAckRequired;

IF FirstScanDone AND Enable AND NOT ProvisionalDatumActive AND NOT InvalidateProvisionalDatum
   AND NOT M1Status.HomingProvisional AND NOT M2Status.HomingProvisional
   AND NOT MachineHomedRaw AND MachineWasHomed THEN
    IF NOT WinchesMechanicallyStopped THEN
        HomingLossLatched := TRUE;
    END_IF;
    ReHomingAckRequired := TRUE;
END_IF;

IF Enable THEN
    MachineWasHomed := MachineHomedRaw;
END_IF;
MachineHomingLossSafeStop := HomingLossLatched AND NOT WinchesMechanicallyStopped;

IF ResetEdge.Q AND WinchesMechanicallyStopped THEN
    HomingLossLatched   := FALSE;
    ReHomingAckRequired := FALSE;
END_IF;
{endregion}

{region "§4 Purge sur Reset & Forcage mise en service"}
IF ResetEdge.Q OR ModeChangedInCycle
   OR ((SeqStep <> E_MachineHomingTxState.HX0_REPOS) AND (SeqStep <> E_MachineHomingTxState.HX7_FAILED) AND NOT MaintenanceActive) THEN
    IF ProvisionalDatumActive OR Step1PresetIssued OR M1Status.HomingProvisional OR M2Status.HomingProvisional THEN
        InvalidateProvisionalDatum    := TRUE;
        BucketCommit.CommitInvalidate := TRUE;
        ProvisionalDatumActive        := FALSE;
        ProvisionalAborted            := TRUE;
        CommitPublished               := FALSE;
    ELSIF ResetEdge.Q THEN
        ProvisionalAborted            := FALSE;
    END_IF;
    IF ResetEdge.Q THEN
        MachineHomingFailed := FALSE;
        TopContactLatched   := FALSE;
        TopContactCount     := 0;
    END_IF;
    HomingModeBActive   := FALSE;
    Step1MoveCutoff     := FALSE;
    Step1PresetIssued   := FALSE;
    Step2SlackCutoff    := FALSE;
    Step3ClearanceDone  := FALSE;
    Step3AccumTime      := T#0s;
    Step3SegTime        := T#0s;
    Step3RemainingTime  := T#0s;
    Step3TimerRunning   := FALSE;
    Step3Timer(IN := FALSE, PT := T#0s);
    StepValidateHoldTimer(IN := FALSE, PT := T#0s);
    Step4PresetIssued   := FALSE;
    RawBtnSeenReleased  := NOT RawDeadmanButton;
    SeqStep             := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
END_IF;

ForceStepApplyEdge(CLK := CfgForceStepApply);
IF Enable AND CfgCommissioningEnable AND ModeIsMaint2 AND ForceStepApplyEdge.Q THEN
    ForceStepClamped := LIMIT(0, CfgForceStepTarget, 5);
    CASE ForceStepClamped OF
        0: SeqStep := E_MachineHomingTxState.HX0_REPOS;
        1: SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
        2: SeqStep := E_MachineHomingTxState.HX2_CLIMB_TO_TOP;
        3: SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
        4: SeqStep := E_MachineHomingTxState.HX4_FINAL_CONFIRM;
        5: SeqStep := E_MachineHomingTxState.HX7_FAILED;
    END_CASE;
    Step1MoveCutoff     := FALSE;
    Step2SlackCutoff    := FALSE;
    Step3ClearanceDone  := FALSE;
    Step3AccumTime      := T#0s;
    Step3SegTime        := T#0s;
    Step3RemainingTime  := T#0s;
    Step3TimerRunning   := FALSE;
    Step3Timer(IN := FALSE, PT := T#0s);
    Step4PresetIssued   := FALSE;
    IF (ForceStepClamped <= 1) AND (ProvisionalDatumActive OR Step1PresetIssued OR M1Status.HomingProvisional OR M2Status.HomingProvisional) THEN
        InvalidateProvisionalDatum    := TRUE;
        BucketCommit.CommitInvalidate := TRUE;
        ProvisionalDatumActive        := FALSE;
        ProvisionalAborted            := (ForceStepClamped = 0);
        CommitPublished               := FALSE;
        Step1PresetIssued             := FALSE;
    END_IF;
    MachineHomingFailed := FALSE;
END_IF;
{endregion}

{region "§5 Table des causes & socle defaut"}
instCauses[CST_CauseHomingLostInMotion].Active   := HomingLossLatched OR ReHomingAckRequired;
instCauses[CST_CauseHomingLostInMotion].Latching := TRUE;
instCauses[CST_CauseHomingLostInMotion].Texte    := 'Perte de datum machine en mouvement : re-referencer';

instCauses[CST_CauseClimbTimeout].Active   := ClimbTimedOut;
instCauses[CST_CauseClimbTimeout].Latching := TRUE;
instCauses[CST_CauseClimbTimeout].Texte    := 'Montee au capteur haut non aboutie dans le temps imparti';

instCauses[CST_CauseMotionOutOfPhase].Active   := MotionOutOfPhase;
instCauses[CST_CauseMotionOutOfPhase].Latching := TRUE;
instCauses[CST_CauseMotionOutOfPhase].Texte    := 'Mouvement treuil detecte hors phase autorisee du cycle';

instCauses[CST_CauseHomingErrorM1].Active   := CycleRunning AND M1Status.HomingError;
instCauses[CST_CauseHomingErrorM1].Latching := TRUE;
instCauses[CST_CauseHomingErrorM1].Texte    := 'Erreur de homing codeur M1 pendant le referencement conjoint';

instCauses[CST_CauseHomingErrorM2].Active   := CycleRunning AND M2Status.HomingError;
instCauses[CST_CauseHomingErrorM2].Latching := TRUE;
instCauses[CST_CauseHomingErrorM2].Texte    := 'Erreur de homing codeur M2 pendant le referencement conjoint';

instCauses[CST_CauseHomeAxesTimeout].Active   := HomeAxesTimedOut;
instCauses[CST_CauseHomeAxesTimeout].Latching := TRUE;
instCauses[CST_CauseHomeAxesTimeout].Texte    := 'Prise de reference finale non obtenue dans le temps';

instCauses[CST_CauseCouplingFault].Active   := CouplingInterlockFault;
instCauses[CST_CauseCouplingFault].Latching := TRUE;
instCauses[CST_CauseCouplingFault].Texte    := 'Defaut de couplage treuils M1+M2 pendant referencement';

instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§7 Gate Enable"}
IF NOT Enable THEN
    M1Demand.HomeReq := FALSE; M1Demand.UseDynamicTarget := FALSE; M1Demand.DynamicTarget_M := 0.0; M1Demand.Provisional := FALSE;
    M2Demand.HomeReq := FALSE; M2Demand.UseDynamicTarget := FALSE; M2Demand.DynamicTarget_M := 0.0; M2Demand.Provisional := FALSE;
    BucketCommit.CommitOpen  := FALSE;
    BucketCommit.CommitClose := FALSE;
    IF ProvisionalDatumActive OR Step1PresetIssued OR InvalidateProvisionalDatum OR BucketCommit.CommitInvalidate THEN
        InvalidateProvisionalDatum    := TRUE;
        BucketCommit.CommitInvalidate := TRUE;
        ProvisionalDatumActive        := FALSE;
        ProvisionalAborted            := TRUE;
        CommitPublished               := FALSE;
    ELSE
        BucketCommit.CommitInvalidate := FALSE;
        InvalidateProvisionalDatum    := FALSE;
    END_IF;
    CmdBucketOpen  := FALSE;
    CmdBucketClose := FALSE;
    CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
    CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
    CmdWinchSelect := -1;
    AllowAscent    := FALSE;
    AllowDescend   := FALSE;
    SoftLimitsOff  := FALSE;
    Ready          := FALSE;
    Lifecycle.Busy := FALSE;
    Lifecycle.Done := FALSE;
    MachineHomingActive := FALSE;
    M3Locked       := FALSE;
    Step1MoveCutoff := FALSE;
    Step1PresetIssued := FALSE;
    Step2SlackCutoff := FALSE;
    Step3ClearanceDone := FALSE;
    Step3AccumTime := T#0s;
    Step3SegTime := T#0s;
    Step3RemainingTime := T#0s;
    Step3TimerRunning := FALSE;
    Step3Timer(IN := FALSE, PT := T#0s);
    StepValidateHoldTimer(IN := FALSE, PT := T#0s);
    Step4PresetIssued := FALSE;
    SeqStep         := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingStep := E_MachineHomingStep.IDLE;
    MachineHomingInstruction := 'Cycle homing desactive';
    PrevMode := Mode;
    RETURN;
END_IF;
{endregion}

{region "§8 GRAFCET de referencement machine (CASE SeqStep)"}
MachineHomedRaw := AxesDatumRaw AND CommitOrOffsetValid AND NOT ProvisionalDatumActive
                   AND NOT ProvisionalAborted
                   AND NOT M1Status.HomingProvisional AND NOT M2Status.HomingProvisional
                   AND NOT ReHomingAckRequired AND NOT MachineHomingFailed AND NOT Fault.Latched;

IF NOT RawDeadmanButton THEN
    RawBtnSeenReleased := TRUE;
END_IF;

StepValidateAllowed := ((SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) AND NOT Step1MoveCutoff AND NOT Step1PresetIssued)
                    OR ((SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP) AND CouplingSettleTimer.Q AND NOT TopPositionSensor)
                    OR ((SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) AND NOT Step4PresetIssued AND NOT TopPositionSensor);
StepValidateHoldActive := Enable
                          AND MaintenanceActive
                          AND NOT Fault.Latched
                          AND NOT MachineHomingFailed
                          AND StepValidateAllowed
                          AND RawBtnSeenReleased
                          AND RawDeadmanButton
                          AND NOT JoystickDeflected
                          AND WinchesMechanicallyStopped;
StepValidateHoldTimer(IN := StepValidateHoldActive, PT := Cfg.CfgEntryHoldTime);
ValidatePressed := BtnValidationEdge.Q OR HomingBucketConfirmEdge.Q OR StepValidateHoldTimer.Q;

CASE SeqStep OF

    E_MachineHomingTxState.HX0_REPOS:
        CmdWinchSelect := -1;

        // Garde RETAIN post-coupure secteur (B1) : si les codeurs ont redemarre avec un
        // zero provisoire HX1 persistant (coupure/reset pendant HX2..HX4), purge immediate.
        IF M1Status.HomingProvisional OR M2Status.HomingProvisional THEN
            InvalidateProvisionalDatum    := TRUE;
            BucketCommit.CommitInvalidate := TRUE;
            ProvisionalAborted            := TRUE;
            CommitPublished               := FALSE;
        END_IF;

        EntryHoldTimer(
            IN := NOT MachineHomedRaw
                  AND ModeIsMaint1
                  AND BootReady
                  AND NOT Fault.Latched
                  AND NOT MachineHomingFailed
                  AND RawBtnSeenReleased
                  AND RawDeadmanButton
                  AND NOT JoystickDeflected
                  AND WinchesMechanicallyStopped,
            PT := Cfg.CfgEntryHoldTime
        );

        // Verrou absolu (D2) : impossible si machine deja referencee
        IF NOT MachineHomedRaw AND BootReady AND NOT Fault.Latched AND NOT MachineHomingFailed THEN
            IF (ModeIsMaint1 AND EntryHoldTimer.Q)
               OR (ModeIsMaint2 AND StartEdge.Q AND NOT JoystickDeflected AND WinchesMechanicallyStopped) THEN
                Step1MoveCutoff        := FALSE;
                Step1PresetIssued      := FALSE;
                Step2SlackCutoff       := FALSE;
                Step3ClearanceDone     := FALSE;
                Step3AccumTime         := T#0s;
                Step3SegTime           := T#0s;
                Step4PresetIssued      := FALSE;
                ProvisionalDatumActive := FALSE;
                ProvisionalAborted     := FALSE;
                RawBtnSeenReleased     := FALSE;
                SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
            END_IF;
        END_IF;

    E_MachineHomingTxState.HX1_BUCKET_PREPARE:
        // M2 seul palier 1, ouverture + fermeture autorisees sans aucune butee soft
        CmdWinchSelect := 2;
        SoftLimitsOff  := TRUE;

        IF Step1MoveCutoff AND NOT JoystickDeflected AND NOT DeadmanArmed AND NOT RawDeadmanButton THEN
            Step1MoveCutoff := FALSE;
        END_IF;

        Step1MovingCmd := NOT Step1PresetIssued
                          AND (JoystickWinchSelectArbitrated = 2)
                          AND DeadmanArmed
                          AND (JoystickPull XOR JoystickPush);
        Step1MoveTimer(IN := Step1MovingCmd AND NOT Step1MoveCutoff, PT := Cfg.CfgBucketPrepareTimeout);
        IF Step1MoveTimer.Q THEN
            Step1MoveCutoff := TRUE;
        END_IF;

        AllowAscent  := NOT Step1MoveCutoff AND NOT Step1PresetIssued;
        AllowDescend := NOT Step1MoveCutoff AND NOT Step1PresetIssued;

        IF TransactionAbort THEN
            IF ProvisionalDatumActive OR Step1PresetIssued THEN
                InvalidateProvisionalDatum    := TRUE;
                BucketCommit.CommitInvalidate := TRUE;
                ProvisionalDatumActive        := FALSE;
                ProvisionalAborted            := TRUE;
                CommitPublished               := FALSE;
            END_IF;
            Step1PresetIssued   := FALSE;
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF NOT Step1PresetIssued THEN
            IF ValidatePressed AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
                // Zero provisoire codeurs (0m M1, 0m + OffsetCloseM M2) pour monter droit et connaitre etat benne
                M1Demand.HomeReq          := TRUE;
                M1Demand.UseDynamicTarget := TRUE;
                M1Demand.DynamicTarget_M  := 0.0;
                M1Demand.Provisional      := TRUE;
                M2Demand.HomeReq          := TRUE;
                M2Demand.UseDynamicTarget := TRUE;
                M2Demand.DynamicTarget_M  := Cfg.CfgOffsetClose_M;
                M2Demand.Provisional      := TRUE;
                Step1PresetIssued := TRUE;
            END_IF;
        ELSIF BothAxesHomed AND M1Status.HomingDone AND M2Status.HomingDone
              AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy THEN
            BucketCommit.CommitClose := TRUE;
            CommitPublished          := FALSE;
            ProvisionalDatumActive   := TRUE;
            ProvisionalAborted       := FALSE;
            Step1PresetIssued        := FALSE;
            Step2SlackCutoff         := FALSE;
            RawBtnSeenReleased       := FALSE;
            SeqStep := E_MachineHomingTxState.HX2_CLIMB_TO_TOP;
        END_IF;

    E_MachineHomingTxState.HX2_CLIMB_TO_TOP:
        // Couple M1+M2 palier 1 : montee lente + detente cable 2s max par geste.
        // Toucher TopPositionSensor = PERDU / surcourse -> coupure montee et Step 3.
        CmdWinchSelect := 0;
        SoftLimitsOff  := TRUE;

        IF Step2SlackCutoff AND NOT JoystickDeflected THEN
            Step2SlackCutoff := FALSE;
        END_IF;

        Step2SlackCmd := CouplingSettleTimer.Q
                         AND DeadmanArmed
                         AND JoystickPush AND NOT JoystickPull;
        Step2SlackTimer(IN := Step2SlackCmd AND NOT Step2SlackCutoff, PT := Cfg.CfgSlackReliefMaxTime);
        IF Step2SlackTimer.Q THEN
            Step2SlackCutoff := TRUE;
        END_IF;

        AllowAscent  := CouplingSettleTimer.Q AND NOT TopPositionSensor;
        AllowDescend := CouplingSettleTimer.Q AND NOT Step2SlackCutoff;

        IF TransactionAbort THEN
            IF ProvisionalDatumActive THEN
                InvalidateProvisionalDatum    := TRUE;
                BucketCommit.CommitInvalidate := TRUE;
                ProvisionalDatumActive        := FALSE;
                ProvisionalAborted            := TRUE;
                CommitPublished               := FALSE;
            END_IF;
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF TopPositionSensor THEN
            TopContactLatched  := TRUE;
            TopContactCount    := TopContactCount + UINT#1;
            AllowAscent        := FALSE;
            Step3ClearanceDone := FALSE;
            Step3AccumTime     := T#0s;
            Step3SegTime       := T#0s;
            Step3RemainingTime := Cfg.CfgTopClearanceTime;
            Step3TimerRunning  := FALSE;
            Step3Timer(IN := FALSE, PT := T#0s);
            SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
        ELSIF ValidatePressed AND CouplingSettleTimer.Q AND NOT JoystickDeflected
              AND WinchesMechanicallyStopped AND NOT TopPositionSensor THEN
            Step4PresetIssued  := FALSE;
            RawBtnSeenReleased := FALSE;
            SeqStep := E_MachineHomingTxState.HX4_FINAL_CONFIRM;
        END_IF;

    E_MachineHomingTxState.HX3_TOP_CLEARANCE:
        // Contact TOP touche : montee strictement interdite, descente accumulee ~4s
        // apres relachement capteur TOP (independant des codeurs), puis retour HX1.
        CmdWinchSelect := 0;
        SoftLimitsOff  := TRUE;
        AllowAscent    := FALSE;

        IF TopPositionSensor THEN
            Step3AccumTime     := T#0s;
            Step3SegTime       := T#0s;
            Step3RemainingTime := Cfg.CfgTopClearanceTime;
            Step3ClearanceDone := FALSE;
            Step3TimerRunning  := FALSE;
            Step3Timer(IN := FALSE, PT := T#0s);
        ELSE
            Step3DescendEngaged := NOT Step3ClearanceDone
                                   AND (JoystickWinchSelectArbitrated = 0)
                                   AND DeadmanArmed
                                   AND JoystickPush AND NOT JoystickPull;

            IF Step3DescendEngaged THEN
                IF NOT Step3TimerRunning THEN
                    IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
                        Step3RemainingTime := T#0s;
                        Step3ClearanceDone := TRUE;
                    ELSE
                        Step3RemainingTime := Cfg.CfgTopClearanceTime - Step3AccumTime;
                    END_IF;
                    Step3Timer(IN := FALSE, PT := T#0s);
                    Step3TimerRunning := NOT Step3ClearanceDone;
                END_IF;
                IF Step3TimerRunning THEN
                    Step3Timer(IN := TRUE, PT := Step3RemainingTime);
                    Step3SegTime := Step3Timer.ET;
                    IF Step3Timer.Q THEN
                        Step3ClearanceDone := TRUE;
                        Step3AccumTime     := Cfg.CfgTopClearanceTime;
                        Step3SegTime       := T#0s;
                        Step3TimerRunning  := FALSE;
                        Step3Timer(IN := FALSE, PT := T#0s);
                    END_IF;
                END_IF;
            ELSE
                IF Step3TimerRunning THEN
                    Step3Timer(IN := TRUE, PT := Step3RemainingTime);
                    Step3AccumTime := Step3AccumTime + Step3Timer.ET;
                    IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
                        Step3AccumTime     := Cfg.CfgTopClearanceTime;
                        Step3ClearanceDone := TRUE;
                    END_IF;
                    Step3SegTime      := T#0s;
                    Step3TimerRunning := FALSE;
                    Step3Timer(IN := FALSE, PT := T#0s);
                END_IF;
                IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
                    Step3RemainingTime := T#0s;
                ELSE
                    Step3RemainingTime := Cfg.CfgTopClearanceTime - Step3AccumTime;
                END_IF;
            END_IF;
        END_IF;

        AllowDescend := NOT Step3ClearanceDone;

        IF TransactionAbort THEN
            IF ProvisionalDatumActive THEN
                InvalidateProvisionalDatum    := TRUE;
                BucketCommit.CommitInvalidate := TRUE;
                ProvisionalDatumActive        := FALSE;
                ProvisionalAborted            := TRUE;
                CommitPublished               := FALSE;
            END_IF;
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF Step3ClearanceDone AND NOT TopPositionSensor AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
            TopContactLatched  := FALSE;
            Step1MoveCutoff    := FALSE;
            RawBtnSeenReleased := NOT RawDeadmanButton;
            SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
        END_IF;

    E_MachineHomingTxState.HX4_FINAL_CONFIRM:
        // Zero mouvement : avertissement + validation finale -> ecriture 8.5m M1 + (8.5m + OffsetCloseM) M2
        CmdWinchSelect := 0;
        SoftLimitsOff  := FALSE;
        AllowAscent    := FALSE;
        AllowDescend   := FALSE;

        IF TransactionAbort THEN
            IF ProvisionalDatumActive THEN
                InvalidateProvisionalDatum    := TRUE;
                BucketCommit.CommitInvalidate := TRUE;
                ProvisionalDatumActive        := FALSE;
                ProvisionalAborted            := TRUE;
                CommitPublished               := FALSE;
            END_IF;
            Step4PresetIssued   := FALSE;
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF TopPositionSensor THEN
            // Surcourse detectee pendant l'attente -> repli degagement Step 3, annule preset HX4 si arme
            TopContactLatched  := TRUE;
            TopContactCount    := TopContactCount + UINT#1;
            IF Step4PresetIssued THEN
                InvalidateProvisionalDatum    := TRUE;
                BucketCommit.CommitInvalidate := TRUE;
                ProvisionalDatumActive        := FALSE;
                ProvisionalAborted            := TRUE;
                CommitPublished               := FALSE;
            END_IF;
            Step4PresetIssued  := FALSE;
            Step3ClearanceDone := FALSE;
            Step3AccumTime     := T#0s;
            Step3SegTime       := T#0s;
            Step3RemainingTime := Cfg.CfgTopClearanceTime;
            Step3TimerRunning  := FALSE;
            Step3Timer(IN := FALSE, PT := T#0s);
            SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
        ELSIF NOT Step4PresetIssued THEN
            IF ValidatePressed AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
                M1Demand.HomeReq          := TRUE;
                M1Demand.UseDynamicTarget := TRUE;
                M1Demand.DynamicTarget_M  := Cfg.CfgTopHomingTargetM1_M;
                M2Demand.HomeReq          := TRUE;
                M2Demand.UseDynamicTarget := TRUE;
                M2Demand.DynamicTarget_M  := Cfg.CfgTopHomingTarget_M + Cfg.CfgOffsetClose_M;
                Step4PresetIssued := TRUE;
            END_IF;
        ELSIF BothAxesHomed AND M1Status.HomingDone AND M2Status.HomingDone
              AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy AND NOT TopPositionSensor THEN
            BucketCommit.CommitClose := TRUE;
            CommitPublished          := TRUE;
            ProvisionalDatumActive   := FALSE;
            ProvisionalAborted       := FALSE;
            ReHomingAckRequired      := FALSE;
            Step4PresetIssued        := FALSE;
            RawBtnSeenReleased       := NOT RawDeadmanButton;
            SeqStep := E_MachineHomingTxState.HX0_REPOS;
        END_IF;

    E_MachineHomingTxState.HX7_FAILED:
        CmdWinchSelect := -1;
        SoftLimitsOff  := FALSE;
        AllowAscent    := FALSE;
        AllowDescend   := FALSE;

    ELSE
        MachineHomingFailed := TRUE;
        SeqStep := E_MachineHomingTxState.HX7_FAILED;

END_CASE;
{endregion}

{region "§9 Cycle de vie & qualification de sortie"}
CycleRunning := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);

IF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
    CmdWinchSelect := 2;
    SoftLimitsOff  := TRUE;
    AllowAscent    := NOT Step1MoveCutoff AND NOT Step1PresetIssued;
    AllowDescend   := NOT Step1MoveCutoff AND NOT Step1PresetIssued;
ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP) THEN
    CmdWinchSelect := 0;
    SoftLimitsOff  := TRUE;
    AllowAscent    := CouplingSettleTimer.Q AND NOT TopPositionSensor;
    AllowDescend   := CouplingSettleTimer.Q AND NOT Step2SlackCutoff;
ELSIF (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE) THEN
    CmdWinchSelect := 0;
    SoftLimitsOff  := TRUE;
    AllowAscent    := FALSE;
    AllowDescend   := NOT Step3ClearanceDone;
ELSIF (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) THEN
    CmdWinchSelect := 0;
    SoftLimitsOff  := FALSE;
    AllowAscent    := FALSE;
    AllowDescend   := FALSE;
ELSE
    CmdWinchSelect := -1;
    SoftLimitsOff  := FALSE;
    AllowAscent    := FALSE;
    AllowDescend   := FALSE;
END_IF;

CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
MachineHomed := BothAxesHomed AND CommitOrOffsetValid
                AND NOT ProvisionalDatumActive
                AND NOT ProvisionalAborted
                AND NOT M1Status.HomingProvisional AND NOT M2Status.HomingProvisional
                AND (SeqStep <> E_MachineHomingTxState.HX7_FAILED)
                AND NOT MachineHomingFailed AND NOT ReHomingAckRequired
                AND NOT Fault.Latched;

// M3 verrouille des Step 0 en N1/SEMI si non reference (echappatoire N2 preservee en Step 0)
M3Locked             := CycleRunning OR (NOT MachineHomed AND NOT ModeIsMaint2);
MachineHomingActive  := (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE)
                     OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP)
                     OR (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE)
                     OR (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM);
Lifecycle.Busy       := MachineHomingActive;
Lifecycle.Done       := CommitPublished AND (SeqStep = E_MachineHomingTxState.HX0_REPOS);
MachineHomingSeqStep := SeqStep;
{endregion}

{region "§10 Guide operateur — messages ASCII sans accents"}
IF Fault.Latched THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'Echec homing - Acquitter (Reset)';
ELSIF MachineHomingFailed OR (SeqStep = E_MachineHomingTxState.HX7_FAILED) THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'HX7 - Homing abandonne - Acquitter Reset';
ELSIF MachineHomingLossSafeStop THEN
    MachineHomingStep := E_MachineHomingStep.LOSS_SAFESTOP;
    MachineHomingInstruction := 'Reference perdue - Arret controle';
ELSIF MachineHomed AND NOT CycleRunning THEN
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'Homing fait';
ELSIF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
    MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
    IF Step1PresetIssued THEN
        MachineHomingInstruction := 'HX1 - Prise 0m codeurs + benne fermee...';
    ELSIF Step1MoveCutoff THEN
        MachineHomingInstruction := 'HX1 - Delai 20s atteint: relacher neutre et BP';
    ELSIF StepValidateHoldActive THEN
        ValRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime - StepValidateHoldTimer.ET) + DINT#999) / DINT#1000);
        IF ValRemSec < 0 THEN ValRemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX1 - Validation neutre: ',
                                           CONCAT(INT_TO_STRING(ValRemSec), 's (lacher=annul.)'));
    ELSE
        Step1RemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgBucketPrepareTimeout - Step1MoveTimer.ET) + DINT#999) / DINT#1000);
        IF Step1RemSec < 0 THEN Step1RemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX1 - Benne M2 ',
                                           CONCAT(INT_TO_STRING(Step1RemSec), 's (SANS BUTEES) | BP 5s neutre'));
    END_IF;
ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
    IF Step2SlackCutoff THEN
        MachineHomingInstruction := 'HX2 - Detente 2s atteinte: relacher neutre';
    ELSIF TopContactLatched AND TopPositionSensor THEN
        MachineHomingInstruction := 'HX2 - Refus montee: contact TOP encore actif';
    ELSIF StepValidateHoldActive THEN
        ValRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime - StepValidateHoldTimer.ET) + DINT#999) / DINT#1000);
        IF ValRemSec < 0 THEN ValRemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX2 [PROV 0m] Valid 8.5m: ',
                                           CONCAT(INT_TO_STRING(ValRemSec), 's'));
    ELSIF TopContactCount > 0 THEN
        MachineHomingInstruction := CONCAT('HX2 - Approche plus basse (TOP:',
                                           CONCAT(UINT_TO_STRING(TopContactCount), ')'));
    ELSE
        MachineHomingInstruction := 'HX2 [PROV 0m] Monter < TOP (non ref) | BP 5s';
    END_IF;
ELSIF (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE) THEN
    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
    IF TopPositionSensor THEN
        MachineHomingInstruction := 'HX3 - TOP touche: position perdue, degager capteur';
    ELSIF Step3ClearanceDone THEN
        MachineHomingInstruction := 'HX3 - Degagement OK, relacher neutre -> retour HX1';
    ELSE
        Step3RemSec := DINT_TO_INT((TIME_TO_DINT(Step3RemainingTime - Step3SegTime) + DINT#999) / DINT#1000);
        IF Step3RemSec < 0 THEN Step3RemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX3 - Continuer descente degagement: ',
                                           CONCAT(INT_TO_STRING(Step3RemSec), 's'));
    END_IF;
ELSIF (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) THEN
    MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
    IF Step4PresetIssued THEN
        MachineHomingInstruction := 'HX4 - Ecriture references 8.5m + benne...';
    ELSIF StepValidateHoldActive THEN
        ValRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime - StepValidateHoldTimer.ET) + DINT#999) / DINT#1000);
        IF ValRemSec < 0 THEN ValRemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX4 [NON REF] 8.5m+benne: ',
                                           CONCAT(INT_TO_STRING(ValRemSec), 's'));
    ELSE
        MachineHomingInstruction := 'HX4 [NON REF] Calibrer 8.5m+benne? BP 5s';
    END_IF;
ELSIF ModeIsMaint1 THEN
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    IF NOT BootReady THEN
        MachineHomingInstruction := 'HX0 - Attente prets codeurs/boot...';
    ELSIF ProvisionalAborted AND NOT RawDeadmanButton THEN
        MachineHomingInstruction := 'HX0 - Altimetrie non calibree: re-referencer';
    ELSIF RawDeadmanButton AND NOT JoystickDeflected AND RawBtnSeenReleased THEN
        EntryRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime - EntryHoldTimer.ET) + DINT#999) / DINT#1000);
        IF EntryRemSec < 0 THEN EntryRemSec := 0; END_IF;
        MachineHomingInstruction := CONCAT('HX0 - Maintien BP neutre: ',
                                           CONCAT(INT_TO_STRING(EntryRemSec), 's (secours: N2)'));
    ELSE
        EntryRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime) + DINT#999) / DINT#1000);
        MachineHomingInstruction := CONCAT('HX0 - Maintenir BP joy ',
                                           CONCAT(INT_TO_STRING(EntryRemSec), 's neutre (ou passer N2)'));
    END_IF;
ELSIF ModeIsMaint2 THEN
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    IF ProvisionalAborted THEN
        MachineHomingInstruction := 'HX0 - Altimetrie non calibree (N2 secours libre)';
    ELSE
        MachineHomingInstruction := 'HX0 - N2 libre actif | Lancer homing (Start IHM)';
    END_IF;
ELSE
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    IF ProvisionalAborted THEN
        MachineHomingInstruction := 'HX0 - Altimetrie non calibree: passer N1/N2';
    ELSE
        MachineHomingInstruction := 'HX0 - Non reference : passer en MAINT_N1 ou N2';
    END_IF;
END_IF;

IF LatchedEdge.Q THEN
    MachineHomingStepAtError := MachineHomingStep;
END_IF;

Ready := Enable AND NOT Fault.Latched;
PrevMode := Mode;
FirstScanDone := TRUE;
{endregion}

END_FUNCTION_BLOCK
