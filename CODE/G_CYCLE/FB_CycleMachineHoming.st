(* =======================================================================
   🎯 FB_CycleMachineHoming — Cycle de referencement machine M1/M2/benne
   ───────────────────────────────────────────────────────────────
   Role : GRAFCET sequentiel (HX0..HX6 + HX7_FAILED) qui coordonne
             le homing machine selon la specification exploitant du 2026-09-21 :
             fermeture benne palier 1 en HX1, bascule et interlock couplage
             M1+M2 en HX1a (résolution E1), montee palier 1 en HX2, prise
             de reference a la volee sur capteur haut en HX3, controle
             stabilisation/inertie [8.50..8.80m] en HX4 avec max 3 retries,
             degagement zone haute en HX5, qualification MachineHomed en HX6,
             et etat d'echec unifie HX7_FAILED.
   Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
                + DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_REFONTE_SEQUENCE_HOMING.yaml
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_CycleMachineHoming
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale (FALSE => sorties sures, retour HX0)
    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut / abandon cycle (front, jamais conditionne)

    // === MODE ARBITRE ===
    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (referencement : MAINT_N2 seul)
    BootReady                   : BOOL;                                      // --> [HW] Acquisition + codeurs valides apres boot

    // === PERMIS SECURITE ===
    TopPositionSensor           : BOOL;                                      // --> [SAFE] Capteur haut commun M1/M2
    WinchesMechanicallyStopped  : BOOL;                                      // --> [SAFE] M1 ET M2 arret mecanique confirme

    // === ACQUISITION HOMING (M1 / M2) ===
    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1 (Retenue)
    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2 (Benne)

    // === ETAT BENNE ===
    BucketOffsetValid           : BOOL;                                      // --> [HW] Offset benne actif valide (FB_Bucket) — bootstrap datum seulement

    // === PERMIS OPERATEUR (joystick + homme-mort) ===
    DeadmanArmed                : BOOL;                                      // --> [CMD] Homme-mort arme
    JoystickDeflected           : BOOL;                                      // --> [CMD] Joystick defléchi (un axe quelconque) — sert au latch SeenNeutral
    JoystickPull                : BOOL;                                      // --> [CMD] Manche tire vers soi = sens montee treuils / fermeture benne
    JoystickPush                : BOOL;                                      // --> [CMD] Manche pousse = sens descente treuils / ouverture benne

    // === VALIDATION OPERATEUR ===
    BtnValidation               : BOOL;                                      // --> [CMD] BP joystick (homme-mort)
    StartRequest                : BOOL;                                      // --> [CMD] Lancer le cycle (front) — commande IHM dediee
    BtnConfirmHomingBucket      : BOOL;                                      // --> [CMD] Confirmation visuelle fermeture benne cycle homing HX1 (bouton dédié IHM)

    // === INTERLOCK COUPLAGE E1 & RETOUR ARBITRAGE ===
    JoystickWinchSelectArbitrated : INT;                                     // --> [CMD] Selecteur treuil arbitre aval (0=both, 1=M1, 2=M2) pour interlock E1

    // === MESURES POSITIONS POUR CONTROLE STABILISATION HX4 ===
    CablePosM1                  : REAL;                                      // --> [MEAS] Position reelle cable M1 (m)
    CablePosM2                  : REAL;                                      // --> [MEAS] Position reelle cable M2 (m)
    CoherenceLimitM             : REAL := 1.0;                               // --> [CFG] Ecart max autorise entre treuils en stabilisation

    // === MISE EN SERVICE : forcage de step (encadre) ===
    CfgCommissioningEnable      : BOOL;                                      // --> [CFG] Case IHM mise en service homing : deverrouille le forcage de step
    CfgForceStepTarget          : INT;                                       // --> [CFG] Step cible du forcage (0=HX0 .. 8=HX7)
    CfgForceStepApply           : BOOL;                                      // --> [CMD] Applique le forcage (front) — impulsion

    // === REGLAGES & CONFIGURATION ===
    Cfg                         : ST_fbMachineHomingCycle_Cfg;               // --> [CFG] Reglages geometriques + temporisations de garde
END_VAR
VAR_OUTPUT
    // === CONTRAT STANDARD (Ready + Fault) ===
    Ready                       : BOOL;                                      // <-- [STAT] FB actif (Enable ET NOT Fault.Latched)
    Fault                       : ST_Fault;                                  // <-- [SAFE] Socle defaut (rempli par FB_FaultCore)
    Lifecycle                   : ST_Lifecycle;                              // <-- [STAT] Cycle GRAFCET (Busy = cycle de homing en cours)

    // === QUALIFICATION MACHINE ===
    MachineHomed                : BOOL;                                      // <-- [SAFE] Datum machine valide (gate SEMI_AUTO)
    MachineHomingStep           : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [STAT] Etape du guide (echelle de priorite)
    MachineHomingStepAtError    : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [DIAG] Etape figee a l'apparition du defaut (R9)
    MachineHomingSeqStep        : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS; // <-- [DIAG] Step GRAFCET courant
    MachineHomingInstruction    : STRING(120);                               // <-- [DIAG] Consigne operateur en clair (ASCII)
    MachineHomingActive         : BOOL;                                      // <-- [STAT] Cycle en cours (= Lifecycle.Busy)
    MachineHomingLossSafeStop   : BOOL;                                      // <-- [STAT] Demande d'arret controle suite perte de datum en mouvement
    MachineHomingFailed         : BOOL;                                      // <-- [STAT] Derniere sequence abandonnee
    HomingModeBActive           : BOOL;                                      // <-- [STAT] Repli automatique reference a l'arret (Mode B) engage

    // === DEMANDES HOMING (M1 / M2) ===
    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;       // <-- [ACT] Demande de homing conjoint axe M1
    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;       // <-- [ACT] Demande de homing conjoint axe M2

    // === ORDRES MOUVEMENT TREUIL (vers PRG_03 -> PRG_04) ===
    CmdWinchM1                  : ST_ProgramWinchRequest;                     // <-- [ACT] Ordre treuil M1 (montee palier 1)
    CmdWinchM2                  : ST_ProgramWinchRequest;                     // <-- [ACT] Ordre treuil M2 (montee palier 1)

    // === ORDRES BENNE (palier 1, sans FDC logiciel — HX1) ===
    CmdBucketOpen               : BOOL;                                      // <-- [ACT] Ordre ouverture benne palier 1 sans FDC soft
    CmdBucketClose              : BOOL;                                      // <-- [ACT] Ordre fermeture benne palier 1 sans FDC soft

    // === OVERRIDE SELECTEUR TREUIL CYCLE ===
    CmdWinchSelect              : INT := -1;                                 // <-- [ACT] Override selecteur treuil cycle (-1=neutre, 0=forcer couple, 2=forcer benne)

    // === COMMIT BENNE ===
    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;       // <-- [ACT] Publication atomique de l'etat benne (vers FB_Bucket)

    // === VERROU TRANSLATION ===
    M3Locked                    : BOOL;                                      // <-- [STAT] Translation M3 interdite tant que le cycle homing n'est pas en HX0
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    instFault                   : FB_FaultCore;                              // * [INST] Socle defaut transverse
    ResetEdge                   : R_TRIG;                                    // . [LOC] Front montant Reset
    LatchedEdge                 : R_TRIG;                                    // . [LOC] Front montant Fault.Latched (capture R9)
    TopLostEdge                 : F_TRIG;                                    // . [LOC] Front descendant TopPositionSensor

    // === TABLE DES CAUSES DE DEFAUT ===
    instCauses                  : ARRAY[0..15] OF ST_FaultCause;             // . [LOC] Causes en clair pour FB_FaultCore

    // === GRAFCET ===
    SeqStep                     : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS; // . [LOC] Step GRAFCET courant
    CommitPublished             : BOOL;                                      // . [LOC] Commit benne deja publie sur ce datum
    CommitDone                  : BOOL;                                      // . [LOC] Commit CommitClose deja emis (impulsion 1 scan)
    PendingClose                : BOOL;                                      // . [LOC] Fermeture benne confirmee en attente de commit final en HX6
    CycleRunning                : BOOL;                                      // . [LOC] Miroir de (SeqStep <> HX0_REPOS) — cycle engage
    HomeReqDone                 : BOOL;                                      // . [LOC] Impulsion HomeReq M1+M2 deja emise sur ce passage HX3
    SeenNeutral                 : BOOL;                                      // . [LOC] Joystick repasse au neutre depuis l'entree du step d'arret

    // === TEMPORISATIONS DE GARDE ===
    ClimbTimer                  : TON;                                       // . [LOC] Garde HX2 (montee au capteur)
    HomeAxesTimer               : TON;                                       // . [LOC] Garde globale HX3 (prise de reference)
    FlyingHomingTimer           : TON;                                       // . [LOC] Garde essai reference au vol (Mode A) avant bascule Mode B
    StandstillHomeReqDone       : BOOL;                                      // . [LOC] Impulsion HomeReq emise a l'arret mecanique (Mode B)
    CouplingSettleTimer         : TON;                                       // . [LOC] Temporisation dwell de bascule selecteur HX1a (300 ms)
    SettleGraceTimer            : TON;                                       // . [LOC] Fenetre de grace deceleration
    FirstScanDone               : BOOL;                                      // . [LOC] Garde 1er scan : statuts codeurs pas encore stables au boot

    // === FRONTS OPERATEUR ===
    StartEdge                   : R_TRIG;                                    // . [LOC] Front montant StartRequest
    BtnValidationEdge           : R_TRIG;                                    // . [LOC] Front montant BtnValidation (lancement joystick N2)
    HomingBucketConfirmEdge     : R_TRIG;                                    // . [LOC] Front montant BtnConfirmHomingBucket
    ForceStepApplyEdge          : R_TRIG;                                    // . [LOC] Front montant CfgForceStepApply
    ForceStepClamped            : INT;                                       // . [LOC] CfgForceStepTarget borne [0..8]

    // === CONDITIONS INTERMEDIAIRES NOMMEES ===
    BothAxesHomed               : BOOL;                                      // . [LOC] M1 ET M2 references et fiables
    CommitOrOffsetValid         : BOOL;                                      // . [LOC] Datum benne connu (commit publie OU offset valide)
    ClimbPermit                 : BOOL;                                      // . [LOC] Permis operateur maintenu, sens montee
    DescendPermit               : BOOL;                                      // . [LOC] Permis operateur maintenu, sens descente
    BucketPermit                : BOOL;                                      // . [LOC] Permis operateur maintenu, benne
    IsInMovePhase               : BOOL;                                      // . [LOC] Step GRAFCET qui commande un mouvement treuil (HX2)
    AxisHomingError             : BOOL;                                      // . [LOC] Erreur de homing M1 ou M2
    MotionOutOfPhase            : BOOL;                                      // . [LOC] Treuil bouge hors phase mouvement, grace decel ecoulee
    ModeLostDuringCycle         : BOOL;                                      // . [LOC] Sortie de MAINT_N2 alors que le cycle est engage
    ClimbTimedOut               : BOOL;                                      // . [LOC] Garde de montee ecoulee
    HomeAxesTimedOut            : BOOL;                                      // . [LOC] Garde de homing axes ecoulee sans axes homes
    TransactionAbort            : BOOL;                                      // . [LOC] Condition d'abandon fail-safe pendant une phase mouvement
    ReHomingAckRequired         : BOOL;                                      // . [LOC] Bloque MachineHomed jusqu'a un Reset conscient
    MachineWasHomed             : BOOL;                                      // . [LOC] Memorise un datum valide (detection de perte)
    HomingLossLatched           : BOOL;                                      // . [LOC] Perte de datum en mouvement latchee jusqu'a l'arret
    MachineHomedRaw             : BOOL;                                      // . [LOC] Qualification hors Fault
    AxesDatumRaw                : BOOL;                                      // . [LOC] Reference codeurs M1/M2 seule

    // === CONTEXTE MODES & INTERLOCKS ===
    ModeIsMaint2                : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N2
    ModeIsMaint1                : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N1
    MaintenanceActive           : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N1 ou MAINT_N2
    ClimbStepActive             : BOOL;                                      // . [LOC] Step courant = montee couplee (HX2)
    ClimbCommandActive          : BOOL;                                      // . [LOC] Montee REELLEMENT commandee : seule condition qui consomme la garde
    CouplingInterlockFault      : BOOL;                                      // . [LOC] Violation couplage pendant la montee HX2 (WinchSel <> 0)

    // === CONTROLE STABILISATION HX4 ===
    RetryCount                  : INT := 0;                                  // . [LOC] Compteur de tentatives HX4 -> HX1 (max 3)
    StabilizationOk             : BOOL;                                      // . [LOC] Stabilisation inertie conforme [8.50..8.80m]
    StabilizationFailed         : BOOL;                                      // . [LOC] Stabilisation inertie hors plage
END_VAR
VAR CONSTANT
    // === INDICES DE CAUSES (instCauses[]) ===
    CST_CauseHomingLostInMotion : INT := 0;                                  // Perte d'un datum valide pendant un mouvement (Latching)
    CST_CauseClimbTimeout       : INT := 1;                                  // HX2 : capteur haut non atteint dans la garde (Latching)
    CST_CauseMotionOutOfPhase   : INT := 2;                                  // Treuil bouge hors phase mouvement autorisee (Latching)
    CST_CauseHomingErrorM1      : INT := 3;                                  // FB_Encoder M1 signale une erreur de homing (Latching)
    CST_CauseHomingErrorM2      : INT := 4;                                  // FB_Encoder M2 signale une erreur de homing (Latching)
    CST_CauseHomeAxesTimeout    : INT := 5;                                  // HX3 : prise de reference non obtenue dans la garde (Latching)
    CST_CauseCouplingFault      : INT := 6;                                  // HX2 : selecteur treuil non couple (WinchSel <> 0) pendant la montee (Latching)
    CST_CauseStabilizationFault : INT := 7;                                  // HX4 : echec persistant stabilisation apres 3 retries (Latching)

    // === TEMPORISATIONS & DIVERS ===
    CST_SettleGrace             : TIME := T#3s;                              // Grace deceleration a l'entree d'un step d'arret
    CST_StepSlow                : INT  := 1;                                 // Palier de vitesse lent (palier 1 MAX strict)
END_VAR

{region "§1 Fronts, remises a zero de tete de scan, verrou M3"}
// === §1 FRONTS + RAZ TETE DE SCAN + VERROU M3 =========================

// Protection premier scan : forcer repos et etat propre
IF NOT FirstScanDone THEN
    SeqStep              := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingFailed  := FALSE;
    HomingModeBActive    := FALSE;
    StandstillHomeReqDone:= FALSE;
    RetryCount           := 0;
    HomeReqDone          := FALSE;
    PendingClose         := FALSE;
END_IF;

// Sorties impulsionnelles / mouvement : remises a FALSE en tete de scan.
M1Demand.HomeReq := FALSE;
M2Demand.HomeReq := FALSE;
BucketCommit.CommitOpen  := FALSE;
BucketCommit.CommitClose := FALSE;
CmdBucketOpen  := FALSE;
CmdBucketClose := FALSE;
CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
CmdWinchSelect := -1; // Par defaut pas d'override

ResetEdge(CLK := Reset);
LatchedEdge(CLK := Fault.Latched);
TopLostEdge(CLK := TopPositionSensor);
StartEdge(CLK := StartRequest);
BtnValidationEdge(CLK := BtnValidation);
HomingBucketConfirmEdge(CLK := BtnConfirmHomingBucket);

// Miroirs booleens de contexte GRAFCET.
ModeIsMaint1 := (Mode = E_Mode.MAINT_N1);
ModeIsMaint2 := (Mode = E_Mode.MAINT_N2);
MaintenanceActive := ModeIsMaint1 OR ModeIsMaint2;

// Phases de mouvement treuils
IsInMovePhase := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED);
CycleRunning  := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);

