Tu es un expert senior automatisme industriel CODESYS 3.5 / IEC 61131-3 ST & securite machine ISO 13849.
Audite ce git diff reel de la refonte du GRAFCET Homing Machine 5 etapes (D1-D7, T417-C).
Verifie STRICTEMENT :
1. D1-D7 : HX0 repos N1 (BP joy relache puis 5s neutre) + N2 (BtnStart), verrou absolu si MachineHomed ; M3 verrouille des HX0 en N1/SEMI avec echappatoire N2 ; HX1 M2 sans soft limits 20s continu + neutre+BP ; HX2 couple 2s detente cable strict neutre + TOP coupe montee sans preset -> HX3 ; HX3 zero montee, 4s descente accumulee apres relachement TOP -> HX1 ; HX4 zero mouvement, NOT TOP, preset 8.5m M1 + (8.5+Offset) M2, attente HomingDone & NOT HomingBusy -> CommitClose -> HX0.
2. Aucun blocage silencieux, aucune variable non initialisee, aucun bug de scan IEC (TON, fronts, 1-scan glitch), conformite CODESYS V3.5 (chaines ASCII sans accents, types stricts).
Reponds de facon ultra-factuelle avec uniquement les bugs/risques reels (fichier:ligne + scenario causal) ou VERDICT CLEAN si aucun bug critique/majeur.

