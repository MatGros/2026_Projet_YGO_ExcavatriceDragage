(* =======================================================================
   🎯 FB_MachineHomingCycle — Guide de referencement machine M1/M2/benne
   ───────────────────────────────────────────────────────────────
   🎯 Role : Qualifier le datum machine (2 codeurs cales + etat benne
             confirme) et guider le homing conjoint M1/M2 + le commit
             atomique de l'etat benne. N'emet AUCUN ordre de mouvement.
   🔒 Securite : SEMI_AUTO interdit tant que MachineHomed=FALSE. Perte de
                 datum en mouvement -> SafeStop ; reprise sur Reset conscient
                 uniquement (aucun redemarrage automatique).
   🔌 Interface : contrat standard (Enable/Reset, Ready/Fault/Lifecycle).
                  Producteur UNIQUE de la qualification machine — ne relit
                  jamais un ActiveOffsetValid aval (T185 C-3).
   📄 Doc metier : DOC/AF/AF_Partie-09_Fonction_Encoder_v2.4.md (F09.08)
                   + DOC/AF/AF_Partie-05_Modes_Maintenance_v2.1.md
   🧩 Dependances : FB_FaultCore, FB_Encoder (M1/M2), FB_Bucket, FB_Modes
   ======================================================================= *)
FUNCTION_BLOCK PUBLIC FB_MachineHomingCycle
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                      : BOOL;                                      // --> [CMD] Autorisation generale (FALSE => sorties sures, retour IDLE)
    Reset                       : BOOL;                                      // --> [CMD] Acquittement defaut (front, jamais conditionne)

    // === MODE ARBITRE ===
    Mode                        : E_Mode;                                    // --> [CMD] Mode machine (confirmation benne : MAINT_N2 seul)

    // === PERMIS SECURITE ===
    TopPositionActive           : BOOL;                                      // --> [SAFE] Capteur haut commun au contact
    WinchesMechanicallyStopped  : BOOL;                                      // --> [SAFE] M1 ET M2 arret mecanique confirme

    // === ACQUISITION HOMING (M1 / M2) ===
    M1Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M1 (Retenue)
    M2Status                    : ST_fbMachineHomingCycle_AxisHomingStatus;  // --> [HW] Statut homing axe M2 (Benne)

    // === ETAT BENNE ===
    BucketOffsetValid           : BOOL;                                      // --> [HW] Offset benne actif valide (FB_Bucket) — bootstrap datum seulement

    // === COMMANDES OPERATEUR (IHM) ===
    ConfirmOpenPosition         : BOOL;                                      // --> [CMD] Confirmation visuelle "benne ouverte" (niveau, front interne)
    ConfirmClosePosition        : BOOL;                                      // --> [CMD] Confirmation visuelle "benne fermee" (niveau, front interne)

    // === REGLAGES & CONFIGURATION ===
    CfgTopHomingTargetM         : REAL;                                      // --> [CFG] Cible haute configuree M1 (m)
    CfgOffsetOpenM              : REAL;                                      // --> [CFG] Ecart geometrique benne ouverte (m)
    CfgOffsetCloseM             : REAL;                                      // --> [CFG] Ecart geometrique benne fermee (m)
END_VAR
VAR_OUTPUT
    // === CONTRAT STANDARD (Ready + Fault) ===
    Ready                       : BOOL;                                      // <-- [STAT] FB actif (Enable ET NOT Fault.Latched)
    Fault                       : ST_Fault;                                  // <-- [SAFE] Socle defaut (rempli par FB_FaultCore)
    Lifecycle                   : ST_Lifecycle;                              // <-- [STAT] Cycle transaction (Busy = homing conjoint en cours)

    // === QUALIFICATION MACHINE ===
    MachineHomed                : BOOL;                                      // <-- [SAFE] Datum machine valide (gate SEMI_AUTO)
    MachineHomingStep           : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [STAT] Etape du guide
    MachineHomingStepAtError    : E_MachineHomingStep := E_MachineHomingStep.IDLE;   // <-- [DIAG] Etape figee a l'apparition du defaut (R9)
    MachineHomingInstruction    : STRING(120);                              // <-- [DIAG] Consigne operateur en clair (ASCII)
    MachineHomingActive         : BOOL;                                      // <-- [STAT] Transaction en cours (= Lifecycle.Busy)
    MachineHomingLossSafeStop   : BOOL;                                      // <-- [SAFE] Demande d'arret controle suite perte de datum en mouvement
    MachineHomingFailed         : BOOL;                                      // <-- [STAT] Derniere transaction abandonnee

    // === DEMANDES HOMING (M1 / M2) ===
    M1Demand                    : ST_fbMachineHomingCycle_HomingDemand;      // <-- [ACT] Demande de homing conjoint axe M1
    M2Demand                    : ST_fbMachineHomingCycle_HomingDemand;      // <-- [ACT] Demande de homing conjoint axe M2 (cible dynamique)

    // === COMMIT BENNE ===
    BucketCommit                : ST_fbMachineHomingCycle_BucketCommit;      // <-- [ACT] Publication atomique de l'etat benne (vers FB_Bucket)