// M3Locked est calcule en §9 pour verrouiller des le scan d'entree en cycle.
{endregion}

{region "§2 Conditions intermediaires"}
// === §2 CONDITIONS NOMMEES ============================================
BothAxesHomed       := M1Status.HomedAndReliable AND M2Status.HomedAndReliable;
CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
ClimbPermit         := DeadmanArmed AND JoystickPull;
DescendPermit       := DeadmanArmed AND JoystickPush;
BucketPermit        := DeadmanArmed AND JoystickPull; // HX1 : fermeture uniquement par manche tire

// Fenetre de grace deceleration
SettleGraceTimer(IN := (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK)
                       OR (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK)
                       OR (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE), PT := CST_SettleGrace);

// Conditions d'abandon fail-safe
AxisHomingError  := M1Status.HomingError OR M2Status.HomingError;
MotionOutOfPhase := CycleRunning AND NOT IsInMovePhase
                    AND NOT WinchesMechanicallyStopped AND SettleGraceTimer.Q;

// Garde de montee HX2
ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED);
ClimbCommandActive := ClimbStepActive AND ClimbPermit;
ClimbTimer(IN := ClimbCommandActive, PT := Cfg.CfgTimeoutClimb);
ClimbTimedOut := ClimbStepActive AND ClimbTimer.Q;