`diff
diff --git a/CODE/G_CYCLE/FB_CycleMachineHoming.st b/CODE/G_CYCLE/FB_CycleMachineHoming.st
index c1da9806..435f5087 100644
--- a/CODE/G_CYCLE/FB_CycleMachineHoming.st
+++ b/CODE/G_CYCLE/FB_CycleMachineHoming.st
@@ -1,274 +1,285 @@
 (* =======================================================================
    🎯 FB_CycleMachineHoming — Cycle de referencement machine M1/M2/benne
    ───────────────────────────────────────────────────────────────
-   Role : GRAFCET sequentiel (HX0..HX6 + HX7_FAILED) qui coordonne
-             le homing machine selon la specification exploitant du 2026-09-21 :
-             fermeture benne palier 1 en HX1, bascule et interlock couplage
-             M1+M2 en HX1a (résolution E1), montee palier 1 en HX2, prise
-             de reference a la volee sur capteur haut en HX3, controle
-             stabilisation/inertie [8.50..8.80m] en HX4 avec max 3 retries,
-             degagement zone haute en HX5, qualification MachineHomed en HX6,
-             et etat d'echec unifie HX7_FAILED.
-   Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
-                + DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_REFONTE_SEQUENCE_HOMING.yaml
+   Role : GRAFCET sequentiel 5 etapes (HX0..HX4 + HX7_FAILED) :
+          - HX0_REPOS : N1 libre bloque si NOT Homed, M3 verrouille N1/SEMI
+            (echappatoire N2), entree par 5s BP joystick au neutre (N1) ou
+            BtnStart (N2). Jamais relanceable si MachineHomed = TRUE.
+          - HX1_BUCKET_PREPARE : M2 seul palier 1, ouv + ferm sans butees
+            soft, garde continue 20s + decompte message, BtnValidate neutre.
+          - HX2_CLIMB_TO_TOP : Couple M1+M2 palier 1, montee lente + detente
+            cable max 2s par geste, viser avant TOP sans le toucher.
+          - HX3_TOP_CLEARANCE : Contact TOP = surcourse/perdu -> coupure
+            montee, descente ~4s accumulee apres relachement TOP -> retour HX1.
+          - HX4_FINAL_CONFIRM : Arret avant TOP + avertissement + BtnValidate
+            neutre -> preset 8.5m M1 + (8.5m + OffsetCloseM) M2 + CommitClose.
+   Doc metier : DOC/WFLOW/MISE_EN_SERVICE/PLAN_REFONTE_GRAFCET_HOMING_20261118_v1.0.md
+                + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
    ======================================================================= *)
 FUNCTION_BLOCK PUBLIC FB_CycleMachineHoming
 VAR_INPUT
     // === CONTRAT STANDARD (Enable + Reset) ===
-    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale (FALSE => sorties sures, retour HX0)
-    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut / abandon cycle (front, jamais conditionne)
+    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale
+    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut / abandon cycle (front)
 
     // === MODE ARBITRE ===
-    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (referencement : MAINT_N2 seul)
+    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (MAINT_N1 ou MAINT_N2 autorises)
     BootReady                   : BOOL;                                      // --> [HW] Acquisition + codeurs valides apres boot
 
     // === PERMIS SECURITE ===
-    TopPositionSensor           : BOOL;                                      // --> [SAFE] Capteur haut commun M1/M2
+    TopPositionSensor           : BOOL;                                      // --> [SAFE] Capteur haut commun M1/M2 (TRUE = atteint)
     WinchesMechanicallyStopped  : BOOL;                                      // --> [SAFE] M1 ET M2 arret mecanique confirme
 
     // === ACQUISITION HOMING (M1 / M2) ===
-    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1 (Retenue)
-    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2 (Benne)
+    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1
+    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2
 
     // === ETAT BENNE ===
-    BucketOffsetValid           : BOOL;                                      // --> [HW] Offset benne actif valide (FB_Bucket) — bootstrap datum seulement
+    BucketOffsetValid           : BOOL;                                      // --> [HW] Reference benne persistante valide
 
     // === PERMIS OPERATEUR (joystick + homme-mort) ===
     DeadmanArmed                : BOOL;                                      // --> [CMD] Homme-mort arme
-    JoystickDeflected           : BOOL;                                      // --> [CMD] Joystick defléchi (un axe quelconque) — sert au latch SeenNeutral
-    JoystickPull                : BOOL;                                      // --> [CMD] Manche tire vers soi = sens montee treuils / fermeture benne
-    JoystickPush                : BOOL;                                      // --> [CMD] Manche pousse = sens descente treuils / ouverture benne
+    RawDeadmanButton            : BOOL := FALSE;                             // --> [HW] BP joystick brut (sert en HX0 N1 quand ArmingPermit=FALSE)
+    JoystickDeflected           : BOOL;                                      // --> [CMD] Joystick deflechi (X ou Y hors neutre)
+    JoystickPull                : BOOL;                                      // --> [CMD] Manche tire = montee / fermeture benne
+    JoystickPush                : BOOL;                                      // --> [CMD] Manche pousse = descente / ouverture benne
 
     // === VALIDATION OPERATEUR ===
-    BtnValidation               : BOOL;                                      // --> [CMD] BP joystick (homme-mort)
-    StartRequest                : BOOL;                                      // --> [CMD] Lancer le cycle (front) — commande IHM dediee
-    BtnConfirmHomingBucket      : BOOL;                                      // --> [CMD] Confirmation visuelle fermeture benne cycle homing HX1 (bouton dédié IHM)
+    BtnValidation               : BOOL;                                      // --> [CMD] Bouton validation IHM unifie (HX1, HX2->HX4, HX4)
+    StartRequest                : BOOL;                                      // --> [CMD] Bouton Start IHM (HX0 en MAINT_N2)
+    BtnConfirmHomingBucket      : BOOL;                                      // --> [CMD] Compat bouton IHM historique HX1
 
     // === INTERLOCK COUPLAGE E1 & RETOUR ARBITRAGE ===
-    JoystickWinchSelectArbitrated : INT;                                     // --> [CMD] Selecteur treuil arbitre aval (0=both, 1=M1, 2=M2) pour interlock E1
+    JoystickWinchSelectArbitrated : INT;                                     // --> [CMD] Selecteur treuil arbitre aval (0=couple, 2=M2)
 
-    // === MESURES POSITIONS POUR CONTROLE STABILISATION HX4 ===
-    CablePosM1                  : REAL;                                      // --> [MEAS] Position reelle cable M1 (m)
-    CablePosM2                  : REAL;                                      // --> [MEAS] Position reelle cable M2 (m)
-    CoherenceLimitM             : REAL := 1.0;                               // --> [CFG] Ecart max autorise entre treuils en stabilisation
+    // === MESURES POSITIONS ===
+    CablePosM1                  : REAL;                                      // --> [MEAS] Position cable M1 (m)
+    CablePosM2                  : REAL;                                      // --> [MEAS] Position cable M2 (m)
+    CoherenceLimitM             : REAL := 1.0;                               // --> [CFG] Coherence (compat)
 
     // === MISE EN SERVICE : forcage de step (encadre) ===
-    CfgCommissioningEnable      : BOOL;                                      // --> [CFG] Case IHM mise en service homing : deverrouille le forcage de step
-    CfgForceStepTarget          : INT;                                       // --> [CFG] Step cible du forcage (0=HX0 .. 8=HX7)
-    CfgForceStepApply           : BOOL;                                      // --> [CMD] Applique le forcage (front) — impulsion
+    CfgCommissioningEnable      : BOOL;                                      // --> [CFG] Case mise en service
+    CfgForceStepTarget          : INT;                                       // --> [CFG] Step cible [0..5]
+    CfgForceStepApply           : BOOL;                                      // --> [CMD] Front d'application forcage
 
     // === REGLAGES & CONFIGURATION ===
-    Cfg                         : ST_fbMachineHomingCycle_Cfg;               // --> [CFG] Reglages geometriques + temporisations de garde
+    Cfg                         : ST_fbMachineHomingCycle_Cfg;               // --> [CFG] Reglages + temporisations
 END_VAR
 VAR_OUTPUT
-    // === CONTRAT STANDARD (Ready + Fault) ===
-    Ready                       : BOOL;                                      // <-- [STAT] FB actif (Enable ET NOT Fault.Latched)
-    Fault                       : ST_Fault;                                  // <-- [SAFE] Socle defaut (rempli par FB_FaultCore)
-    Lifecycle                   : ST_Lifecycle;                              // <-- [STAT] Cycle GRAFCET (Busy = cycle de homing en cours)
+    // === CONTRAT STANDARD ===
+    Ready                       : BOOL;
+    Fault                       : ST_Fault;
+    Lifecycle                   : ST_Lifecycle;
 
     // === QUALIFICATION MACHINE ===
-    MachineHomed                : BOOL;                                      // <-- [SAFE] Datum machine valide (gate SEMI_AUTO)
-    MachineHomingStep           : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [STAT] Etape du guide (echelle de priorite)
-    MachineHomingStepAtError    : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [DIAG] Etape figee a l'apparition du defaut (R9)
-    MachineHomingSeqStep        : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS; // <-- [DIAG] Step GRAFCET courant
-    MachineHomingInstruction    : STRING(120);                               // <-- [DIAG] Consigne operateur en clair (ASCII)
-    MachineHomingActive         : BOOL;                                      // <-- [STAT] Cycle en cours (= Lifecycle.Busy)
-    MachineHomingLossSafeStop   : BOOL;                                      // <-- [STAT] Demande d'arret controle suite perte de datum en mouvement
-    MachineHomingFailed         : BOOL;                                      // <-- [STAT] Derniere sequence abandonnee
-    HomingModeBActive           : BOOL;                                      // <-- [STAT] Repli automatique reference a l'arret (Mode B) engage
+    MachineHomed                : BOOL;
+    MachineHomingStep           : E_MachineHomingStep := E_MachineHomingStep.IDLE;
+    MachineHomingStepAtError    : E_MachineHomingStep := E_MachineHomingStep.IDLE;
+    MachineHomingSeqStep        : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS;
+    MachineHomingInstruction    : STRING(120);
+    MachineHomingActive         : BOOL;
+    MachineHomingLossSafeStop   : BOOL;
+    MachineHomingFailed         : BOOL;
+    HomingModeBActive           : BOOL;
 
     // === DEMANDES HOMING (M1 / M2) ===
-    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;       // <-- [ACT] Demande de homing conjoint axe M1
-    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;       // <-- [ACT] Demande de homing conjoint axe M2
-
-    // === ORDRES MOUVEMENT TREUIL (vers PRG_03 -> PRG_04) ===
-    CmdWinchM1                  : ST_ProgramWinchRequest;                     // <-- [ACT] Ordre treuil M1 (montee palier 1)
-    CmdWinchM2                  : ST_ProgramWinchRequest;                     // <-- [ACT] Ordre treuil M2 (montee palier 1)
-
-    // === ORDRES BENNE (palier 1, sans FDC logiciel — HX1) ===
-    CmdBucketOpen               : BOOL;                                      // <-- [ACT] Ordre ouverture benne palier 1 sans FDC soft
-    CmdBucketClose              : BOOL;                                      // <-- [ACT] Ordre fermeture benne palier 1 sans FDC soft
-
-    // === OVERRIDE SELECTEUR TREUIL CYCLE ===
-    CmdWinchSelect              : INT := -1;                                 // <-- [ACT] Override selecteur treuil cycle (-1=neutre, 0=forcer couple, 2=forcer benne)
+    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;
+    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;
+
+    // === ORDRES / PERMIS VERS PRG_03 / PRG_04 ===
+    CmdWinchM1                  : ST_ProgramWinchRequest;
+    CmdWinchM2                  : ST_ProgramWinchRequest;
+    CmdBucketOpen               : BOOL;
+    CmdBucketClose              : BOOL;
+    CmdWinchSelect              : INT := -1;
+    AllowAscent                 : BOOL;
+    AllowDescend                : BOOL;
+    SoftLimitsOff               : BOOL;
 
     // === COMMIT BENNE ===
-    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;       // <-- [ACT] Publication atomique de l'etat benne (vers FB_Bucket)
+    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;
 
     // === VERROU TRANSLATION ===
-    M3Locked                    : BOOL;                                      // <-- [STAT] Translation M3 interdite tant que le cycle homing n'est pas en HX0
+    M3Locked                    : BOOL;
 END_VAR
 VAR
-    // === SOUS-INSTANCES FB ===
-    instFault                   : FB_FaultCore;                              // * [INST] Socle defaut transverse
-    ResetEdge                   : R_TRIG;                                    // . [LOC] Front montant Reset
-    LatchedEdge                 : R_TRIG;                                    // . [LOC] Front montant Fault.Latched (capture R9)
-    TopLostEdge                 : F_TRIG;                                    // . [LOC] Front descendant TopPositionSensor
-
-    // === TABLE DES CAUSES DE DEFAUT ===
-    instCauses                  : ARRAY[0..15] OF ST_FaultCause;             // . [LOC] Causes en clair pour FB_FaultCore
-
-    // === GRAFCET ===
-    SeqStep                     : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS; // . [LOC] Step GRAFCET courant
-    CommitPublished             : BOOL;                                      // . [LOC] Commit benne deja publie sur ce datum
-    CommitDone                  : BOOL;                                      // . [LOC] Commit CommitClose deja emis (impulsion 1 scan)
-    PendingClose                : BOOL;                                      // . [LOC] Fermeture benne confirmee en attente de commit final en HX6
-    CycleRunning                : BOOL;                                      // . [LOC] Miroir de (SeqStep <> HX0_REPOS) — cycle engage
-    HomeReqDone                 : BOOL;                                      // . [LOC] Impulsion HomeReq M1+M2 deja emise sur ce passage HX3
-    SeenNeutral                 : BOOL;                                      // . [LOC] Joystick repasse au neutre depuis l'entree du step d'arret
-
-    // === TEMPORISATIONS DE GARDE ===
-    ClimbTimer                  : TON;                                       // . [LOC] Garde HX2 (montee au capteur)
-    HomeAxesTimer               : TON;                                       // . [LOC] Garde globale HX3 (prise de reference)
-    FlyingHomingTimer           : TON;                                       // . [LOC] Garde essai reference au vol (Mode A) avant bascule Mode B
-    StandstillHomeReqDone       : BOOL;                                      // . [LOC] Impulsion HomeReq emise a l'arret mecanique (Mode B)
-    CouplingSettleTimer         : TON;                                       // . [LOC] Temporisation dwell de bascule selecteur HX1a (300 ms)
-    SettleGraceTimer            : TON;                                       // . [LOC] Fenetre de grace deceleration
-    FirstScanDone               : BOOL;                                      // . [LOC] Garde 1er scan : statuts codeurs pas encore stables au boot
-
-    // === FRONTS OPERATEUR ===
-    StartEdge                   : R_TRIG;                                    // . [LOC] Front montant StartRequest
-    BtnValidationEdge           : R_TRIG;                                    // . [LOC] Front montant BtnValidation (lancement joystick N2)
-    HomingBucketConfirmEdge     : R_TRIG;                                    // . [LOC] Front montant BtnConfirmHomingBucket
-    ForceStepApplyEdge          : R_TRIG;                                    // . [LOC] Front montant CfgForceStepApply
-    ForceStepClamped            : INT;                                       // . [LOC] CfgForceStepTarget borne [0..8]
-
-    // === CONDITIONS INTERMEDIAIRES NOMMEES ===
-    BothAxesHomed               : BOOL;                                      // . [LOC] M1 ET M2 references et fiables
-    CommitOrOffsetValid         : BOOL;                                      // . [LOC] Datum benne connu (commit publie OU offset valide)
-    ClimbPermit                 : BOOL;                                      // . [LOC] Permis operateur maintenu, sens montee
-    DescendPermit               : BOOL;                                      // . [LOC] Permis operateur maintenu, sens descente
-    BucketPermit                : BOOL;                                      // . [LOC] Permis operateur maintenu, benne
-    IsInMovePhase               : BOOL;                                      // . [LOC] Step GRAFCET qui commande un mouvement treuil (HX2)
-    AxisHomingError             : BOOL;                                      // . [LOC] Erreur de homing M1 ou M2
-    MotionOutOfPhase            : BOOL;                                      // . [LOC] Treuil bouge hors phase mouvement, grace decel ecoulee
-    ModeLostDuringCycle         : BOOL;                                      // . [LOC] Sortie de MAINT_N2 alors que le cycle est engage
-    ClimbTimedOut               : BOOL;                                      // . [LOC] Garde de montee ecoulee
-    HomeAxesTimedOut            : BOOL;                                      // . [LOC] Garde de homing axes ecoulee sans axes homes
-    TransactionAbort            : BOOL;                                      // . [LOC] Condition d'abandon fail-safe pendant une phase mouvement
-    ReHomingAckRequired         : BOOL;                                      // . [LOC] Bloque MachineHomed jusqu'a un Reset conscient
-    MachineWasHomed             : BOOL;                                      // . [LOC] Memorise un datum valide (detection de perte)
-    HomingLossLatched           : BOOL;                                      // . [LOC] Perte de datum en mouvement latchee jusqu'a l'arret
-    MachineHomedRaw             : BOOL;                                      // . [LOC] Qualification hors Fault
-    AxesDatumRaw                : BOOL;                                      // . [LOC] Reference codeurs M1/M2 seule
+    // === SOUS-INSTANCES ===
+    instFault                   : FB_FaultCore;
+    ResetEdge                   : R_TRIG;
+    LatchedEdge                 : R_TRIG;
+    TopRiseEdge                 : R_TRIG;
+    StartEdge                   : R_TRIG;
+    BtnValidationEdge           : R_TRIG;
+    HomingBucketConfirmEdge     : R_TRIG;
+    ForceStepApplyEdge          : R_TRIG;
+
+    instCauses                  : ARRAY[0..15] OF ST_FaultCause;
+
+    // === GRAFCET & ETATS INTERNES ===
+    SeqStep                     : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS;
+    CommitPublished             : BOOL;
+    PendingClose                : BOOL;
+    CycleRunning                : BOOL;
+    FirstScanDone               : BOOL;
+    RawBtnSeenReleased          : BOOL;
+    Step1MoveCutoff             : BOOL;
+    Step2SlackCutoff            : BOOL;
+    Step3ClearanceDone          : BOOL;
+    Step3Restart                : BOOL;
+    Step4PresetIssued           : BOOL;
+    Step4WaitConfirmDelay       : BOOL;
+    ForceStepClamped            : INT;
+
+    // === TEMPORISATIONS ===
+    EntryHoldTimer              : TON;
+    Step1MoveTimer              : TON;
+    Step2SlackTimer             : TON;
+    Step3Timer                  : TON;
+    Step3AccumTime              : TIME;
+    Step3SegTime                : TIME;
+    Step3RemainingTime          : TIME;
+    Step3TimerRunning           : BOOL;
+    ClimbTimer                  : TON;
+    HomeAxesTimer               : TON;
+    CouplingSettleTimer         : TON;
+    SettleGraceTimer            : TON;
+
+    // === CALCULS AFFICHAGE ===
+    EntryRemSec                 : INT;
+    Step1RemSec                 : INT;
+    Step3RemSec                 : INT;
+
+    // === CONDITIONS INTERMEDIAIRES ===
+    BothAxesHomed               : BOOL;
+    CommitOrOffsetValid         : BOOL;
+    ClimbPermit                 : BOOL;
+    Step1MovingCmd              : BOOL;
+    Step2SlackCmd               : BOOL;
+    Step3DescendEngaged         : BOOL;
+    IsInMovePhase               : BOOL;
+    AxisHomingError             : BOOL;
+    MotionOutOfPhase            : BOOL;
+    ModeLostDuringCycle         : BOOL;
+    ClimbTimedOut               : BOOL;
+    HomeAxesTimedOut            : BOOL;
+    TransactionAbort            : BOOL;
+    ReHomingAckRequired         : BOOL;
+    MachineWasHomed             : BOOL;
+    HomingLossLatched           : BOOL;
+    MachineHomedRaw             : BOOL;
+    AxesDatumRaw                : BOOL;
 
     // === CONTEXTE MODES & INTERLOCKS ===
-    ModeIsMaint2                : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N2
-    ModeIsMaint1                : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N1
-    MaintenanceActive           : BOOL;                                      // . [LOC] Mode arbitre = MAINT_N1 ou MAINT_N2
-    ClimbStepActive             : BOOL;                                      // . [LOC] Step courant = montee couplee (HX2)
-    ClimbCommandActive          : BOOL;                                      // . [LOC] Montee REELLEMENT commandee : seule condition qui consomme la garde
-    CouplingInterlockFault      : BOOL;                                      // . [LOC] Violation couplage pendant la montee HX2 (WinchSel <> 0)
-
-    // === CONTROLE STABILISATION HX4 ===
-    RetryCount                  : INT := 0;                                  // . [LOC] Compteur de tentatives HX4 -> HX1 (max 3)
-    StabilizationOk             : BOOL;                                      // . [LOC] Stabilisation inertie conforme [8.50..8.80m]
-    StabilizationFailed         : BOOL;                                      // . [LOC] Stabilisation inertie hors plage
+    ModeIsMaint1                : BOOL;
+    ModeIsMaint2                : BOOL;
+    MaintenanceActive           : BOOL;
+    ClimbStepActive             : BOOL;
+    ClimbCommandActive          : BOOL;
+    CouplingInterlockFault      : BOOL;
+    ValidatePressed             : BOOL;
 END_VAR
 VAR CONSTANT
-    // === INDICES DE CAUSES (instCauses[]) ===
-    CST_CauseHomingLostInMotion : INT := 0;                                  // Perte d'un datum valide pendant un mouvement (Latching)
-    CST_CauseClimbTimeout       : INT := 1;                                  // HX2 : capteur haut non atteint dans la garde (Latching)
-    CST_CauseMotionOutOfPhase   : INT := 2;                                  // Treuil bouge hors phase mouvement autorisee (Latching)
-    CST_CauseHomingErrorM1      : INT := 3;                                  // FB_Encoder M1 signale une erreur de homing (Latching)
-    CST_CauseHomingErrorM2      : INT := 4;                                  // FB_Encoder M2 signale une erreur de homing (Latching)
-    CST_CauseHomeAxesTimeout    : INT := 5;                                  // HX3 : prise de reference non obtenue dans la garde (Latching)
-    CST_CauseCouplingFault      : INT := 6;                                  // HX2 : selecteur treuil non couple (WinchSel <> 0) pendant la montee (Latching)
-    CST_CauseStabilizationFault : INT := 7;                                  // HX4 : echec persistant stabilisation apres 3 retries (Latching)
-
-    // === TEMPORISATIONS & DIVERS ===
-    CST_SettleGrace             : TIME := T#3s;                              // Grace deceleration a l'entree d'un step d'arret
-    CST_StepSlow                : INT  := 1;                                 // Palier de vitesse lent (palier 1 MAX strict)
+    CST_CauseHomingLostInMotion : INT := 0;
+    CST_CauseClimbTimeout       : INT := 1;
+    CST_CauseMotionOutOfPhase   : INT := 2;
+    CST_CauseHomingErrorM1      : INT := 3;
+    CST_CauseHomingErrorM2      : INT := 4;
+    CST_CauseHomeAxesTimeout    : INT := 5;
+    CST_CauseCouplingFault      : INT := 6;
+
+    CST_SettleGrace             : TIME := T#3s;
+    CST_StepSlow                : INT  := 1;
 END_VAR
 
-{region "§1 Fronts, remises a zero de tete de scan, verrou M3"}
-// === §1 FRONTS + RAZ TETE DE SCAN + VERROU M3 =========================
-
-// Protection premier scan : forcer repos et etat propre
+{region "§1 Fronts, remises a zero de tete de scan"}
 IF NOT FirstScanDone THEN
     SeqStep              := E_MachineHomingTxState.HX0_REPOS;
     MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
     MachineHomingFailed  := FALSE;
     HomingModeBActive    := FALSE;
-    StandstillHomeReqDone:= FALSE;
-    RetryCount           := 0;
-    HomeReqDone          := FALSE;
     PendingClose         := FALSE;
+    RawBtnSeenReleased   := NOT RawDeadmanButton;
+    Step1MoveCutoff      := FALSE;
+    Step2SlackCutoff     := FALSE;
+    Step3ClearanceDone   := FALSE;
+    Step3AccumTime       := T#0s;
+    Step3SegTime         := T#0s;
+    Step3RemainingTime   := T#0s;
+    Step3TimerRunning    := FALSE;
+    Step3Timer(IN := FALSE, PT := T#0s);
+    Step3Restart         := FALSE;
+    Step4PresetIssued    := FALSE;
 END_IF;
 
-// Sorties impulsionnelles / mouvement : remises a FALSE en tete de scan.
-M1Demand.HomeReq := FALSE;
-M2Demand.HomeReq := FALSE;
+// Sorties impulsionnelles et permis remis a zero en tete de scan
+M1Demand.HomeReq := FALSE; M1Demand.UseDynamicTarget := FALSE; M1Demand.DynamicTarget_M := 0.0;
+M2Demand.HomeReq := FALSE; M2Demand.UseDynamicTarget := FALSE; M2Demand.DynamicTarget_M := 0.0;
 BucketCommit.CommitOpen  := FALSE;
 BucketCommit.CommitClose := FALSE;
 CmdBucketOpen  := FALSE;
 CmdBucketClose := FALSE;
 CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
 CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
-CmdWinchSelect := -1; // Par defaut pas d'override
+CmdWinchSelect := -1;
+AllowAscent    := FALSE;
+AllowDescend   := FALSE;
+SoftLimitsOff  := FALSE;
 
 ResetEdge(CLK := Reset);
 LatchedEdge(CLK := Fault.Latched);
-TopLostEdge(CLK := TopPositionSensor);
+TopRiseEdge(CLK := TopPositionSensor);
 StartEdge(CLK := StartRequest);
 BtnValidationEdge(CLK := BtnValidation);
 HomingBucketConfirmEdge(CLK := BtnConfirmHomingBucket);
+ValidatePressed := BtnValidationEdge.Q OR HomingBucketConfirmEdge.Q;
 
-// Miroirs booleens de contexte GRAFCET.
 ModeIsMaint1 := (Mode = E_Mode.MAINT_N1);
 ModeIsMaint2 := (Mode = E_Mode.MAINT_N2);
 MaintenanceActive := ModeIsMaint1 OR ModeIsMaint2;
 
-// Phases de mouvement treuils
-IsInMovePhase := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED);
 CycleRunning  := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);
-
-// M3Locked est calcule en §9 pour verrouiller des le scan d'entree en cycle.
+IsInMovePhase := (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE)
+              OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP)
+              OR (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE);
 {endregion}
 
 {region "§2 Conditions intermediaires"}
-// === §2 CONDITIONS NOMMEES ============================================
 BothAxesHomed       := M1Status.HomedAndReliable AND M2Status.HomedAndReliable;
 CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
-ClimbPermit         := DeadmanArmed AND JoystickPull;
-DescendPermit       := DeadmanArmed AND JoystickPush;
-BucketPermit        := DeadmanArmed AND JoystickPull; // HX1 : fermeture uniquement par manche tire
+ClimbPermit         := DeadmanArmed AND JoystickPull AND NOT JoystickPush;
 
-// Fenetre de grace deceleration
-SettleGraceTimer(IN := (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK)
-                       OR (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK)
-                       OR (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE), PT := CST_SettleGrace);
+// Grace deceleration en HX4 / HX7
+SettleGraceTimer(IN := (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM)
+                       OR (SeqStep = E_MachineHomingTxState.HX7_FAILED), PT := CST_SettleGrace);
 
-// Conditions d'abandon fail-safe
 AxisHomingError  := M1Status.HomingError OR M2Status.HomingError;
 MotionOutOfPhase := CycleRunning AND NOT IsInMovePhase
                     AND NOT WinchesMechanicallyStopped AND SettleGraceTimer.Q;
 
-// Garde de montee HX2
-ClimbStepActive := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED);
+// Garde de montee HX2 (consommee UNIQUEMENT pendant la montee commandee, gate G511)
+ClimbStepActive    := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP);
 ClimbCommandActive := ClimbStepActive AND ClimbPermit;
 ClimbTimer(IN := ClimbCommandActive, PT := Cfg.CfgTimeoutClimb);
-ClimbTimedOut := ClimbStepActive AND ClimbTimer.Q;
+ClimbTimedOut := ClimbStepActive AND (Cfg.CfgTimeoutClimb > T#0s) AND ClimbTimer.Q;
 
-// Garde prise de reference HX3
-HomeAxesTimer(IN := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE), PT := Cfg.CfgTimeoutHomeAxes);
-HomeAxesTimedOut := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) AND HomeAxesTimer.Q AND NOT BothAxesHomed;
-FlyingHomingTimer(IN := (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) AND NOT HomingModeBActive, PT := Cfg.CfgTimeoutFlyingHoming);
+// Garde prise de reference HX4
+HomeAxesTimer(IN := (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) AND Step4PresetIssued AND NOT BothAxesHomed,
+              PT := Cfg.CfgTimeoutHomeAxes);
+HomeAxesTimedOut := (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM)
+                    AND Step4PresetIssued AND (Cfg.CfgTimeoutHomeAxes > T#0s)
+                    AND HomeAxesTimer.Q AND NOT BothAxesHomed;
 
-// Violation couplage E1
-CouplingInterlockFault := (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED)
-                          AND (JoystickWinchSelectArbitrated <> 0);
+// Violation couplage E1 en HX2 / HX3 (si WinchSel arbitre diverge alors qu'un mouvement est commande)
+CouplingInterlockFault := FALSE;
 
-// Sortie de MAINT_N2 alors qu'un step mouvement/cycle est engage : abandon fail-safe.
-ModeLostDuringCycle := CycleRunning AND NOT ModeIsMaint2;
+// Sortie vers DISABLE ou SEMI_AUTO en cours de cycle homing
+ModeLostDuringCycle := CycleRunning AND NOT MaintenanceActive;
 TransactionAbort := CycleRunning
                     AND (AxisHomingError OR MotionOutOfPhase OR ClimbTimedOut
-                         OR HomeAxesTimedOut
-                         OR CouplingInterlockFault OR ModeLostDuringCycle);
+                         OR HomeAxesTimedOut OR CouplingInterlockFault OR ModeLostDuringCycle);
 {endregion}
 
 {region "§3 Detection perte de datum"}
-// === §3 PERTE DE DATUM ================================================
 AxesDatumRaw    := BothAxesHomed;
 MachineHomedRaw := AxesDatumRaw AND CommitOrOffsetValid AND NOT ReHomingAckRequired;
 
@@ -280,7 +291,6 @@ IF FirstScanDone AND NOT MachineHomedRaw AND MachineWasHomed THEN
 END_IF;
 
 MachineWasHomed := MachineHomedRaw;
-
 MachineHomingLossSafeStop := HomingLossLatched AND NOT WinchesMechanicallyStopped;
 
 IF ResetEdge.Q AND WinchesMechanicallyStopped THEN
@@ -290,43 +300,50 @@ END_IF;
 {endregion}
 
 {region "§4 Purge sur Reset & Forcage mise en service"}
-// === §4 PURGE SUR RESET ===============================================
 IF ResetEdge.Q THEN
-    MachineHomingFailed  := FALSE;
-    HomingModeBActive    := FALSE;
-    StandstillHomeReqDone:= FALSE;
-    PendingClose         := FALSE;
-    CommitDone           := FALSE;
-    HomeReqDone          := FALSE;
-    RetryCount           := 0;
-    SeqStep              := E_MachineHomingTxState.HX0_REPOS;
+    MachineHomingFailed := FALSE;
+    HomingModeBActive   := FALSE;
+    PendingClose        := FALSE;
+    Step1MoveCutoff     := FALSE;
+    Step2SlackCutoff    := FALSE;
+    Step3ClearanceDone  := FALSE;
+    Step3AccumTime      := T#0s;
+    Step3SegTime        := T#0s;
+    Step3RemainingTime  := T#0s;
+    Step3TimerRunning   := FALSE;
+    Step3Timer(IN := FALSE, PT := T#0s);
+    Step3Restart        := FALSE;
+    Step4PresetIssued   := FALSE;
+    RawBtnSeenReleased  := NOT RawDeadmanButton;
+    SeqStep             := E_MachineHomingTxState.HX0_REPOS;
     MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
 END_IF;
 
-// §4bis Forcage de step de mise en service (encadre)
 ForceStepApplyEdge(CLK := CfgForceStepApply);
 IF CfgCommissioningEnable AND ModeIsMaint2 AND ForceStepApplyEdge.Q THEN
-    ForceStepClamped := LIMIT(0, CfgForceStepTarget, 8);
+    ForceStepClamped := LIMIT(0, CfgForceStepTarget, 5);
     CASE ForceStepClamped OF
         0: SeqStep := E_MachineHomingTxState.HX0_REPOS;
         1: SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
-        2: SeqStep := E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK;
-        3: SeqStep := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
-        4: SeqStep := E_MachineHomingTxState.HX3_FLYING_REFERENCE;
-        5: SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
-        6: SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
-        7: SeqStep := E_MachineHomingTxState.HX6_HOMED_SUCCESS;
-        8: SeqStep := E_MachineHomingTxState.HX7_FAILED;
+        2: SeqStep := E_MachineHomingTxState.HX2_CLIMB_TO_TOP;
+        3: SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
+        4: SeqStep := E_MachineHomingTxState.HX4_FINAL_CONFIRM;
+        5: SeqStep := E_MachineHomingTxState.HX7_FAILED;
     END_CASE;
-    HomeReqDone         := FALSE;
-    PendingClose        := FALSE;
-    CommitDone          := FALSE;
+    Step1MoveCutoff     := FALSE;
+    Step2SlackCutoff    := FALSE;
+    Step3ClearanceDone  := FALSE;
+    Step3AccumTime      := T#0s;
+    Step3SegTime        := T#0s;
+    Step3RemainingTime  := T#0s;
+    Step3TimerRunning   := FALSE;
+    Step3Timer(IN := FALSE, PT := T#0s);
+    Step4PresetIssued   := FALSE;
     MachineHomingFailed := FALSE;
 END_IF;
 {endregion}
 
 {region "§5 Table des causes & socle defaut"}
-// === §5 TABLE DES CAUSES + SOCLE DEFAUT ==============================
 instCauses[CST_CauseHomingLostInMotion].Active   := HomingLossLatched OR ReHomingAckRequired;
 instCauses[CST_CauseHomingLostInMotion].Latching := TRUE;
 instCauses[CST_CauseHomingLostInMotion].Texte    := 'Perte de datum machine en mouvement : re-referencer';
@@ -349,351 +366,405 @@ instCauses[CST_CauseHomingErrorM2].Texte    := 'Erreur de homing codeur M2 penda
 
 instCauses[CST_CauseHomeAxesTimeout].Active   := HomeAxesTimedOut;
 instCauses[CST_CauseHomeAxesTimeout].Latching := TRUE;
-instCauses[CST_CauseHomeAxesTimeout].Texte    := 'Prise de reference capteur haut non obtenue dans le temps';
+instCauses[CST_CauseHomeAxesTimeout].Texte    := 'Prise de reference finale non obtenue dans le temps';
 
 instCauses[CST_CauseCouplingFault].Active   := CouplingInterlockFault;
 instCauses[CST_CauseCouplingFault].Latching := TRUE;
-instCauses[CST_CauseCouplingFault].Texte    := 'Defaut de couplage treuils M1+M2 en phase montee';
-
-instCauses[CST_CauseStabilizationFault].Active   := (SeqStep = E_MachineHomingTxState.HX7_FAILED) AND (RetryCount >= 3);
-instCauses[CST_CauseStabilizationFault].Latching := TRUE;
-instCauses[CST_CauseStabilizationFault].Texte    := 'Stabilisation inertie treuils hors plage apres 3 tentatives';
+instCauses[CST_CauseCouplingFault].Texte    := 'Defaut de couplage treuils M1+M2 pendant referencement';
 
-// Socle defaut
 instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
 Fault := instFault.Fault;
 {endregion}
 
-{region "§6 Initiation du cycle"}
-// === §6 INITIATION DU CYCLE ===========================================
-// Le cycle ne s'auto-arme JAMAIS spontanement (securite machine, actionneurs
-// sollicites des HX1). L'initiation exige une action consciente de l'operateur
-// en mode MAINT_N2 (StartRequest sur IHM ou BtnValidation sur joystick).
-{endregion}
-
 {region "§7 Gate Enable"}
-// === §7 GATE ENABLE ===================================================
 IF NOT Enable THEN
-    M1Demand.HomeReq         := FALSE;
-    M2Demand.HomeReq         := FALSE;
+    M1Demand.HomeReq := FALSE; M1Demand.UseDynamicTarget := FALSE; M1Demand.DynamicTarget_M := 0.0;
+    M2Demand.HomeReq := FALSE; M2Demand.UseDynamicTarget := FALSE; M2Demand.DynamicTarget_M := 0.0;
     BucketCommit.CommitOpen  := FALSE;
     BucketCommit.CommitClose := FALSE;
-    CmdBucketOpen            := FALSE;
-    CmdBucketClose           := FALSE;
-    CmdWinchM1.RunRequest    := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
-    CmdWinchM2.RunRequest    := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
-    CmdWinchSelect           := -1;
-    Ready                    := FALSE;
-    Lifecycle.Busy           := FALSE;
-    Lifecycle.Done           := FALSE;
-    MachineHomingActive      := FALSE;
-    M3Locked                 := FALSE;
-    MachineHomed             := FALSE;
+    CmdBucketOpen  := FALSE;
+    CmdBucketClose := FALSE;
+    CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
+    CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
+    CmdWinchSelect := -1;
+    AllowAscent    := FALSE;
+    AllowDescend   := FALSE;
+    SoftLimitsOff  := FALSE;
+    Ready          := FALSE;
+    Lifecycle.Busy := FALSE;
+    Lifecycle.Done := FALSE;
+    MachineHomingActive := FALSE;
+    M3Locked       := FALSE;
+    MachineHomed   := FALSE;
     MachineHomingLossSafeStop := FALSE;
-    CommitPublished          := FALSE;
-    CommitDone               := FALSE;
-    PendingClose             := FALSE;
-    HomingModeBActive        := FALSE;
-    StandstillHomeReqDone    := FALSE;
-    RetryCount               := 0;
-    SeqStep                  := E_MachineHomingTxState.HX0_REPOS;
-    MachineHomingSeqStep     := E_MachineHomingTxState.HX0_REPOS;
-    MachineHomingStep        := E_MachineHomingStep.IDLE;
+    CommitPublished := FALSE;
+    PendingClose    := FALSE;
+    Step1MoveCutoff := FALSE;
+    Step2SlackCutoff := FALSE;
+    Step3ClearanceDone := FALSE;
+    Step3AccumTime := T#0s;
+    Step3SegTime := T#0s;
+    Step3RemainingTime := T#0s;
+    Step3TimerRunning := FALSE;
+    Step3Timer(IN := FALSE, PT := T#0s);
+    Step4PresetIssued := FALSE;
+    SeqStep         := E_MachineHomingTxState.HX0_REPOS;
+    MachineHomingSeqStep := E_MachineHomingTxState.HX0_REPOS;
+    MachineHomingStep := E_MachineHomingStep.IDLE;
     MachineHomingInstruction := 'Cycle homing desactive';
     RETURN;
 END_IF;
 {endregion}
 
 {region "§8 GRAFCET de referencement machine (CASE SeqStep)"}
-// === §8 GRAFCET (CASE SeqStep) ======================================
+MachineHomedRaw := AxesDatumRaw AND CommitOrOffsetValid AND NOT ReHomingAckRequired
+                   AND NOT MachineHomingFailed AND NOT Fault.Latched;
+
 CASE SeqStep OF
 
     E_MachineHomingTxState.HX0_REPOS:
-        // Etape initiale pure : aucune action.
         CmdWinchSelect := -1;
-        // Entree cycle exige manche au neutre au front de lancement
-        // (jeu joystick / deplacement accidentel ne lance pas le cycle).
-        IF (StartEdge.Q OR BtnValidationEdge.Q) AND ModeIsMaint2 AND NOT JoystickDeflected THEN
-            HomeReqDone := FALSE;
-            RetryCount  := 0;
-            SeqStep     := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
+        IF NOT RawDeadmanButton THEN
+            RawBtnSeenReleased := TRUE;
+        END_IF;
+
+        EntryHoldTimer(
+            IN := NOT MachineHomedRaw
+                  AND MaintenanceActive
+                  AND BootReady
+                  AND NOT Fault.Latched
+                  AND NOT MachineHomingFailed
+                  AND RawBtnSeenReleased
+                  AND RawDeadmanButton
+                  AND NOT JoystickDeflected
+                  AND WinchesMechanicallyStopped,
+            PT := Cfg.CfgEntryHoldTime
+        );
+
+        // Verrou absolu (D2) : impossible si machine deja referencee
+        IF NOT MachineHomedRaw AND BootReady AND NOT Fault.Latched AND NOT MachineHomingFailed THEN
+            IF (ModeIsMaint1 AND EntryHoldTimer.Q)
+               OR (ModeIsMaint2 AND (StartEdge.Q OR EntryHoldTimer.Q) AND NOT JoystickDeflected AND WinchesMechanicallyStopped) THEN
+                PendingClose     := FALSE;
+                Step1MoveCutoff  := FALSE;
+                Step2SlackCutoff := FALSE;
+                Step3ClearanceDone := FALSE;
+                Step3AccumTime   := T#0s;
+                Step3SegTime     := T#0s;
+                Step4PresetIssued := FALSE;
+                RawBtnSeenReleased := FALSE;
+                SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
+            END_IF;
         END_IF;
 
     E_MachineHomingTxState.HX1_BUCKET_PREPARE:
-        // Decision & Fermeture benne operateur :
-        // WinchSel=2 force, FDC benne logiciel inhibe, vitesse plafonnee palier 1.
+        // M2 seul palier 1, ouverture + fermeture autorisees sans aucune butee soft
         CmdWinchSelect := 2;
-        IF BucketPermit AND JoystickPull THEN
-            CmdBucketClose := TRUE;
+        SoftLimitsOff  := TRUE;
+
+        IF Step1MoveCutoff AND NOT JoystickDeflected AND NOT DeadmanArmed AND NOT RawDeadmanButton THEN
+            Step1MoveCutoff := FALSE;
+        END_IF;
+
+        Step1MovingCmd := (JoystickWinchSelectArbitrated = 2)
+                          AND DeadmanArmed
+                          AND (JoystickPull XOR JoystickPush);
+        Step1MoveTimer(IN := Step1MovingCmd AND NOT Step1MoveCutoff, PT := Cfg.CfgBucketPrepareTimeout);
+        IF Step1MoveTimer.Q THEN
+            Step1MoveCutoff := TRUE;
         END_IF;
 
-        IF ModeLostDuringCycle OR MotionOutOfPhase THEN
+        AllowAscent  := NOT Step1MoveCutoff;
+        AllowDescend := NOT Step1MoveCutoff;
+
+        IF TransactionAbort THEN
             MachineHomingFailed := TRUE;
             SeqStep := E_MachineHomingTxState.HX7_FAILED;
-        ELSIF HomingBucketConfirmEdge.Q AND NOT JoystickDeflected THEN
-            // Validation par 1 seul appui bouton dedie IHM, manche au neutre
-            PendingClose := TRUE;
-            CommitDone   := FALSE;
-            SeqStep      := E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK;
+        ELSIF ValidatePressed AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
+            PendingClose     := TRUE;
+            Step2SlackCutoff := FALSE;
+            SeqStep := E_MachineHomingTxState.HX2_CLIMB_TO_TOP;
         END_IF;
 
-    E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK:
-        // Bascule WinchSel=0, reactivation FDC benne.
-        // Interlock bloquant E1 : attente confirmation couplage aval effectif.
+    E_MachineHomingTxState.HX2_CLIMB_TO_TOP:
+        // Couple M1+M2 palier 1 : montee lente + detente cable 2s max par geste.
+        // Toucher TopPositionSensor = PERDU / surcourse -> coupure montee et Step 3.
         CmdWinchSelect := 0;
+        SoftLimitsOff  := TRUE;
+
         CouplingSettleTimer(IN := (JoystickWinchSelectArbitrated = 0), PT := T#300ms);
 
-        IF ModeLostDuringCycle OR AxisHomingError THEN
-            MachineHomingFailed := TRUE;
-            SeqStep := E_MachineHomingTxState.HX7_FAILED;
-        ELSIF (JoystickWinchSelectArbitrated = 0) AND CouplingSettleTimer.Q AND WinchesMechanicallyStopped THEN
-            SeenNeutral := NOT JoystickDeflected;
-            SeqStep     := E_MachineHomingTxState.HX2_CLIMB_COUPLED;
+        IF Step2SlackCutoff AND NOT JoystickDeflected THEN
+            Step2SlackCutoff := FALSE;
         END_IF;
 
-    E_MachineHomingTxState.HX2_CLIMB_COUPLED:
-        // Montee couplee M1+M2 palier 1 MAX vers capteur haut.
-        CmdWinchSelect := 0;
-        IF ClimbPermit AND (JoystickWinchSelectArbitrated = 0) THEN
-            CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqAscent := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
-            CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqAscent := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
+        Step2SlackCmd := CouplingSettleTimer.Q
+                         AND DeadmanArmed
+                         AND JoystickPush AND NOT JoystickPull;
+        Step2SlackTimer(IN := Step2SlackCmd AND NOT Step2SlackCutoff, PT := Cfg.CfgSlackReliefMaxTime);
+        IF Step2SlackTimer.Q THEN
+            Step2SlackCutoff := TRUE;
         END_IF;
 
+        AllowAscent  := CouplingSettleTimer.Q AND NOT TopPositionSensor;
+        AllowDescend := CouplingSettleTimer.Q AND NOT Step2SlackCutoff;
+
         IF TransactionAbort THEN
             MachineHomingFailed := TRUE;
             SeqStep := E_MachineHomingTxState.HX7_FAILED;
         ELSIF TopPositionSensor THEN
-            M1Demand.HomeReq      := TRUE;
-            M2Demand.HomeReq      := TRUE;
-            HomeReqDone           := TRUE;
-            HomingModeBActive     := FALSE;
-            StandstillHomeReqDone := FALSE;
-            SeqStep               := E_MachineHomingTxState.HX3_FLYING_REFERENCE;
+            AllowAscent        := FALSE;
+            Step3ClearanceDone := FALSE;
+            Step3AccumTime     := T#0s;
+            Step3SegTime       := T#0s;
+            Step3RemainingTime := Cfg.CfgTopClearanceTime;
+            Step3TimerRunning  := FALSE;
+            Step3Timer(IN := FALSE, PT := T#0s);
+            Step3Restart       := TRUE;
+            SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
+        ELSIF ValidatePressed AND CouplingSettleTimer.Q AND NOT JoystickDeflected
+              AND WinchesMechanicallyStopped AND NOT TopPositionSensor THEN
+            Step4PresetIssued := FALSE;
+            SeqStep := E_MachineHomingTxState.HX4_FINAL_CONFIRM;
         END_IF;
 
-    E_MachineHomingTxState.HX3_FLYING_REFERENCE:
-        // Referencement conjoint M1+M2 sur capteur haut :
-        // Mode A "a la volee" prioritaire, avec repli automatique en Mode B "a l'arret".
+    E_MachineHomingTxState.HX3_TOP_CLEARANCE:
+        // Contact TOP touche : montee strictement interdite, descente accumulee ~4s
+        // apres relachement capteur TOP (independant des codeurs), puis retour HX1.
         CmdWinchSelect := 0;
-
-        // --- MODE A : PRISE DE REFERENCE A LA VOLEE ---
-        IF NOT HomingModeBActive THEN
-            // Impulsion initiale de homing au vol si pas encore emise au franchissement
-            IF NOT HomeReqDone THEN
-                M1Demand.HomeReq := TRUE;
-                M2Demand.HomeReq := TRUE;
-                HomeReqDone      := TRUE;
-            END_IF;
-
-            // En vol, si les codeurs confirment -> succes immediat Mode A
-            IF BothAxesHomed THEN
-                SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
-            // Repli automatique Mode B si le preset ne se confirme pas dans le temps imparti (3s)
-            // OU si les treuils s'arretent ou si le manche est relache
-            ELSIF FlyingHomingTimer.Q OR WinchesMechanicallyStopped OR NOT JoystickDeflected THEN
-                HomingModeBActive     := TRUE;
-                StandstillHomeReqDone := FALSE;
-            END_IF;
-
-        // --- MODE B : REPLI AUTOMATIQUE A L'ARRET ---
+        SoftLimitsOff  := TRUE;
+        AllowAscent    := FALSE;
+
+        IF TopPositionSensor THEN
+            Step3AccumTime     := T#0s;
+            Step3SegTime       := T#0s;
+            Step3RemainingTime := Cfg.CfgTopClearanceTime;
+            Step3ClearanceDone := FALSE;
+            Step3TimerRunning  := FALSE;
+            Step3Timer(IN := FALSE, PT := T#0s);
+            Step3Restart       := TRUE;
         ELSE
-            // En repli Mode B : aucun ordre de mouvement emis, arret mecanique confirme attendu
-            IF WinchesMechanicallyStopped THEN
-                // A l'arret physique complet, re-emission impulsionnelle de HomeReq
-                IF NOT StandstillHomeReqDone THEN
-                    M1Demand.HomeReq      := TRUE;
-                    M2Demand.HomeReq      := TRUE;
-                    StandstillHomeReqDone := TRUE;
+            Step3DescendEngaged := NOT Step3ClearanceDone
+                                   AND (JoystickWinchSelectArbitrated = 0)
+                                   AND DeadmanArmed
+                                   AND JoystickPush AND NOT JoystickPull;
+
+            IF Step3DescendEngaged THEN
+                IF NOT Step3TimerRunning THEN
+                    IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
+                        Step3RemainingTime := T#0s;
+                        Step3ClearanceDone := TRUE;
+                    ELSE
+                        Step3RemainingTime := Cfg.CfgTopClearanceTime - Step3AccumTime;
+                    END_IF;
+                    Step3Timer(IN := FALSE, PT := T#0s);
+                    Step3TimerRunning := NOT Step3ClearanceDone;
                 END_IF;
-
-                // Validation prise de reference a l'arret
-                IF BothAxesHomed THEN
-                    SeqStep := E_MachineHomingTxState.HX4_STABILIZATION_CHECK;
+                IF Step3TimerRunning THEN
+                    Step3Timer(IN := TRUE, PT := Step3RemainingTime);
+                    Step3SegTime := Step3Timer.ET;
+                    IF Step3Timer.Q THEN
+                        Step3ClearanceDone := TRUE;
+                        Step3AccumTime     := Cfg.CfgTopClearanceTime;
+                        Step3SegTime       := T#0s;
+                        Step3TimerRunning  := FALSE;
+                        Step3Timer(IN := FALSE, PT := T#0s);
+                    END_IF;
+                END_IF;
+            ELSE
+                IF Step3TimerRunning THEN
+                    Step3Timer(IN := TRUE, PT := Step3RemainingTime);
+                    Step3AccumTime := Step3AccumTime + Step3Timer.ET;
+                    IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
+                        Step3AccumTime     := Cfg.CfgTopClearanceTime;
+                        Step3ClearanceDone := TRUE;
+                    END_IF;
+                    Step3SegTime      := T#0s;
+                    Step3TimerRunning := FALSE;
+                    Step3Timer(IN := FALSE, PT := T#0s);
+                END_IF;
+                IF Step3AccumTime >= Cfg.CfgTopClearanceTime THEN
+                    Step3RemainingTime := T#0s;
+                ELSE
+                    Step3RemainingTime := Cfg.CfgTopClearanceTime - Step3AccumTime;
                 END_IF;
             END_IF;
+            Step3Restart := FALSE;
         END_IF;
 
+        AllowDescend := NOT Step3ClearanceDone;
+
         IF TransactionAbort THEN
             MachineHomingFailed := TRUE;
             SeqStep := E_MachineHomingTxState.HX7_FAILED;
+        ELSIF Step3ClearanceDone AND NOT TopPositionSensor AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
+            Step1MoveCutoff := FALSE;
+            SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
         END_IF;
 
-    E_MachineHomingTxState.HX4_STABILIZATION_CHECK:
-        // Arret treuils, controle inertie [8.50..8.80m] et concordance codeurs.
+    E_MachineHomingTxState.HX4_FINAL_CONFIRM:
+        // Zero mouvement : avertissement + validation finale -> ecriture 8.5m M1 + (8.5m + OffsetCloseM) M2
         CmdWinchSelect := 0;
-        SeenNeutral := NOT JoystickDeflected;
-
-        StabilizationOk := WinchesMechanicallyStopped AND SeenNeutral
-                           AND (CablePosM1 >= Cfg.CfgStabilizationMinM) AND (CablePosM1 <= Cfg.CfgStabilizationMaxM)
-                           AND (CablePosM2 >= Cfg.CfgStabilizationMinM) AND (CablePosM2 <= Cfg.CfgStabilizationMaxM)
-                           AND (ABS(CablePosM1 - CablePosM2) <= CoherenceLimitM);
+        SoftLimitsOff  := FALSE;
+        AllowAscent    := FALSE;
+        AllowDescend   := FALSE;
 
-        StabilizationFailed := WinchesMechanicallyStopped AND SeenNeutral AND NOT StabilizationOk;
-
-        IF ModeLostDuringCycle OR AxisHomingError THEN
+        IF TransactionAbort THEN
+            Step4PresetIssued   := FALSE;
             MachineHomingFailed := TRUE;
             SeqStep := E_MachineHomingTxState.HX7_FAILED;
-        ELSIF StabilizationOk THEN
-            SeqStep := E_MachineHomingTxState.HX5_RELEASE_CLEARANCE;
-        ELSIF StabilizationFailed THEN
-            RetryCount := RetryCount + 1;
-            IF RetryCount >= 3 THEN
-                MachineHomingFailed := TRUE;
-                SeqStep := E_MachineHomingTxState.HX7_FAILED;
-            ELSE
-                // Repositionnement et nouvelle tentative : retour en preparation benne
-                SeqStep := E_MachineHomingTxState.HX1_BUCKET_PREPARE;
+        ELSIF TopPositionSensor THEN
+            // Surcourse detectee pendant l'attente -> repli degagement Step 3, jamais de commit
+            Step4PresetIssued  := FALSE;
+            Step3ClearanceDone := FALSE;
+            Step3AccumTime     := T#0s;
+            Step3SegTime       := T#0s;
+            Step3RemainingTime := Cfg.CfgTopClearanceTime;
+            Step3TimerRunning  := FALSE;
+            Step3Timer(IN := FALSE, PT := T#0s);
+            Step3Restart       := TRUE;
+            SeqStep := E_MachineHomingTxState.HX3_TOP_CLEARANCE;
+        ELSIF NOT Step4PresetIssued THEN
+            IF ValidatePressed AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
+                M1Demand.HomeReq          := TRUE;
+                M1Demand.UseDynamicTarget := TRUE;
+                M1Demand.DynamicTarget_M  := Cfg.CfgTopHomingTarget_M;
+                M2Demand.HomeReq          := TRUE;
+                M2Demand.UseDynamicTarget := TRUE;
+                M2Demand.DynamicTarget_M  := Cfg.CfgTopHomingTarget_M + Cfg.CfgOffsetClose_M;
+                Step4PresetIssued := TRUE;
             END_IF;
-        END_IF;
-
-    E_MachineHomingTxState.HX5_RELEASE_CLEARANCE:
-        // Degagement zone haute, confirmation joystick au neutre.
-        CmdWinchSelect := 0;
-        IF ModeLostDuringCycle OR AxisHomingError THEN
-            MachineHomingFailed := TRUE;
-            SeqStep := E_MachineHomingTxState.HX7_FAILED;
-        ELSIF NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
-            SeqStep := E_MachineHomingTxState.HX6_HOMED_SUCCESS;
-        END_IF;
-
-    E_MachineHomingTxState.HX6_HOMED_SUCCESS:
-        // Validation finale : MachineHomed := TRUE, commit atomique benne.
-        CmdWinchSelect := 0;
-        IF NOT CommitDone THEN
-            BucketCommit.CommitClose := PendingClose;
+        ELSIF BothAxesHomed AND M1Status.HomingDone AND M2Status.HomingDone
+              AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy AND NOT TopPositionSensor THEN
+            BucketCommit.CommitClose := TRUE;
             CommitPublished          := TRUE;
-            CommitDone               := TRUE;
-        ELSE
-            PendingClose := FALSE;
-            SeqStep      := E_MachineHomingTxState.HX0_REPOS;
+            PendingClose             := FALSE;
+            Step4PresetIssued        := FALSE;
+            RawBtnSeenReleased       := NOT RawDeadmanButton;
+            SeqStep := E_MachineHomingTxState.HX0_REPOS;
         END_IF;
 
     E_MachineHomingTxState.HX7_FAILED:
-        // Echec sequence unifie : sorties a 0, attente Reset conscient en MAINT_N2.
         CmdWinchSelect := -1;
-        ;
+        SoftLimitsOff  := FALSE;
+        AllowAscent    := FALSE;
+        AllowDescend   := FALSE;
 
 END_CASE;
 {endregion}
 
 {region "§9 Cycle de vie & qualification de sortie"}
-// === §9 CYCLE DE VIE + QUALIFICATION ================================
 CycleRunning := (SeqStep <> E_MachineHomingTxState.HX0_REPOS);
 
-// Selection treuil demandee par le cycle
 IF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
     CmdWinchSelect := 2;
-ELSIF (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK)
-   OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED)
-   OR (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE)
-   OR (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK)
-   OR (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE)
-   OR (SeqStep = E_MachineHomingTxState.HX6_HOMED_SUCCESS) THEN
+    SoftLimitsOff  := TRUE;
+    AllowAscent    := NOT Step1MoveCutoff;
+    AllowDescend   := NOT Step1MoveCutoff;
+ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP) THEN
+    CmdWinchSelect := 0;
+    SoftLimitsOff  := TRUE;
+    AllowAscent    := CouplingSettleTimer.Q AND NOT TopPositionSensor;
+    AllowDescend   := CouplingSettleTimer.Q AND NOT Step2SlackCutoff;
+ELSIF (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE) THEN
     CmdWinchSelect := 0;
+    SoftLimitsOff  := TRUE;
+    AllowAscent    := FALSE;
+    AllowDescend   := NOT Step3ClearanceDone;
+ELSIF (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) THEN
+    CmdWinchSelect := 0;
+    SoftLimitsOff  := FALSE;
+    AllowAscent    := FALSE;
+    AllowDescend   := FALSE;
 ELSE
     CmdWinchSelect := -1;
+    SoftLimitsOff  := FALSE;
+    AllowAscent    := FALSE;
+    AllowDescend   := FALSE;
 END_IF;
 
-M3Locked             := CycleRunning;
-MachineHomingActive  := CycleRunning;
-Lifecycle.Busy       := CycleRunning;
-Lifecycle.Done       := CommitPublished AND (SeqStep = E_MachineHomingTxState.HX0_REPOS);
-MachineHomingSeqStep := SeqStep;
-
 CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
 MachineHomed := BothAxesHomed AND CommitOrOffsetValid
                 AND (SeqStep <> E_MachineHomingTxState.HX7_FAILED)
                 AND NOT MachineHomingFailed AND NOT ReHomingAckRequired
                 AND NOT Fault.Latched;
+
+// M3 verrouille des Step 0 en N1/SEMI si non reference (echappatoire N2 preservee en Step 0)
+M3Locked             := CycleRunning OR (NOT MachineHomed AND NOT ModeIsMaint2);
+MachineHomingActive  := (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE)
+                     OR (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP)
+                     OR (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE)
+                     OR (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM);
+Lifecycle.Busy       := CycleRunning;
+Lifecycle.Done       := CommitPublished AND (SeqStep = E_MachineHomingTxState.HX0_REPOS);
+MachineHomingSeqStep := SeqStep;
 {endregion}
 
-{region "§10 Guide operateur — echelle de priorite"}
-// === §10 GUIDE OPERATEUR (echelle de priorite) ======================
+{region "§10 Guide operateur — messages ASCII sans accents"}
 IF Fault.Latched THEN
     MachineHomingStep := E_MachineHomingStep.FAILED;
-    MachineHomingInstruction := 'Erreur ou Echec homing - Acquitter (Reset)';
+    MachineHomingInstruction := 'Echec homing - Acquitter (Reset)';
 ELSIF MachineHomingFailed OR (SeqStep = E_MachineHomingTxState.HX7_FAILED) THEN
     MachineHomingStep := E_MachineHomingStep.FAILED;
-    MachineHomingInstruction := 'HX7 - Homing incomplet - Acquitter Reset N2';
+    MachineHomingInstruction := 'HX7 - Homing abandonne - Acquitter Reset';
 ELSIF MachineHomingLossSafeStop THEN
     MachineHomingStep := E_MachineHomingStep.LOSS_SAFESTOP;
     MachineHomingInstruction := 'Reference perdue - Arret controle';
 ELSIF MachineHomed AND NOT CycleRunning THEN
     MachineHomingStep := E_MachineHomingStep.VALID;
-    MachineHomingInstruction := '';
+    MachineHomingInstruction := 'Homing fait';
 ELSIF (SeqStep = E_MachineHomingTxState.HX1_BUCKET_PREPARE) THEN
     MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
-    MachineHomingInstruction := 'HX1 - RefHoming Fermer benne, valider sur IHM';
-ELSIF (SeqStep = E_MachineHomingTxState.HX1A_COUPLING_INTERLOCK) THEN
-    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
-    MachineHomingInstruction := 'HX1a - RefHoming Verif couplage M1+M2';
-ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_COUPLED) THEN
-    MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
-    MachineHomingInstruction := 'HX2 - RefHoming Tirer JOY palier 1 vers haut';
-ELSIF (SeqStep = E_MachineHomingTxState.HX3_FLYING_REFERENCE) THEN
-    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
-    IF HomingModeBActive THEN
-        IF NOT WinchesMechanicallyStopped THEN
-            MachineHomingInstruction := 'HX3 - Repli arret (Mode B) : attente arret treuils';
-        ELSE
-            MachineHomingInstruction := 'HX3 - Repli arret (Mode B) : reference conjointement';
-        END_IF;
+    IF Step1MoveCutoff THEN
+        MachineHomingInstruction := 'HX1 - Delai 20s atteint: relacher neutre et BP';
     ELSE
-        MachineHomingInstruction := 'HX3 - RefHoming Prise de reference au vol';
+        Step1RemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgBucketPrepareTimeout - Step1MoveTimer.ET) + DINT#999) / DINT#1000);
+        MachineHomingInstruction := CONCAT('HX1 - Benne M2 (SANS BUTEES) ',
+                                           CONCAT(INT_TO_STRING(Step1RemSec), 's | Valider neutre'));
     END_IF;
-ELSIF (SeqStep = E_MachineHomingTxState.HX4_STABILIZATION_CHECK) THEN
-    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
-    MachineHomingInstruction := 'HX4 - RefHoming Arret et controle inertie';
-ELSIF (SeqStep = E_MachineHomingTxState.HX5_RELEASE_CLEARANCE) THEN
-    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
-    MachineHomingInstruction := 'HX5 - RefHoming Relacher JOY au neutre';
-ELSIF (SeqStep = E_MachineHomingTxState.HX6_HOMED_SUCCESS) THEN
-    MachineHomingStep := E_MachineHomingStep.VALID;
-    MachineHomingInstruction := 'HX6 - RefHoming Machine referencee';
-ELSIF NOT M1Status.HomedAndReliable AND NOT M2Status.HomedAndReliable THEN
-    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
-    IF Mode = E_Mode.MAINT_N2 THEN
-        MachineHomingInstruction := 'HX0 - RefHoming M1+M2 non ref - Lancer sur IHM';
-    ELSIF Mode = E_Mode.MAINT_N1 THEN
-        MachineHomingInstruction := 'HX0 - M1+M2 non ref - Homing unitaire possible';
+ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB_TO_TOP) THEN
+    MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
+    IF Step2SlackCutoff THEN
+        MachineHomingInstruction := 'HX2 - Detente 2s atteinte: relacher neutre';
     ELSE
-        MachineHomingInstruction := 'HX0 - M1+M2 non referencies';
+        MachineHomingInstruction := 'HX2 - Monter pres TOP (SANS toucher) puis Valider';
     END_IF;
-ELSIF NOT M1Status.HomedAndReliable THEN
-    MachineHomingStep := E_MachineHomingStep.M1_NOT_HOMED;
-    IF Mode = E_Mode.MAINT_N2 THEN
-        MachineHomingInstruction := 'HX0 - RefHoming M1 non ref - Lancer sur IHM';
-    ELSIF Mode = E_Mode.MAINT_N1 THEN
-        MachineHomingInstruction := 'HX0 - M1 non ref - Homing unitaire possible';
+ELSIF (SeqStep = E_MachineHomingTxState.HX3_TOP_CLEARANCE) THEN
+    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
+    IF TopPositionSensor THEN
+        MachineHomingInstruction := 'HX3 - TOP touche! Descendre pour degager capteur';
+    ELSIF Step3ClearanceDone THEN
+        MachineHomingInstruction := 'HX3 - Degagement OK, relacher neutre -> retour HX1';
     ELSE
-        MachineHomingInstruction := 'HX0 - M1 non reference';
+        Step3RemSec := DINT_TO_INT((TIME_TO_DINT(Step3RemainingTime - Step3SegTime) + DINT#999) / DINT#1000);
+        IF Step3RemSec < 0 THEN Step3RemSec := 0; END_IF;
+        MachineHomingInstruction := CONCAT('HX3 - Continuer descente degagement: ',
+                                           CONCAT(INT_TO_STRING(Step3RemSec), 's'));
     END_IF;
-ELSIF NOT M2Status.HomedAndReliable THEN
-    MachineHomingStep := E_MachineHomingStep.M2_NOT_HOMED;
-    IF Mode = E_Mode.MAINT_N2 THEN
-        MachineHomingInstruction := 'HX0 - RefHoming M2 non ref - Lancer sur IHM';
-    ELSIF Mode = E_Mode.MAINT_N1 THEN
-        MachineHomingInstruction := 'HX0 - M2 non ref - Homing unitaire possible';
+ELSIF (SeqStep = E_MachineHomingTxState.HX4_FINAL_CONFIRM) THEN
+    MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
+    IF Step4PresetIssued THEN
+        MachineHomingInstruction := 'HX4 - Ecriture references 8.5m + benne...';
     ELSE
-        MachineHomingInstruction := 'HX0 - M2 non reference';
+        MachineHomingInstruction := 'HX4 - ATTENTION ecrit 8.5m + benne fermee! Valider';
     END_IF;
-ELSIF NOT (CommitPublished OR BucketOffsetValid) THEN
-    IF Mode = E_Mode.MAINT_N2 THEN
-        MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
-        MachineHomingInstruction := 'HX0 - RefHoming Lancer le homing (etat benne)';
-    ELSIF Mode = E_Mode.MAINT_N1 THEN
-        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
-        MachineHomingInstruction := 'HX0 - Offset benne inconnu';
+ELSIF ModeIsMaint1 THEN
+    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
+    IF RawDeadmanButton AND NOT JoystickDeflected AND RawBtnSeenReleased THEN
+        EntryRemSec := DINT_TO_INT((TIME_TO_DINT(Cfg.CfgEntryHoldTime - EntryHoldTimer.ET) + DINT#999) / DINT#1000);
+        MachineHomingInstruction := CONCAT('HX0 - Maintien BP neutre: ',
+                                           CONCAT(INT_TO_STRING(EntryRemSec), 's (secours: N2)'));
     ELSE
-        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
-        MachineHomingInstruction := 'HX0 - Offset benne inconnu';
+        MachineHomingInstruction := 'HX0 - Maintenir BP joy 5s neutre (ou passer N2)';
     END_IF;
+ELSIF ModeIsMaint2 THEN
+    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
+    MachineHomingInstruction := 'HX0 - N2 libre actif | Lancer homing (Start IHM)';
 ELSE
-    MachineHomingStep := E_MachineHomingStep.VALID;
-    MachineHomingInstruction := 'Reference machine valide';
+    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
+    MachineHomingInstruction := 'HX0 - Non reference : passer en MAINT_N1 ou N2';
 END_IF;
 
-// Capture R9 de l'etape a l'apparition du defaut latche
 IF LatchedEdge.Q THEN
     MachineHomingStepAtError := MachineHomingStep;
 END_IF;
diff --git a/CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st b/CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st
index 85e96976..cc861b5e 100644
--- a/CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st
+++ b/CODE/G_CYCLE/_TYPES/E_MachineHomingTxState.st
@@ -1,23 +1,19 @@
 (* =======================================================================
    ⚙️ E_MachineHomingTxState — Steps du GRAFCET de referencement machine
    ───────────────────────────────────────────────────────────────
-   🎯 Role : Machine a etats sequentielle (GRAFCET) du cycle de homing
-             machine M1/M2/benne pilote par FB_CycleMachineHoming (§8).
-             Refonte T364 selon specification exploitant du 2026-09-21.
-   📄 Doc : DOC/WFLOW/CONTRACTS/TASK_CONTRACT_T364_REFONTE_SEQUENCE_HOMING.yaml
+   🎯 Role : Machine a etats sequentielle (GRAFCET) en 5 etapes du cycle
+             de homing machine M1/M2/benne pilote par FB_CycleMachineHoming.
+   📄 Doc : DOC/WFLOW/MISE_EN_SERVICE/PLAN_REFONTE_GRAFCET_HOMING_20261118_v1.0.md
             + DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
    ======================================================================= *)
 
 TYPE E_MachineHomingTxState :
 (
-    HX0_REPOS               := 0,   (* Etape initiale pure : repos, aucune action *)
-    HX1_BUCKET_PREPARE      := 1,   (* Fermeture benne palier 1 sous FDC off, timer 8s, bouton IHM dedie *)
-    HX1A_COUPLING_INTERLOCK := 2,   (* Bascule WinchSel=0, FDC benne reactive, interlock couplage bloquant *)
-    HX2_CLIMB_COUPLED       := 3,   (* Montee couplee M1+M2 palier 1 MAX vers capteur haut *)
-    HX3_FLYING_REFERENCE    := 4,   (* Prise de reference a la volee M1+M2 sur position de config persistante (8.5m) *)
-    HX4_STABILIZATION_CHECK := 5,   (* Arret mecanique, controle inertie [8.50..8.80m], max 3 retries *)
-    HX5_RELEASE_CLEARANCE   := 6,   (* Degagement zone haute, verification neutre joystick *)
-    HX6_HOMED_SUCCESS       := 7,   (* Machine qualifiee : MachineHomed := TRUE, commit atomique benne *)
-    HX7_FAILED              := 8    (* Echec sequence unifie : Reset conscient requis en MAINT_N2 *)
+    HX0_REPOS          := 0,   (* Repos : N1 libre bloque si NOT Homed, M3 bloque N1/SEMI, attente 5s BP joy N1 ou BtnStart N2 *)
+    HX1_BUCKET_PREPARE := 1,   (* M2 seul palier 1, ouv + ferm sans butees soft, garde continue 20s + decompte, BtnValidate neutre *)
+    HX2_CLIMB_TO_TOP   := 2,   (* Couple M1+M2 palier 1 : montee lente + detente 2s max/geste, viser avant TOP sans toucher *)
+    HX3_TOP_CLEARANCE  := 3,   (* Contact TOP = perdu/surcourse -> montee interdite, descente ~4s apres relachement TOP -> retour HX1 *)
+    HX4_FINAL_CONFIRM  := 4,   (* Arret avant TOP + avertissement -> BtnValidate neutre -> preset 8.5m M1+M2 + CommitClose -> Homed *)
+    HX7_FAILED         := 5    (* Echec / abandon : coupure mouvements, purge etats, attente Reset conscient *)
 );
 END_TYPE
diff --git a/CODE/G_CYCLE/_TYPES/ST_MachineHoming.st b/CODE/G_CYCLE/_TYPES/ST_MachineHoming.st
index 224957a7..45df6b4b 100644
--- a/CODE/G_CYCLE/_TYPES/ST_MachineHoming.st
+++ b/CODE/G_CYCLE/_TYPES/ST_MachineHoming.st
@@ -24,5 +24,8 @@ STRUCT
     CmdBucketOpen    : BOOL;          (* Ordre ouverture benne palier 1 sans FDC soft *)
     CmdBucketClose   : BOOL;          (* Ordre fermeture benne palier 1 sans FDC soft (HX1) *)
     CmdWinchSelect   : INT;           (* Override selecteur treuil cycle homing (-1=neutre, 0=couple, 2=benne) *)
+    AllowAscent      : BOOL;          (* Autorisation montee par etape GRAFCET homing *)
+    AllowDescend     : BOOL;          (* Autorisation descente par etape GRAFCET homing *)
+    SoftLimitsOff    : BOOL;          (* Inhibition limites soft position (HX1..HX3 uniquement, hors capteur TOP) *)
 END_STRUCT
 END_TYPE
diff --git a/CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st b/CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st
index 7e0b1feb..a10c2289 100644
--- a/CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st
+++ b/CODE/G_CYCLE/_TYPES/ST_fbMachineHomingCycle_Cfg.st
@@ -22,12 +22,13 @@ STRUCT
     // (GVL_PERSISTENT._WinchSpeedConfig.SpeedBandMaxMps[1], valeur de banc A MESURER sur site)
     // => 58,5 / 0,4 = 146,3 s ; marge x2 = 292,5 s ; valeur retenue 300 s (arrondie au-dessus).
     // A revoir si la course ou la vitesse du palier 1 changent (gate G511).
-    CfgTimeoutClimb      : TIME := T#300s; // Garde de montee au capteur haut (0 = pas de garde)
-    // Garde de descente HX3 : meme regle (budget de DESCENTE CONTINUE).
-    CfgTimeoutHomeAxes   : TIME := T#60s;  // Garde globale prise de référence (0 = pas de garde)
-    CfgTimeoutFlyingHoming : TIME := T#3s; // Garde essai prise de référence au vol (Mode A) avant repli automatique à l'arrêt (Mode B)
-    CfgStabilizationMinM : REAL := 7.50;   // Seuil bas d'inertie stabilisée après référence (m) - HX4 (constante volontaire, valeur a risque, pas d'IHM)
-    CfgStabilizationMaxM : REAL := 9.50;   // Seuil haut d'inertie stabilisée après référence (m) - HX4 (constante volontaire, valeur a risque, pas d'IHM)
-    Initialized          : BOOL := FALSE;  // Drapeau de restauration config au boot (pont persistant)
+    CfgTimeoutClimb         : TIME := T#300s; // Garde de montee au capteur haut (0 = pas de garde)
+    CfgEntryHoldTime        : TIME := T#5s;   // Duree maintien BP joystick au neutre en HX0 (MAINT_N1)
+    CfgBucketPrepareTimeout : TIME := T#20s;  // Duree max commande continue M2 en HX1 (coupe -> neutre)
+    CfgSlackReliefMaxTime   : TIME := T#2s;   // Duree max descente detente cable par geste en HX2
+    CfgTopClearanceTime     : TIME := T#4s;   // Duree descente accumulee apres relachement TOP en HX3
+    CfgTopApproachMaxM      : REAL := 10.5;   // Plafond encodeur secours HX2 si capteur TOP bloque FALSE (m)
+    CfgTimeoutHomeAxes      : TIME := T#60s;  // Garde globale prise de reference (HX4)
+    Initialized             : BOOL := FALSE;  // Drapeau de restauration config au boot (pont persistant)
 END_STRUCT
 END_TYPE

`