END_VAR
VAR
    // === SOUS-INSTANCES FB ===
    instFault                   : FB_FaultCore;                             // * [INST] Socle defaut transverse
    ResetEdge                   : R_TRIG;                                   // * [INST] Front montant Reset
    ConfirmOpenEdge             : R_TRIG;                                   // * [INST] Front montant ConfirmOpenPosition
    ConfirmCloseEdge            : R_TRIG;                                   // * [INST] Front montant ConfirmClosePosition
    LatchedEdge                 : R_TRIG;                                   // * [INST] Front montant Fault.Latched (capture R9)

    // === TABLE DES CAUSES DE DEFAUT ===
    instCauses                  : ARRAY[0..15] OF ST_FaultCause;            // . [LOC] Causes en clair pour FB_FaultCore

    // === ETATS INTERNES TRANSACTION ===
    PendingOpen                 : BOOL;                                     // . [LOC] Confirmation "ouverte" en attente de commit
    PendingClose                : BOOL;                                     // . [LOC] Confirmation "fermee" en attente de commit
    HomingStarted               : BOOL;                                     // . [LOC] Transaction homing conjoint armee
    HomingBusyObserved          : BOOL;                                     // . [LOC] Au moins un Busy observe depuis le debut de la transaction
    CommitPublished             : BOOL;                                     // . [LOC] Commit benne deja publie sur ce datum
    MachineWasHomed             : BOOL;                                     // . [LOC] Memorise un datum valide (detection de perte)
    HomingLossLatched           : BOOL;                                     // . [LOC] Perte de datum en mouvement latchee jusqu'a l'arret
    ReHomingAckRequired         : BOOL;                                     // . [LOC] C-1 : bloque MachineHomed jusqu'a un Reset conscient

    // === CONDITIONS INTERMEDIAIRES NOMMEES (std 2quater : <= 3 termes) ===
    DoubleConfirmRequested      : BOOL;                                     // . [LOC] Les deux fronts confirmation au meme scan (C-2)
    SingleConfirm               : BOOL;                                     // . [LOC] Exactement un front confirmation
    ConfirmWhileHoming          : BOOL;                                     // . [LOC] Confirmation pendant un homing d'axe en cours (C-4.3)
    WindowSafe                  : BOOL;                                     // . [LOC] Fenetre mecanique sure (N2 + capteur haut + arret)
    AxisHomed                   : BOOL;                                     // . [LOC] M1 ET M2 references et fiables
    CommitOrOffsetValid         : BOOL;                                     // . [LOC] Datum benne connu (commit publie OU offset valide)
    TransactionAbort            : BOOL;                                     // . [LOC] Condition d'abandon fail-safe de la transaction
    MachineHomedRaw             : BOOL;                                     // . [LOC] Qualification hors Fault (detection de perte, evite la circularite)
END_VAR
VAR CONSTANT
    // === INDICES DE CAUSES (instCauses[]) ===
    CAUSE_HOMING_LOST_IN_MOTION : INT := 0;                                 // Perte d'un datum valide pendant un mouvement (Latching)
    CAUSE_TX_ABORT_TOP_LOST     : INT := 1;                                 // Capteur haut perdu pendant la transaction (Latching)
    CAUSE_TX_ABORT_MOTION       : INT := 2;                                 // Mouvement detecte pendant la transaction (Latching)
    CAUSE_HOMING_ERROR_M1       : INT := 3;                                 // FB_Encoder M1 signale une erreur de homing (Latching)
    CAUSE_HOMING_ERROR_M2       : INT := 4;                                 // FB_Encoder M2 signale une erreur de homing (Latching)
    CAUSE_DOUBLE_CONFIRM        : INT := 5;                                 // ConfirmOpen ET ConfirmClose au meme scan (Latching) — C-2
    CAUSE_CONFIRM_WHILE_HOMING  : INT := 6;                                 // Confirmation pendant un homing d'axe en cours (Latching) — C-4.3