// Garde prise de reference HX3
HomeAxesTimer(IN := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE), PT := Cfg.CfgTimeoutHomeAxes);
HomeAxesTimedOut := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) AND HomeAxesTimer.Q AND NOT BothAxesHomed;
FlyingHomingTimer(IN := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) AND NOT HomingModeBActive, PT := Cfg.CfgTimeoutFlyingHoming);

// Violation couplage E1
CouplingInterlockFault := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED)
                          AND (JoystickWinchSelectArbitrated <> 0);

// Sortie de MAINT_N2 alors qu'un step mouvement/cycle est engage : abandon fail-safe.
ModeLostDuringCycle := CycleRunning AND NOT ModeIsMaint2;
TransactionAbort := CycleRunning
                    AND (AxisHomingError OR MotionOutOfPhase OR ClimbTimedOut
                         OR HomeAxesTimedOut
                         OR CouplingInterlockFault OR ModeLostDuringCycle);
{endregion}

{region "§3 Detection perte de datum"}
// === §3 PERTE DE DATUM ================================================
AxesDatumRaw    := BothAxesHomed;
MachineHomedRaw := AxesDatumRaw AND CommitOrOffsetValid AND NOT ReHomingAckRequired;

IF FirstScanDone AND NOT MachineHomedRaw AND MachineWasHomed THEN
    IF NOT WinchesMechanicallyStopped THEN
        HomingLossLatched := TRUE;
    END_IF;
    ReHomingAckRequired := TRUE;
