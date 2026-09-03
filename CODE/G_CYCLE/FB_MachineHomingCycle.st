(* =======================================================================
   🎯 FB_MachineHomingCycle — Cycle de referencement machine M1/M2/benne
   ───────────────────────────────────────────────────────────────
   Role : GRAFCET sequentiel (HX0..HX6 + HXF) qui coordonne le homing
             machine : montee au capteur haut, homing des axes M1/M2 au
             vol sur le front descendant du capteur, mise en position
             fermee de la benne et commit atomique de l'etat benne, jusqu'a
             MachineHomed. Emet les ordres treuil (CmdWinchM1/CmdWinchM2)
             consommes par PRG_03 -> PRG_04. Producteur UNIQUE de la
             qualification machine ; ne relit jamais un ActiveOffsetValid
             aval. Aucun mouvement sans permis operateur maintenu.
   📄 Doc métier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_MachineHomingCycle
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale (FALSE => sorties sures, retour HX0)
    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut / abandon cycle (front, jamais conditionne)

    // === MODE ARBITRE ===
    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (referencement : MAINT_N2 seul)

    // === PERMIS SECURITE ===
    TopPositionSensor           : BOOL;                                      // --> [SAFE] Capteur haut (FDC logiciel) commun M1/M2
    WinchesMechanicallyStopped  : BOOL;                                      // --> [SAFE] M1 ET M2 arret mecanique confirme

    // === ACQUISITION HOMING (M1 / M2) ===
    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1 (Retenue)
    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2 (Benne)

    // === ETAT BENNE ===
    BucketOffsetValid           : BOOL;                                      // --> [HW] Offset benne actif valide (FB_Bucket) — bootstrap datum seulement

    // === PERMIS OPERATEUR (joystick + homme-mort) ===
    DeadmanArmed                : BOOL;                                      // --> [CMD] Homme-mort arme
    JoystickDeflected           : BOOL;                                      // --> [CMD] Joystick defléchi (un axe quelconque) — sert au latch SeenNeutral
    JoystickPull                : BOOL;                                      // --> [CMD] Manche tire vers soi = sens montee treuils
    JoystickPush                : BOOL;                                      // --> [CMD] Manche pousse = sens descente treuils

    // === VALIDATION OPERATEUR (mecanisme homogene machine) ===
    BtnValidation               : BOOL;                                      // --> [CMD] BP joystick (homme-mort) — motif 3 appuis successifs (V_EXPLICITE)
    StartRequest                : BOOL;                                      // --> [CMD] Lancer le cycle (front) — commande IHM dediee, alternative au motif joystick

    // === REGLAGES & CONFIGURATION ===
    Cfg                         : ST_fbMachineHomingCycle_Cfg;              // --> [CFG] Reglages geometriques + temporisations de garde
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
    MachineHomingInstruction    : STRING(120);                              // <-- [DIAG] Consigne operateur en clair (ASCII)
    MachineHomingActive         : BOOL;                                      // <-- [STAT] Cycle en cours (= Lifecycle.Busy)
    MachineHomingLossSafeStop   : BOOL;                                      // <-- [STAT] Demande d'arret controle suite perte de datum en mouvement
    MachineHomingFailed         : BOOL;                                      // <-- [STAT] Derniere sequence abandonnee

    // === DEMANDES HOMING (M1 / M2) ===
    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;      // <-- [ACT] Demande de homing conjoint axe M1
    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;      // <-- [ACT] Demande de homing conjoint axe M2 (cible dynamique)

    // === ORDRES MOUVEMENT TREUIL (vers PRG_03 -> PRG_04) ===
    CmdWinchM1                  : ST_ProgramWinchRequest;                    // <-- [ACT] Ordre treuil M1 (montee/descente palier 1)
    CmdWinchM2                  : ST_ProgramWinchRequest;                    // <-- [ACT] Ordre treuil M2 (montee/descente palier 1)

    // === ORDRES BENNE (palier 1, sans FDC logiciel — HX4) ===
    CmdBucketOpen               : BOOL;                                      // <-- [ACT] Ordre ouverture benne palier 1 sans FDC soft
    CmdBucketClose              : BOOL;                                      // <-- [ACT] Ordre fermeture benne palier 1 sans FDC soft

    // === COMMIT BENNE ===
    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;      // <-- [ACT] Publication atomique de l'etat benne (vers FB_Bucket)

    // === VERROU TRANSLATION ===
    M3Locked                    : BOOL;                                      // <-- [STAT] Translation M3 interdite tant que le cycle homing n'est pas en HX0
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    instFault                   : FB_FaultCore;                             // * [INST] Socle defaut transverse
    ResetEdge                   : R_TRIG;                                   // . [LOC] Front montant Reset
    LatchedEdge                 : R_TRIG;                                   // . [LOC] Front montant Fault.Latched (capture R9)
    TopLostEdge                 : F_TRIG;                                   // . [LOC] Front DESCENDANT TopPositionSensor (sortie capteur = homing axes au vol)

    // === TABLE DES CAUSES DE DEFAUT ===
    instCauses                  : ARRAY[0..15] OF ST_FaultCause;            // . [LOC] Causes en clair pour FB_FaultCore

    // === GRAFCET ===
    SeqStep                     : E_MachineHomingTxState := E_MachineHomingTxState.HX0_REPOS; // . [LOC] Step GRAFCET courant
    PendingClose                : BOOL;                                     // . [LOC] Confirmation "benne fermee" en attente de commit (pose en HT4)
    CommitPublished             : BOOL;                                     // . [LOC] Commit benne deja publie sur ce datum
    CommitDone                  : BOOL;                                     // . [LOC] Commit CommitClose deja emis (impulsion 1 scan garantie en HX5)
    CycleRunning                : BOOL;                                     // . [LOC] Miroir de (SeqStep hors HX0/HX1) — cycle mouvement engage
    HomeReqDone                 : BOOL;                                     // . [LOC] Impulsion HomeReq M1+M2 deja emise sur ce passage HX3
    SeenNeutral                 : BOOL;                                     // . [LOC] Joystick repasse au neutre depuis l'entree du step d'arret

    // === TEMPORISATIONS DE GARDE ===
    ClimbTimer                  : TON;                                      // . [LOC] Garde HX2 (montee au capteur)
    HomeAxesTimer               : TON;                                      // . [LOC] Garde HX3 (descente jusqu'au front descendant)
    SettleGraceTimer            : TON;                                      // . [LOC] Fenetre de grace decelaration a l'entree d'un step d'arret
    AutoArmTimer                : TON;                                      // . [LOC] Debounce de l'auto-armement HX0->HX1 (anti-flapping MachineHomed)
    FirstScanDone               : BOOL;                                     // . [LOC] Garde 1er scan : statuts codeurs pas encore stables au boot

    // === MOTIF DE VALIDATION "3 APPUIS" (V_EXPLICITE) ===
    ValidationBtnEdgeR          : R_TRIG;                                   // . [LOC] Front montant BtnValidation
    ValidationBtnEdgeF          : F_TRIG;                                   // . [LOC] Front descendant BtnValidation
    StartEdge                   : R_TRIG;                                   // . [LOC] Front montant StartRequest (commande IHM lancer cycle)
    ValidationHoldTimer         : TON;                                     // . [LOC] Maintien >= 150 ms d'un appui
    ValidationGapTimer          : TON;                                     // . [LOC] Fenetre <= 2 s entre appuis
    ValidationPressCount        : INT;                                     // . [LOC] Compteur d'appuis valides (0..3)
    ValidationHeldOk            : BOOL;                                     // . [LOC] Appui courant maintenu >= 150 ms (latch, lu au relachement)
    ExplicitValidationPulse     : BOOL;                                    // . [LOC] Validation explicite acquise ce scan (impulsion 1 scan)

    // === CONDITIONS INTERMEDIAIRES NOMMEES (std 2quater : <= 3 termes) ===
    BothAxesHomed               : BOOL;                                    // . [LOC] M1 ET M2 references et fiables
    CommitOrOffsetValid         : BOOL;                                    // . [LOC] Datum benne connu (commit publie OU offset valide)
    ClimbPermit                 : BOOL;                                    // . [LOC] Permis operateur maintenu, sens montee
    DescendPermit               : BOOL;                                    // . [LOC] Permis operateur maintenu, sens descente
    BucketPermit                : BOOL;                                    // . [LOC] Permis operateur maintenu, benne (2 sens)
    IsInMovePhase               : BOOL;                                    // . [LOC] Step GRAFCET qui commande un mouvement treuil (HX2/HX3)
    AxisHomingError             : BOOL;                                    // . [LOC] Erreur de homing M1 ou M2
    MotionOutOfPhase            : BOOL;                                    // . [LOC] Treuil bouge hors phase mouvement, grace decel ecoulee
    ModeLostDuringCycle         : BOOL;                                    // . [LOC] Sortie de MAINT_N2 alors que le cycle est engage (HX2..HX6)
    AutoArmCandidate            : BOOL;                                    // . [LOC] Machine non referencee en maintenance : le cycle se propose
    ClimbTimedOut               : BOOL;                                    // . [LOC] Garde HX2 ecoulee
    HomeAxesTimedOut            : BOOL;                                    // . [LOC] Garde HX3 ecoulee sans axes homes
    TransactionAbort            : BOOL;                                    // . [LOC] Condition d'abandon fail-safe pendant une phase mouvement
    ReHomingAckRequired         : BOOL;                                    // . [LOC] C-1 : bloque MachineHomed jusqu'a un Reset conscient
    MachineWasHomed             : BOOL;                                    // . [LOC] Memorise un datum valide (detection de perte)
    HomingLossLatched           : BOOL;                                    // . [LOC] Perte de datum en mouvement latchee jusqu'a l'arret
    MachineHomedRaw             : BOOL;                                    // . [LOC] Qualification hors Fault (detection de perte, evite circularite)
END_VAR
VAR CONSTANT
    // === INDICES DE CAUSES (instCauses[]) ===
    CST_CauseHomingLostInMotion : INT := 0;                                // Perte d'un datum valide pendant un mouvement (Latching)
    CST_CauseClimbTimeout       : INT := 1;                                // HX2 : capteur haut non atteint dans la garde (Latching)
    CST_CauseMotionOutOfPhase   : INT := 2;                                // Treuil bouge hors phase mouvement autorisee (Latching)
    CST_CauseHomingErrorM1      : INT := 3;                                // FB_Encoder M1 signale une erreur de homing (Latching)
    CST_CauseHomingErrorM2      : INT := 4;                                // FB_Encoder M2 signale une erreur de homing (Latching)
    CST_CauseHomeAxesTimeout    : INT := 5;                                // HX3 : front descendant capteur non obtenu dans la garde (Latching)

    // === MOTIF 3 APPUIS ===
    CST_ValidationHold     : TIME := T#300ms;   // Debounce anti-flapping de l'auto-armement HX0->HX1
    CST_ValidationPressHold : TIME := T#150ms;  // Duree minimale d'un appui du motif 3 appuis
    CST_ValidationGap      : TIME := T#2s;       // Fenetre maximale entre deux appuis
    CST_ValidationCount : INT  := 3;         // Nombre d'appuis requis

    // === DIVERS ===
    CST_SettleGrace : TIME := T#3s;          // Grace deceleration a l'entree d'un step d'arret
    CST_StepSlow    : INT  := 1;             // Palier de vitesse lent (montee / descente couplee homing)
END_VAR

{region "§1 Fronts, remises a zero de tete de scan, verrou M3"}
// === §1 FRONTS + RAZ TETE DE SCAN + VERROU M3 =========================

// Sorties impulsionnelles / mouvement : remises a FALSE en tete de scan.
// Seul un step actif les remonte -> HX0 (etape initiale pure) n'ecrit rien.
M1Demand.HomeReq := FALSE;
M2Demand.HomeReq := FALSE;
BucketCommit.CommitOpen  := FALSE;
BucketCommit.CommitClose := FALSE;
CmdBucketOpen  := FALSE;
CmdBucketClose := FALSE;
CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
ExplicitValidationPulse := FALSE;

// Detection de fronts.
ResetEdge(CLK := Reset);
LatchedEdge(CLK := Fault.Latched);
TopLostEdge(CLK := TopPositionSensor);

// Miroirs booleens de contexte GRAFCET.
IsInMovePhase := (SeqStep = E_MachineHomingTxState.HX2_CLIMB)
              OR (SeqStep = E_MachineHomingTxState.HX3_HOME_AXES);
CycleRunning := (SeqStep <> E_MachineHomingTxState.HX0_REPOS)
             AND (SeqStep <> E_MachineHomingTxState.HX1_CHOICE);

// M3Locked est calcule en §9 (apres le CASE) pour verrouiller des le scan d'entree en cycle.
{endregion}

{region "§2 Conditions intermediaires & motif de validation 3 appuis"}
// === §2 CONDITIONS NOMMEES + VALIDATION EXPLICITE =====================
BothAxesHomed       := M1Status.HomedAndReliable AND M2Status.HomedAndReliable;
CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
ClimbPermit         := DeadmanArmed AND JoystickPull;
DescendPermit       := DeadmanArmed AND JoystickPush;
BucketPermit        := DeadmanArmed AND JoystickDeflected;

// Fenetre de grace deceleration : armee des qu'on entre un step d'arret depuis une phase mouvement.
// Fenetre de grace deceleration : armee sur tous les steps a l'arret (HX2N/HX3N +
// HX4/HX5 ou les treuils doivent rester immobiles).
SettleGraceTimer(IN := (SeqStep = E_MachineHomingTxState.HX2N_NEUTRAL)
                       OR (SeqStep = E_MachineHomingTxState.HX3N_PAUSE)
                       OR (SeqStep = E_MachineHomingTxState.HX4_BUCKET_ADJUST)
                       OR (SeqStep = E_MachineHomingTxState.HX5_BUCKET_COMMIT), PT := CST_SettleGrace);

// Conditions d'abandon fail-safe, chacune <= 3 termes (std 2quater).
AxisHomingError  := M1Status.HomingError OR M2Status.HomingError;
MotionOutOfPhase := CycleRunning AND NOT IsInMovePhase
                    AND NOT WinchesMechanicallyStopped AND SettleGraceTimer.Q;
ClimbTimedOut    := (SeqStep = E_MachineHomingTxState.HX2_CLIMB) AND ClimbTimer.Q;
HomeAxesTimedOut := (SeqStep = E_MachineHomingTxState.HX3_HOME_AXES) AND HomeAxesTimer.Q AND NOT BothAxesHomed;
// Sortie de MAINT_N2 alors qu'un step mouvement/commit est engage : abandon fail-safe.
ModeLostDuringCycle := CycleRunning AND (Mode <> E_Mode.MAINT_N2);
TransactionAbort := CycleRunning
                    AND (AxisHomingError OR MotionOutOfPhase OR ClimbTimedOut
                         OR HomeAxesTimedOut OR ModeLostDuringCycle);

// Auto-armement HX0->HX1 : machine non referencee en maintenance (N1 ou N2), le cycle
// se propose de lui-meme (HX1 = annonce + choix, AUCUN mouvement). Debounce anti-flapping
// sur MachineHomed + garde 1er scan (statuts codeurs non stables au boot). Jamais apres
// defaut non acquitte (regle C : Reset conscient).
AutoArmCandidate := FirstScanDone
                    AND NOT MachineHomed AND NOT MachineHomingFailed
                    AND NOT ReHomingAckRequired AND NOT HomingLossLatched
                    AND ((Mode = E_Mode.MAINT_N1) OR (Mode = E_Mode.MAINT_N2));
AutoArmTimer(IN := AutoArmCandidate, PT := CST_ValidationHold);

// --- Motif "3 appuis successifs" -> ExplicitValidationPulse ---
// Pre-conditions permanentes : joystick centre + aucun mouvement + homme-mort arme.
ValidationBtnEdgeR(CLK := BtnValidation);
ValidationBtnEdgeF(CLK := BtnValidation);
StartEdge(CLK := StartRequest);
ValidationHoldTimer(IN := BtnValidation, PT := CST_ValidationPressHold);
ValidationGapTimer(IN := (ValidationPressCount > 0) AND NOT BtnValidation, PT := CST_ValidationGap);

// Latch "appui maintenu assez longtemps" : lu au relachement (le TON retombe le meme
// scan que la chute de BtnValidation, donc on ne peut pas tester holdTimer.Q sur le front F).
IF BtnValidation AND ValidationHoldTimer.Q THEN
    ValidationHeldOk := TRUE;
END_IF;

// Motif = geste STANDALONE (3 appuis courts sur le BP joystick, joystick centre,
// treuils arretes). Ne PAS exiger DeadmanArmed : le BP joystick EST le bouton
// homme-mort ; on ne peut pas le maintenir arme ET faire des appuis courts.
IF JoystickDeflected OR NOT WinchesMechanicallyStopped THEN
    ValidationPressCount := 0;
    ValidationHeldOk     := FALSE;
ELSIF ValidationGapTimer.Q THEN
    ValidationPressCount := 0;                       // fenetre entre appuis depassee
    ValidationHeldOk     := FALSE;
ELSIF ValidationBtnEdgeF.Q AND ValidationHeldOk THEN
    ValidationPressCount := ValidationPressCount + 1; // appui maintenu >= 300 ms puis relache -> compte
    ValidationHeldOk     := FALSE;
END_IF;

IF ValidationPressCount >= CST_ValidationCount THEN
    ExplicitValidationPulse := TRUE;                 // impulsion 1 scan
    ValidationPressCount    := 0;
END_IF;
{endregion}

{region "§3 Detection de perte de datum (independante de Fault)"}
// === §3 DETECTION DE PERTE DE DATUM ==================================
MachineHomedRaw := BothAxesHomed AND CommitOrOffsetValid
                   AND NOT MachineHomingFailed AND NOT ReHomingAckRequired;

IF MachineHomedRaw THEN
    MachineWasHomed := TRUE;
END_IF;
IF MachineWasHomed AND NOT MachineHomedRaw AND NOT WinchesMechanicallyStopped THEN
    HomingLossLatched := TRUE;
END_IF;
IF NOT MachineHomedRaw AND WinchesMechanicallyStopped THEN
    MachineWasHomed := FALSE;
END_IF;
IF HomingLossLatched AND WinchesMechanicallyStopped THEN
    HomingLossLatched := FALSE;
END_IF;

(* C : pas de redemarrage automatique. Une perte de datum en mouvement exige un
   acquittement conscient (front Reset) avant que MachineHomed puisse revenir. *)
IF HomingLossLatched AND NOT ReHomingAckRequired THEN
    ReHomingAckRequired := TRUE;
END_IF;

MachineHomingLossSafeStop := HomingLossLatched;
{endregion}

{region "§4 Purge sur front Reset (abandon cycle / acquittement)"}
// === §4 PURGE SUR FRONT RESET =======================================
IF ResetEdge.Q THEN
    SeqStep             := E_MachineHomingTxState.HX0_REPOS;
    PendingClose        := FALSE;
    CommitPublished     := FALSE;
    CommitDone          := FALSE;
    HomeReqDone         := FALSE;
    SeenNeutral         := FALSE;
    ValidationPressCount := 0;
    ValidationHeldOk    := FALSE;
    MachineHomingFailed := FALSE;
    MachineWasHomed     := FALSE;
    HomingLossLatched   := FALSE;
    ReHomingAckRequired := FALSE;
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
instCauses[CST_CauseHomeAxesTimeout].Texte    := 'Homing des axes non obtenu dans le temps imparti';

// Socle defaut : appele AVANT la gate NOT Enable (Reset jamais conditionne, std 9).
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§6 Gate initialisation (NOT Enable)"}
// === §6 GATE NOT ENABLE : SORTIES SURES + RETURN =====================
IF NOT Enable THEN
    SeqStep                  := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingStep        := E_MachineHomingStep.IDLE;
    MachineHomingSeqStep     := E_MachineHomingTxState.HX0_REPOS;
    MachineHomingInstruction := 'Homing indisponible';
    MachineHomed             := FALSE;
    MachineHomingActive      := FALSE;
    M1Demand.HomeReq          := FALSE; M1Demand.UseDynamicTarget := FALSE;
    M2Demand.HomeReq          := FALSE; M2Demand.UseDynamicTarget := FALSE;
    CmdWinchM1.RunRequest := FALSE; CmdWinchM1.ReqAscent := FALSE; CmdWinchM1.ReqDescend := FALSE; CmdWinchM1.StepTgt := 0;
    CmdWinchM2.RunRequest := FALSE; CmdWinchM2.ReqAscent := FALSE; CmdWinchM2.ReqDescend := FALSE; CmdWinchM2.StepTgt := 0;
    CmdBucketOpen  := FALSE;
    CmdBucketClose := FALSE;
    BucketCommit.CommitOpen  := FALSE;
    BucketCommit.CommitClose := FALSE;
    Lifecycle.Busy           := FALSE;
    Lifecycle.Done           := FALSE;
    Ready                    := FALSE;
    M3Locked                 := FALSE;
    CycleRunning             := FALSE;
    HomeReqDone              := FALSE;
    SeenNeutral              := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§7 Cible dynamique M2 & temporisations de garde"}
// === §7 CIBLE DYNAMIQUE M2 + GARDES ==================================
M1Demand.UseDynamicTarget := FALSE;
IF (SeqStep = E_MachineHomingTxState.HX3_HOME_AXES) THEN
    M2Demand.UseDynamicTarget := TRUE;
    M2Demand.DynamicTarget_M  := Cfg.CfgTopHomingTarget_M + Cfg.CfgOffsetClose_M;
ELSE
    M2Demand.UseDynamicTarget := FALSE;
END_IF;

ClimbTimer(IN := (SeqStep = E_MachineHomingTxState.HX2_CLIMB) AND (Cfg.CfgTimeoutClimb > T#0s),
           PT := Cfg.CfgTimeoutClimb);
HomeAxesTimer(IN := (SeqStep = E_MachineHomingTxState.HX3_HOME_AXES) AND (Cfg.CfgTimeoutHomeAxes > T#0s),
              PT := Cfg.CfgTimeoutHomeAxes);
{endregion}

{region "§8 GRAFCET de referencement machine (CASE SeqStep)"}
// === §8 GRAFCET (CASE SeqStep) ======================================
// Carte des steps HX0..HX6 + HXF, actions et receptivites : voir
//   DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08 - cycle de homing machine).
// Chaque arme du CASE porte 1 ligne de rappel ; la source de verite reste l'AF.
// ====================================================================
CASE SeqStep OF

    E_MachineHomingTxState.HX0_REPOS:
        // Etape initiale pure : aucune action de sortie ici.
        // HT0 : lancement explicite (commande IHM / motif 3 appuis) OU perte de datum OU
        // auto (machine non referencee en maintenance N1/N2). Vers HX1 = annonce + choix,
        // AUCUN mouvement. CommitPublished N'est PAS efface ici (fait a HT1b, cf. glitch).
        IF (StartEdge.Q OR ExplicitValidationPulse
            OR (MachineWasHomed AND NOT MachineHomedRaw)
            OR AutoArmTimer.Q)
           AND ((Mode = E_Mode.MAINT_N1) OR (Mode = E_Mode.MAINT_N2)) THEN
            HomeReqDone := FALSE;
            SeqStep     := E_MachineHomingTxState.HX1_CHOICE;
        END_IF;

    E_MachineHomingTxState.HX1_CHOICE:
        // Annonce + choix. Aucun ordre mouvement (garanti par la RAZ de tete de scan).
        // Retour HX0 si le datum redevient valide (recuperation transitoire) ou si on
        // quitte la maintenance. Le referencement (mouvement) exige MAINT_N2.
        IF MachineHomed
           OR ((Mode <> E_Mode.MAINT_N1) AND (Mode <> E_Mode.MAINT_N2)) THEN
            SeqStep := E_MachineHomingTxState.HX0_REPOS;
        ELSIF ExplicitValidationPulse AND (Mode = E_Mode.MAINT_N2) THEN
            CommitPublished := FALSE;   // datum invalide tant qu'il est refait (HT1b, deplace de HX0)
            CommitDone      := FALSE;
            IF NOT TopPositionSensor THEN
                SeqStep := E_MachineHomingTxState.HX2_CLIMB;
            ELSE
                SeenNeutral := NOT JoystickDeflected;
                SeqStep     := E_MachineHomingTxState.HX2N_NEUTRAL;
            END_IF;
        END_IF;
        // HT1a (abandon) traite par la purge §4 sur front Reset.

    E_MachineHomingTxState.HX2_CLIMB:
        // Montee couplee M1+M2 palier 1, uniquement sous permis maintenu (manche tire).
        IF ClimbPermit THEN
            CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqAscent := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
            CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqAscent := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
        END_IF;
        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF TopPositionSensor THEN
            SeenNeutral := NOT JoystickDeflected;
            SeqStep     := E_MachineHomingTxState.HX2N_NEUTRAL;
        END_IF;

    E_MachineHomingTxState.HX2N_NEUTRAL:
        // Mouvement nul obligatoire entre montee (tire) et descente (pousse).
        IF NOT JoystickDeflected THEN
            SeenNeutral := TRUE;
        END_IF;
        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF WinchesMechanicallyStopped AND SeenNeutral AND DescendPermit
              AND TopPositionSensor THEN
            HomeReqDone := FALSE;
            SeqStep     := E_MachineHomingTxState.HX3_HOME_AXES;
        END_IF;

    E_MachineHomingTxState.HX3_HOME_AXES:
        // Descente couplee M1+M2 palier 1 sous permis maintenu (manche pousse).
        IF DescendPermit THEN
            CmdWinchM1.RunRequest := TRUE; CmdWinchM1.ReqDescend := TRUE; CmdWinchM1.StepTgt := CST_StepSlow;
            CmdWinchM2.RunRequest := TRUE; CmdWinchM2.ReqDescend := TRUE; CmdWinchM2.StepTgt := CST_StepSlow;
        END_IF;
        // Homing des AXES seulement, au vol, sur le front DESCENDANT du capteur.
        IF TopLostEdge.Q AND NOT HomeReqDone THEN
            M1Demand.HomeReq := TRUE;
            M2Demand.HomeReq := TRUE;
            HomeReqDone      := TRUE;
        END_IF;
        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF NOT TopPositionSensor AND M1Status.HomedAndReliable AND M2Status.HomedAndReliable THEN
            SeenNeutral := NOT JoystickDeflected;
            SeqStep     := E_MachineHomingTxState.HX3N_PAUSE;
        END_IF;

    E_MachineHomingTxState.HX3N_PAUSE:
        // Arret avant benne : treuils + benne a 0 (RAZ tete de scan), retour au neutre.
        IF NOT JoystickDeflected THEN
            SeenNeutral := TRUE;
        END_IF;
        IF TransactionAbort THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF WinchesMechanicallyStopped AND SeenNeutral THEN
            SeqStep := E_MachineHomingTxState.HX4_BUCKET_ADJUST;
        END_IF;

    E_MachineHomingTxState.HX4_BUCKET_ADJUST:
        // Benne palier 1 SANS FDC soft, 2 sens ; treuils a 0.
        IF BucketPermit AND JoystickPull THEN
            CmdBucketClose := TRUE;
        ELSIF BucketPermit AND JoystickPush THEN
            CmdBucketOpen := TRUE;
        END_IF;
        // Fail-safe : erreur codeur OU treuil qui flue hors phase OU sortie de MAINT_N2.
        IF AxisHomingError OR MotionOutOfPhase OR ModeLostDuringCycle THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF ExplicitValidationPulse AND NOT JoystickDeflected AND WinchesMechanicallyStopped THEN
            PendingClose := TRUE;
            CommitDone   := FALSE;
            SeqStep      := E_MachineHomingTxState.HX5_BUCKET_COMMIT;
        END_IF;

    E_MachineHomingTxState.HX5_BUCKET_COMMIT:
        // Commit atomique de l'etat benne : impulsion 1 scan garantie via CommitDone.
        IF AxisHomingError OR NOT BothAxesHomed OR MotionOutOfPhase OR ModeLostDuringCycle THEN
            MachineHomingFailed := TRUE;
            SeqStep := E_MachineHomingTxState.HXF_FAILED;
        ELSIF NOT CommitDone THEN
            BucketCommit.CommitClose := PendingClose;
            CommitPublished          := TRUE;
            CommitDone               := TRUE;
        ELSE
            PendingClose := FALSE;
            SeqStep      := E_MachineHomingTxState.HX6_HOMED;
        END_IF;

    E_MachineHomingTxState.HX6_HOMED:
        // MachineHomed calcule en §9. Retour immediat a l'etape initiale.
        SeqStep := E_MachineHomingTxState.HX0_REPOS;

    E_MachineHomingTxState.HXF_FAILED:
        // Sortie uniquement sur front Reset conscient (purge §4).
        ;

END_CASE;
{endregion}

{region "§9 Cycle de vie & qualification de sortie"}
// === §9 CYCLE DE VIE + QUALIFICATION ================================
CycleRunning := (SeqStep <> E_MachineHomingTxState.HX0_REPOS)
             AND (SeqStep <> E_MachineHomingTxState.HX1_CHOICE);
// Verrou translation : interdite des qu'on quitte l'etape initiale (calcul post-CASE : sans retard).
// Verrou translation : actif uniquement quand le cycle est reellement engage
// (HX2..HX6), pas en HX1 (annonce + choix, aucun mouvement) qui peut s'armer seul
// apres une perte de datum. Consomme par PRG_05 (M3_SafeStop_Aggregate).
M3Locked             := CycleRunning;
MachineHomingActive  := CycleRunning;
Lifecycle.Busy       := CycleRunning;
Lifecycle.Done       := CommitPublished AND (SeqStep = E_MachineHomingTxState.HX0_REPOS);
MachineHomingSeqStep := SeqStep;

// Qualification de sortie — calcul UNIQUE, apres le deroule GRAFCET (§8).
CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
MachineHomed := BothAxesHomed AND CommitOrOffsetValid
                AND NOT MachineHomingFailed AND NOT ReHomingAckRequired
                AND NOT Fault.Latched;
{endregion}

{region "§10 Guide operateur — echelle de priorite (IF/ELSIF, pas un dispatch d'etat)"}
// === §10 GUIDE OPERATEUR (echelle de priorite) ======================
// MachineHomingStep est RECALCULE chaque scan a partir des conditions courantes :
// l'etape est le resultat, pas l'etat ou l'on dispatche. La vraie machine a etats
// est le GRAFCET (§8, CASE SeqStep). Precedent : FB_Modes.st (echelle IF/ELSIF).
IF Fault.Latched THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'Erreur ou Echec homing - Acquitter (Reset)';
ELSIF MachineHomingFailed OR (SeqStep = E_MachineHomingTxState.HXF_FAILED) THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'HXF - Homing incomplet - Recommencer en N2';
ELSIF MachineHomingLossSafeStop THEN
    MachineHomingStep := E_MachineHomingStep.LOSS_SAFESTOP;
    MachineHomingInstruction := 'Reference perdue - Arret controle';
ELSIF (SeqStep = E_MachineHomingTxState.HX2_CLIMB) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
    MachineHomingInstruction := 'HX2 - RefHoming Tirer JOY palier 1 vers FDC haut';
ELSIF (SeqStep = E_MachineHomingTxState.HX2N_NEUTRAL) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
    MachineHomingInstruction := 'HX2N - RefHoming JOY au neutre puis pousser (descente)';
ELSIF (SeqStep = E_MachineHomingTxState.HX3_HOME_AXES) THEN
    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
    MachineHomingInstruction := 'HX3 - RefHoming Pousser JOY palier 1, homing M1/M2 au vol';
ELSIF (SeqStep = E_MachineHomingTxState.HX3N_PAUSE) THEN
    MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
    MachineHomingInstruction := 'HX3N - RefHoming JOY au neutre (arret avant benne)';
ELSIF (SeqStep = E_MachineHomingTxState.HX4_BUCKET_ADJUST) THEN
    MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
    MachineHomingInstruction := 'HX4 - RefHoming Fermer benne puis valider (3 appuis JOY)';
ELSIF (SeqStep = E_MachineHomingTxState.HX5_BUCKET_COMMIT)
      OR (SeqStep = E_MachineHomingTxState.HX6_HOMED) THEN
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'HX5 - RefHoming Etat benne enregistre - fin homing';
ELSIF (SeqStep = E_MachineHomingTxState.HX1_CHOICE) THEN
    IF Mode <> E_Mode.MAINT_N2 THEN
        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
        MachineHomingInstruction := 'HX1 - RefHoming Passer en MAINT_N2 pour referencer';
    ELSIF NOT TopPositionSensor THEN
        MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
        MachineHomingInstruction := 'HX1 - RefHoming Valider (3 appuis JOY) pour lancer';
    ELSE
        MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
        MachineHomingInstruction := 'HX1 - RefHoming Sur FDC haut - valider (3 appuis JOY)';
    END_IF;
ELSIF NOT M1Status.HomedAndReliable AND NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    MachineHomingInstruction := 'HX0 - RefHoming M1+M2 non ref - lancer (3 appuis JOY ou IHM)';
ELSIF NOT M1Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M1_NOT_HOMED;
    MachineHomingInstruction := 'HX0 - RefHoming M1 non ref - relancer le homing';
ELSIF NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M2_NOT_HOMED;
    MachineHomingInstruction := 'HX0 - RefHoming M2 non ref - relancer le homing';
ELSIF NOT (CommitPublished OR BucketOffsetValid) THEN
    IF Mode <> E_Mode.MAINT_N2 THEN
        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
        MachineHomingInstruction := 'HX0 - RefHoming Offset benne inconnu - passer en N2';
    ELSE
        MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
        MachineHomingInstruction := 'HX0 - RefHoming Lancer le homing (etat benne)';
    END_IF;
ELSE
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'Reference machine valide';
END_IF;

// R9 : capture de l'etape APRES recalcul du guide, au front d'apparition du defaut latche.
IF LatchedEdge.Q THEN
    MachineHomingStepAtError := MachineHomingStep;
END_IF;

Ready := Enable AND NOT Fault.Latched;

// Garde 1er scan : bloque l'auto-armement tant que les statuts codeurs ne sont pas stables.
FirstScanDone := TRUE;
{endregion}

END_FUNCTION_BLOCK