END_VAR

// === 🔑 §1 FRONTS, CIBLE DYNAMIQUE, CAUSES ET SOCLE DEFAUT ===
{region "§1 Fronts & causes"}

// Sorties impulsionnelles remises a FALSE en tete de scan (1 scan actif au commit / a la demande).
M1Demand.HomeReq := FALSE;
M2Demand.HomeReq := FALSE;
BucketCommit.CommitOpen := FALSE;
BucketCommit.CommitClose := FALSE;

// Cible dynamique M2 : recalculee chaque scan (jamais une position M1 live).
M2Demand.UseDynamicTarget := PendingOpen OR PendingClose OR HomingStarted;
IF PendingClose THEN
    M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetCloseM;
ELSE
    M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetOpenM;
END_IF;
M1Demand.UseDynamicTarget := FALSE;

// Detection de fronts.
ResetEdge(CLK := Reset);
ConfirmOpenEdge(CLK := ConfirmOpenPosition);
ConfirmCloseEdge(CLK := ConfirmClosePosition);
LatchedEdge(CLK := Fault.Latched);

// Purge sur front Reset (inclut C-1 : ReHomingAckRequired).
IF ResetEdge.Q THEN
    PendingOpen         := FALSE;
    PendingClose        := FALSE;
    HomingStarted       := FALSE;
    HomingBusyObserved  := FALSE;
    CommitPublished     := FALSE;
    MachineHomingFailed := FALSE;
    MachineWasHomed     := FALSE;
    HomingLossLatched   := FALSE;
    ReHomingAckRequired := FALSE;
END_IF;

// Conditions intermediaires nommees (std 2quater).
DoubleConfirmRequested := ConfirmOpenEdge.Q AND ConfirmCloseEdge.Q;
SingleConfirm          := ConfirmOpenEdge.Q XOR ConfirmCloseEdge.Q;
ConfirmWhileHoming     := SingleConfirm AND (M1Status.HomingBusy OR M2Status.HomingBusy);
WindowSafe             := (Mode = E_Mode.MAINT_N2) AND TopPositionActive AND WinchesMechanicallyStopped;
AxisHomed              := M1Status.HomedAndReliable AND M2Status.HomedAndReliable;
CommitOrOffsetValid    := CommitPublished OR BucketOffsetValid;

// Qualification "brute" (sans Fault) : sert a la detection de perte sans creer de circularite
// avec le socle defaut appele plus bas.
MachineHomedRaw := AxisHomed AND CommitOrOffsetValid
                   AND NOT MachineHomingFailed AND NOT ReHomingAckRequired;

// Perte d'un datum auparavant valide EN MOUVEMENT : latch jusqu'a l'arret mecanique.
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

(* T185 C-1 : pas de redemarrage automatique. Une perte de datum en mouvement exige un
   acquittement conscient (front Reset) avant que MachineHomed puisse revenir. *)
IF HomingLossLatched AND NOT ReHomingAckRequired THEN
    ReHomingAckRequired := TRUE;
END_IF;

// Table des causes (toutes Latching : acquittables au front Reset).
instCauses[CAUSE_HOMING_LOST_IN_MOTION].Active   := HomingLossLatched OR ReHomingAckRequired;
instCauses[CAUSE_HOMING_LOST_IN_MOTION].Latching := TRUE;
instCauses[CAUSE_HOMING_LOST_IN_MOTION].Texte    := 'Perte de datum machine en mouvement : re-referencer';

instCauses[CAUSE_TX_ABORT_TOP_LOST].Active   := HomingStarted AND NOT TopPositionActive;
instCauses[CAUSE_TX_ABORT_TOP_LOST].Latching := TRUE;
instCauses[CAUSE_TX_ABORT_TOP_LOST].Texte    := 'Capteur haut perdu pendant le referencement conjoint';

instCauses[CAUSE_TX_ABORT_MOTION].Active   := HomingStarted AND NOT WinchesMechanicallyStopped;
instCauses[CAUSE_TX_ABORT_MOTION].Latching := TRUE;
instCauses[CAUSE_TX_ABORT_MOTION].Texte    := 'Mouvement detecte pendant le referencement conjoint';

instCauses[CAUSE_HOMING_ERROR_M1].Active   := HomingStarted AND M1Status.HomingError;
instCauses[CAUSE_HOMING_ERROR_M1].Latching := TRUE;
instCauses[CAUSE_HOMING_ERROR_M1].Texte    := 'Erreur de homing codeur M1 pendant le referencement conjoint';