END_IF;

MachineWasHomed := MachineHomedRaw;

MachineHomingLossSafeStop := HomingLossLatched AND NOT WinchesMechanicallyStopped;

IF ResetEdge.Q AND WinchesMechanicallyStopped THEN
    HomingLossLatched   := FALSE;
    ReHomingAckRequired := FALSE;
END_IF;
{endregion}

{region "§4 Purge sur Reset & Forcage mise en service"}
// === §4 PURGE SUR RESET ===============================================
IF ResetEdge.Q THEN
    MachineHomingFailed  := FALSE;
    HomingModeBActive    := FALSE;
    StandstillHomeReqDone:= FALSE;
    PendingClose         := FALSE;
    CommitDone           := FALSE;
    HomeReqDone          := FALSE;
    RetryCount           := 0;
    SeqStep              := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
END_IF;

// §4bis Forcage de step de mise en service (encadre)
ForceStepApplyEdge(CLK := CfgForceStepApply);
IF CfgCommissioningEnable AND ModeIsMaint2 AND ForceStepApplyEdge.Q THEN
    ForceStepClamped := LIMIT(0, CfgForceStepTarget, 8);
    CASE ForceStepClamped OF
        0: SeqStep := E_MachineHomingTxState.HX0_REPOS;
        1: SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
        2: SeqStep := E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK;
        3: SeqStep := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
        4: SeqStep := E_MachineHomingTxState.HX3_FLYING_REFERENCE;
        5: SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
        6: SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
        7: SeqStep := E_MachineHomingTxState.HX6_HOMED_SUCCESS;
        8: SeqStep := E_MachineHomingTxState.HX7_FAILED;
    END_CASE;
    HomeReqDone         := FALSE;
    PendingClose        := FALSE;
    CommitDone          := FALSE;
    MachineHomingFailed := FALSE;
END_IF;
{endregion}

{region "§5 Table des causes & socle defaut"}
// === §5 TABLE DES CAUSES + SOCLE DEFAUT ==============================
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
instCauses[CST_CauseHomeAxesTimeout].Texte    := 'Prise de reference capteur haut non obtenue dans le temps';

instCauses[CST_CauseCouplingFault].Active   := CouplingInterlockFault;
instCauses[CST_CauseCouplingFault].Latching := TRUE;
instCauses[CST_CauseCouplingFault].Texte    := 'Defaut de couplage treuils M1+M2 en phase montee';

instCauses[CST_CauseStabilizationFault].Active   := (SeqStep = E_MachineHomingTxState.HX7_FAILED) AND (RetryCount >= 3);
instCauses[CST_CauseStabilizationFault].Latching := TRUE;
instCauses[CST_CauseStabilizationFault].Texte    := 'Stabilisation inertie treuils hors plage apres 3 tentatives';

// Socle defaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§6 Initiation du cycle"}
// === §6 INITIATION DU CYCLE ===========================================
// Le cycle ne s'auto-arme JAMAIS spontanement (securite machine, actionneurs
// sollicites des HX1). L'initiation exige une action consciente de l'operateur
// en mode MAINT_N2 (StartRequest sur IHM ou BtnValidation sur joystick).
{endregion}