instCauses[CAUSE_HOMING_ERROR_M2].Active   := HomingStarted AND M2Status.HomingError;
instCauses[CAUSE_HOMING_ERROR_M2].Latching := TRUE;
instCauses[CAUSE_HOMING_ERROR_M2].Texte    := 'Erreur de homing codeur M2 pendant le referencement conjoint';

(* T185 C-2 : confirmation Ouverte ET Fermee au meme scan = rejet total, cause a acquitter. *)
instCauses[CAUSE_DOUBLE_CONFIRM].Active   := DoubleConfirmRequested;
instCauses[CAUSE_DOUBLE_CONFIRM].Latching := TRUE;
instCauses[CAUSE_DOUBLE_CONFIRM].Texte    := 'Confirmation benne Ouverte et Fermee simultanee : refusee';

(* T185 C-4.3 : confirmation recue pendant un homing d'axe deja en cours = ignoree. *)
instCauses[CAUSE_CONFIRM_WHILE_HOMING].Active   := ConfirmWhileHoming;
instCauses[CAUSE_CONFIRM_WHILE_HOMING].Latching := TRUE;
instCauses[CAUSE_CONFIRM_WHILE_HOMING].Texte    := 'Confirmation benne pendant un homing codeur en cours : ignoree';

// Socle defaut : appele AVANT la gate NOT Enable (Reset jamais conditionne, std 9).
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

// === 🔑 §2 DEMANDE SAFESTOP SUR PERTE DE DATUM ===
{region "§2 Perte datum"}
// Demande d'arret controle tant que la perte n'est pas mecaniquement resolue.
// La qualification de sortie MachineHomed est calculee en §6, APRES le deroule de
// transaction (commit ou abandon du meme scan pris en compte) — calcul unique.
MachineHomingLossSafeStop := HomingLossLatched;
{endregion}

// === 🔑 §3 GATE D'INITIALISATION (NOT Enable) ===
{region "§3 Gate init NOT Enable"}
IF NOT Enable THEN
    MachineHomingStep         := E_MachineHomingStep.IDLE;
    MachineHomingInstruction  := 'Referencement indisponible';
    MachineHomed              := FALSE;
    MachineHomingActive       := FALSE;
    M1Demand.HomeReq          := FALSE;
    M2Demand.HomeReq          := FALSE;
    M1Demand.UseDynamicTarget := FALSE;
    M2Demand.UseDynamicTarget := FALSE;
    BucketCommit.CommitOpen   := FALSE;
    BucketCommit.CommitClose  := FALSE;
    Lifecycle.Busy            := FALSE;
    Lifecycle.Done            := FALSE;
    Ready                     := FALSE;
    RETURN;
END_IF;
{endregion}

// === 🔑 §4 OUVERTURE DE LA TRANSACTION DE REFERENCEMENT CONJOINT ===
{region "§4 Ouverture transaction"}
(* T185 C-4.1 : jamais "au vol" par-dessus un homing d'axe deja en cours.
   Demande acceptee uniquement dans la fenetre mecanique sure, front unique, hors double. *)
IF SingleConfirm AND NOT HomingStarted AND NOT DoubleConfirmRequested AND NOT ConfirmWhileHoming
   AND WindowSafe
   AND NOT M1Status.HomingBusy AND NOT M2Status.HomingBusy THEN
    PendingOpen        := ConfirmOpenEdge.Q;
    PendingClose       := ConfirmCloseEdge.Q;
    HomingStarted      := TRUE;
    HomingBusyObserved := FALSE;
    CommitPublished    := FALSE;
    MachineHomingFailed := FALSE;
    M1Demand.HomeReq          := TRUE;
    M2Demand.HomeReq          := TRUE;
    M2Demand.UseDynamicTarget := TRUE;
    IF PendingClose THEN
        M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetCloseM;
    ELSE
        M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetOpenM;
    END_IF;
END_IF;
{endregion}

// === 🔑 §5 DEROULE DE LA TRANSACTION & COMMIT ATOMIQUE ===
{region "§5 Deroule transaction & commit atomique"}
IF HomingStarted THEN
    M2Demand.UseDynamicTarget := TRUE;
    IF PendingClose THEN
        M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetCloseM;
    ELSE
        M2Demand.DynamicTarget_M := CfgTopHomingTargetM + CfgOffsetOpenM;
    END_IF;

    TransactionAbort := (NOT TopPositionActive) OR (NOT WinchesMechanicallyStopped)
                        OR M1Status.HomingError OR M2Status.HomingError;

    IF TransactionAbort THEN
        MachineHomingFailed := TRUE;
        HomingStarted       := FALSE;
        PendingOpen         := FALSE;
        PendingClose        := FALSE;
    ELSIF M1Status.HomingBusy OR M2Status.HomingBusy THEN
        HomingBusyObserved := TRUE;
    ELSIF HomingBusyObserved AND M1Status.HomedAndReliable AND M2Status.HomedAndReliable
          AND M1Status.HomingDone AND M2Status.HomingDone THEN
        (* Publication atomique : les deux etats benne ecrits par FB_Bucket dans le meme
           scan, uniquement apres les deux succes observes. *)
        BucketCommit.CommitOpen  := PendingOpen;
        BucketCommit.CommitClose := PendingClose;
        CommitPublished := TRUE;
        HomingStarted   := FALSE;
        PendingOpen     := FALSE;
        PendingClose    := FALSE;
    END_IF;
END_IF;
{endregion}

// === 🔑 §6 CYCLE DE VIE, R9 ET GUIDE OPERATEUR ===
{region "§6 Guide operateur & sorties"}
MachineHomingActive := HomingStarted;
Lifecycle.Busy      := HomingStarted;
Lifecycle.Done      := CommitPublished;

// Qualification de sortie — calcul UNIQUE, apres le deroule de transaction (§5) : un commit
// atomique OU un abandon du meme scan est immediatement reflete (comportement d'origine).
CommitOrOffsetValid := CommitPublished OR BucketOffsetValid;
MachineHomed := AxisHomed AND CommitOrOffsetValid
                AND NOT MachineHomingFailed AND NOT ReHomingAckRequired
                AND NOT Fault.Latched;

// R9 : capture de l'etape au front d'apparition du defaut latche, avant recalcul du guide.
IF LatchedEdge.Q THEN
    MachineHomingStepAtError := MachineHomingStep;
END_IF;

// Guide operateur — priorite decroissante, textes conserves a l'identique.
IF MachineHomingFailed THEN
    MachineHomingStep := E_MachineHomingStep.FAILED;
    MachineHomingInstruction := 'Referencement incomplet : rester en N2 et recommencer';
ELSIF MachineHomingLossSafeStop THEN
    MachineHomingStep := E_MachineHomingStep.LOSS_SAFESTOP;
    MachineHomingInstruction := 'Reference perdue en mouvement : arret controle en cours';
ELSIF HomingStarted OR M1Status.HomingBusy OR M2Status.HomingBusy THEN
    MachineHomingStep := E_MachineHomingStep.HOMING_IN_PROGRESS;
    MachineHomingInstruction := 'Referencement conjoint M1/M2 en cours : ne pas manoeuvrer';
ELSIF NOT M1Status.HomedAndReliable AND NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.BOTH_NOT_HOMED;
    MachineHomingInstruction := 'Codeurs M1 et M2 non references : passer en maintenance N2';
ELSIF NOT M1Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M1_NOT_HOMED;
    MachineHomingInstruction := 'Codeur M1 non reference ou mesure douteuse : homer M1';
ELSIF NOT M2Status.HomedAndReliable THEN
    MachineHomingStep := E_MachineHomingStep.M2_NOT_HOMED;
    MachineHomingInstruction := 'Codeur M2 non reference ou mesure douteuse : homer M2';
ELSIF NOT (CommitPublished OR BucketOffsetValid) THEN
    IF Mode <> E_Mode.MAINT_N2 THEN
        MachineHomingStep := E_MachineHomingStep.OFFSET_UNKNOWN;
        MachineHomingInstruction := 'Offset benne inconnu : passer en maintenance N2';
    ELSIF NOT TopPositionActive THEN
        MachineHomingStep := E_MachineHomingStep.NEED_TOP_POSITION;
        MachineHomingInstruction := 'Monter Both a vitesse lente jusqu au capteur haut';
    ELSIF NOT WinchesMechanicallyStopped THEN
        MachineHomingStep := E_MachineHomingStep.NEED_MECHANICAL_STOP;
        MachineHomingInstruction := 'Capteur haut atteint : relacher la commande et attendre l arret';
    ELSE
        MachineHomingStep := E_MachineHomingStep.AWAIT_BUCKET_CONFIRM;
        MachineHomingInstruction := 'Confirmer visuellement la benne : Fermee ou Ouverte';
    END_IF;
ELSE
    MachineHomingStep := E_MachineHomingStep.VALID;
    MachineHomingInstruction := 'Referencement machine valide : mode nominal disponible';
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

END_FUNCTION_BLOCK