{region "§7 Gate Enable"}
// === §7 GATE ENABLE ===================================================
IF NOT Enable THEN
    M1Demand.HomeReq         := FALSE;
    M2Demand.HomeReq         := FALSE;
    BucketCommit.CommitOpen  := FALSE;
    BucketCommit.CommitClose := FALSE;
    CmdBucketOpen            := FALSE;
    CmdBucketClose           := FALSE;
    CmdWinchM1.RunRequest    := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
    CmdWinchM2.RunRequest    := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
    CmdWinchSelect           := -1;
    Ready                    := FALSE;
    Lifecycle.Busy           := FALSE;
    Lifecycle.Done           := FALSE;
    MachineHomingActive      := FALSE;
    M3Locked                 := FALSE;
    MachineHomed             := FALSE;
    MachineHomingLossSafeStop := FALSE;
    CommitPublished          := FALSE;
    CommitDone               := FALSE;
    PendingClose             := FALSE;
    HomingModeBActive        := FALSE;
    StandstillHomeReqDone    := FALSE;
    RetryCount               := 0;
    SeqStep                  := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingSeqStep     := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingStep        := E_MachineHomingStep.IDLE;
    MachineHomingInstruction := 'Cycle homing desactive';
    RETURN;
END_IF;
{endregion}

{region "§8 GRAFCET de referencement machine (CASE SeqStep)"}
// === §8 GRAFCET (CASE SeqStep) ======================================
CASE SeqStep OF

    E_MachineHomingTxState.HX0_REPOS:
        // Etape initiale pure : aucune action.
        CmdWinchSelect := -1;
        IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 THEN
            HomeReqDone := FALSE;
            RetryCount  := 0;
            SeqStep     := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
        END_IF;

    E_MachineHomingTxState.HX1_BUCKET_PREPARE:
        // Decision & Fermeture benne operateur :
        // WinchSel=2 force, FDC benne logiciel inhibe, vitesse plafonnee palier 1.
        CmdWinchSelect := 2;
        IF BucketPermit AND JoystickPull THEN
            CmdBucketClose := TRUE;
        END_IF;

        IF ModeLostDuringCycle OR MotionOutOfPhase THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF HomingBucketConfirmEdge.Q AND NOT JoystickDeflected THEN
            // Validation par 1 seul appui bouton dedie IHM, manche au neutre
            PendingClose := TRUE;
            CommitDone   := FALSE;
            SeqStep      := E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK;
        END_IF;

    E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK:
        // Bascule WinchSel=0, reactivation FDC benne.
        // Interlock bloquant E1 : attente confirmation couplage aval effectif.
        CmdWinchSelect := 0;
        CouplingSettleTimer(IN := (JoystickWinchSelectArbitrated = 0), PT := T#300ms);

        IF ModeLostDuringCycle OR AxisHomingError THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF (JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped THEN
            SeenNeutral := NOT JoystickDeflected;
            SeqStep     := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
        END_IF;

    E_MachineHomingTxState.HX2_CLIMB_COUPLED:
        // Montee couplee M1+M2 palier 1 MAX vers capteur haut.
        CmdWinchSelect := 0;
        IF ClimbPermit AND (JoystickWinchSelectArbitrated = 0) THEN
            CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqAscent := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
            CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqAscent := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
        END_IF;

        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF TopPositionSensor THEN
            M1Demand.HomeReq      := TRUE;
            M2Demand.HomeReq      := TRUE;
            HomeReqDone           := TRUE;
            HomingModeBActive     := FALSE;
            StandstillHomeReqDone := FALSE;
            SeqStep               := E_MachineHomingTxState.HX3_FLYING_REFERENCE;
        END_IF;

    E_MachineHomingTxState.HX3_FLYING_REFERENCE:
        // Referencement conjoint M1+M2 sur capteur haut :
        // Mode A "a la volee" prioritaire, avec repli automatique en Mode B "a l'arret".
        CmdWinchSelect := 0;

        // --- MODE A : PRISE DE REFERENCE A LA VOLEE ---
        IF NOT HomingModeBActive THEN
            // Impulsion initiale de homing au vol si pas encore emise au franchissement
            IF NOT HomeReqDone THEN
                M1Demand.HomeReq := TRUE;
                M2Demand.HomeReq := TRUE;
                HomeReqDone      := TRUE;
            END_IF;

            // En vol, si les codeurs confirment -> succes immediat Mode A
            IF BothAxesHomed THEN
                SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
            // Repli automatique Mode B si le preset ne se confirme pas dans le temps imparti (3s)
            // OU si les treuils s'arretent ou si le manche est relache
            ELSIF FlyingHomingTimer.Q OR WinchesMechanicallyStopped OR NOT JoystickDeflected THEN
                HomingModeBActive     := TRUE;
                StandstillHomeReqDone := FALSE;
            END_IF;

        // --- MODE B : REPLI AUTOMATIQUE A L'ARRET ---
        ELSE
            // En repli Mode B : aucun ordre de mouvement emis, arret mecanique confirme attendu
            IF WinchesMechanicallyStopped THEN
                // A l'arret physique complet, re-emission impulsionnelle de HomeReq
                IF NOT StandstillHomeReqDone THEN
                    M1Demand.HomeReq      := TRUE;
                    M2Demand.HomeReq      := TRUE;
                    StandstillHomeReqDone := TRUE;
                END_IF;

                // Validation prise de reference a l'arret
                IF BothAxesHomed THEN
                    SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
                END_IF;
            END_IF;
        END_IF;

        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        END_IF;

    E_MachineHomingTxState.HX4_STABILIZATION_CHECK:
        // Arret treuils, controle inertie [8.50..8.80m] et concordance codeurs.
        CmdWinchSelect := 0;
        SeenNeutral := NOT JoystickDeflected;

        StabilizationOk := WinchesMechanicallyStopped AND SeenNeutral
                           AND (CablePosM1 >= Cfg.CfgStabilizationMinM) AND (CablePosM1 <= Cfg.CfgStabilizationMaxM)
                           AND (CablePosM2 >= Cfg.CfgStabilizationMinM) AND (CablePosM2 <= Cfg.CfgStabilizationMaxM)
                           AND (ABS(CablePosM1 - CablePosM2) <= CoherenceLimitM);

        StabilizationFailed := WinchesMechanicallyStopped AND SeenNeutral AND NOT StabilizationOk;

        IF ModeLostDuringCycle OR AxisHomingError THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF StabilizationOk THEN
            SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
        ELSIF StabilizationFailed THEN
            RetryCount := RetryCount + 1;
            IF RetryCount >= 3 THEN
                MachineHomingFailed := TRUE;
                SeqStep := E_MachineHomingTxState.HX7_FAILED;
            ELSE
                // Repositionnement et nouvelle tentative : retour en preparation benne
                SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
            END_IF;
        END_IF;

    E_MachineHomingTxState.HX5_RELEASE_CLEARANCE:
        // Degagement zone haute, confirmation joystick au neutre.
        CmdWinchSelect := 0;
        IF ModeLostDuringCycle OR AxisHomingError THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HX7_FAILED;
        ELSIF NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
            SeqStep := E_MachineHomingTxState.HX6_HOMED_SUCCESS;
        END_IF;

    E_MachineHomingTxState.HX6_HOMED_SUCCESS:
        // Validation finale : MachineHomed := TRUE, commit atomique benne.
        CmdWinchSelect := 0;
        IF NOT CommitDone THEN
            BucketCommit.CommitClose := PendingClose;
            CommitPublished          := TRUE;
            CommitDone               := TRUE;
        ELSE
            PendingClose := FALSE;
            SeqStep      := E_MachineHomingTxState.HX0_REPOS;
        END_IF;

    E_MachineHomingTxState.HX7_FAILED:
        // Echec sequence unifie : sorties a 0, attente Reset conscient en MAINT_N2.
        CmdWinchSelect := -1;
        ;

END_CASE;
{endregion}

{region "§9 Cycle de vie & qualification de sortie"}
// === §9 CYCLE DE VIE + QUALIFICATION ================================
CycleRunning := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);

// Selection treuil demandee par le cycle
IF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
    CmdWinchSelect := 2;
ELSIF (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK)
   OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED)
   OR (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE)
   OR (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK)
   OR (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE)
   OR (SeqStep = E_MachineHomingTxState.HX6_HOMED_SUCCESS) THEN
    CmdWinchSelect := 0;
ELSE
    CmdWinchSelect := -1;
END_IF;

M3Locked             := CycleRunning;
MachineHomingActive  := CycleRunning;
Lifecycle.Busy       := CycleRunning;
Lifecycle.Done       := CommitPublished AND (SeqStep = E_MachineHomingTxState.HX0_REPOS);
MachineHomingSeqStep := SeqStep;

CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
MachineHomed := BothAxesHomed AND CommitOrOffsetValid
                AND (SeqStep <> E_MachineHomingTxState.HX7_FAILED)
                AND NOT MachineHomingFailed AND NOT ReHomingAckRequired
                AND NOT Fault.Latched;
{endregion}

{region "§10 Guide operateur — echelle de priorite"}
// === §10 GUIDE OPERATEUR (echelle de priorite) ======================
IF Fault.Latched THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'Erreur ou Echec homing - Acquitter (Reset)';
ELSIF MachineHomingFailed OR (SeqStep = E_MachineHomingTxState.HX7_FAILED) THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'HX7 - Homing incomplet - Acquitter Reset N2';
ELSIF MachineHomingLossSafeStop THEN
    MachineHomingStep := E_MachineHomingStep.LOSS_SAFESTOP;
    MachineHomingInstruction := 'Reference perdue - Arret controle';
ELSIF MachineHomed AND NOT CycleRunning THEN
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := '';
ELSIF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
    MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
    MachineHomingInstruction := 'HX1 - RefHoming Fermer benne, valider sur IHM';
ELSIF (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
    MachineHomingInstruction := 'HX1a - RefHoming Verif couplage M1+M2';
ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
    MachineHomingInstruction := 'HX2 - RefHoming Tirer JOY palier 1 vers haut';
ELSIF (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) THEN
    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
    IF HomingModeBActive THEN
        IF NOT WinchesMechanicallyStopped THEN
            MachineHomingInstruction := 'HX3 - Repli arret (Mode B) : attente arret treuils';
        ELSE
            MachineHomingInstruction := 'HX3 - Repli arret (Mode B) : reference conjointement';
        END_IF;
    ELSE
        MachineHomingInstruction := 'HX3 - RefHoming Prise de reference au vol';
    END_IF;
ELSIF (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
    MachineHomingInstruction := 'HX4 - RefHoming Arret et controle inertie';
ELSIF (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
    MachineHomingInstruction := 'HX5 - RefHoming Relacher JOY au neutre';
ELSIF (SeqStep = E_MachineHomingTxState.HX6_HOMED_SUCCESS) THEN
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'HX6 - RefHoming Machine referencee';
ELSIF NOT M1Status.HomedAndReliable AND NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    IF Mode = E_Mode.MAINT_N2 THEN
        MachineHomingInstruction := 'HX0 - RefHoming M1+M2 non ref - Lancer sur IHM';
    ELSIF Mode = E_Mode.MAINT_N1 THEN
        MachineHomingInstruction := 'HX0 - M1+M2 non ref - Homing unitaire possible';
    ELSE
        MachineHomingInstruction := 'HX0 - M1+M2 non referencies';
    END_IF;
ELSIF NOT M1Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M1_NOT_HOMED;
    IF Mode = E_Mode.MAINT_N2 THEN
        MachineHomingInstruction := 'HX0 - RefHoming M1 non ref - Lancer sur IHM';
    ELSIF Mode = E_Mode.MAINT_N1 THEN
        MachineHomingInstruction := 'HX0 - M1 non ref - Homing unitaire possible';
    ELSE
        MachineHomingInstruction := 'HX0 - M1 non reference';
    END_IF;
ELSIF NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M2_NOT_HOMED;
    IF Mode = E_Mode.MAINT_N2 THEN
        MachineHomingInstruction := 'HX0 - RefHoming M2 non ref - Lancer sur IHM';
    ELSIF Mode = E_Mode.MAINT_N1 THEN
        MachineHomingInstruction := 'HX0 - M2 non ref - Homing unitaire possible';
    ELSE
        MachineHomingInstruction := 'HX0 - M2 non reference';
    END_IF;
ELSIF NOT (CommitPublished OR BucketOffsetValid) THEN
    IF Mode = E_Mode.MAINT_N2 THEN
        MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
        MachineHomingInstruction := 'HX0 - RefHoming Lancer le homing (etat benne)';
    ELSIF Mode = E_Mode.MAINT_N1 THEN
        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
        MachineHomingInstruction := 'HX0 - Offset benne inconnu';
    ELSE
        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
        MachineHomingInstruction := 'HX0 - Offset benne inconnu';
    END_IF;
ELSE
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'Reference machine valide';
END_IF;

// Capture R9 de l'etape a l'apparition du defaut latche
IF LatchedEdge.Q THEN
    MachineHomingStepAtError := MachineHomingStep;
END_IF;

Ready := Enable AND NOT Fault.Latched;
FirstScanDone := TRUE;
{endregion}

END_FUNCTION_BLOCK
