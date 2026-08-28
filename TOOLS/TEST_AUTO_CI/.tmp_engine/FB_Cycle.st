(* =======================================================================
   ⚙️ FB_Cycle — Séquenceur du cycle automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Automate de cycle automatique de dragage (X0 à X13 + STABILIZING)
   🔒 Sécurité : Gating par mode et homme-mort, repli STABILIZING sur défaut
   🔌 Interface : Demandes de mouvements (treuils, translation, benne)
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.3.md
   ======================================================================= *)

FUNCTION_BLOCK FB_Cycle
VAR_INPUT
    // === COMMANDES & AUTORISATIONS ===
    Enable                  : BOOL;         // --> [CMD] Activation generale du sequenceur
    Reset                   : BOOL;         // --> [CMD] Acquittement defaut (front)
    PowerContactorEngaged   : BOOL;         // --> [SAFE] Chaine de securite OK
    Mode                    : E_Mode;       // --> [CMD] Mode arbitre (SEMI_AUTO pour instance cycle)
    CycleMotionPermit       : BOOL;         // --> [CMD] Manche deflecte (non centre)
    DeadmanArmed            : BOOL;         // --> [CMD] Appui homme-mort (fenetre 3 s)
    HeartbeatIhmOk          : BOOL;         // --> [SAFE] IHM<->PLC valide

    // === COMMANDES OPERATEUR ===
    StartCycle              : BOOL;         // --> [CMD] Demande lancement / reprise (IHM)
    AbortCycle              : BOOL;         // --> [CMD] Demande abandon (IHM)

    // === CIBLES ET CONFIGURATION ===
    SelTarget               : INT;          // --> [CFG] Cible selectionnee (1=Tremie, 2=P2, 3=P1, 4=Maintenance)
    SetDepthM               : REAL;         // --> [CFG] Profondeur de consigne (negative)
    SetOffsetM              : REAL;         // --> [CFG] Ecart de fermeture benne cible

    // === FEEDBACKS CAPTEURS & MATERIEL ===
    KoboldContactFond       : BOOL;         // --> [HW] Retour dedie Kobold : TRUE = contact fond
    LimitLegalReached       : BOOL;         // --> [SAFE] Limite legale atteinte (descente interdite)
    LimitLegalDepthM        : REAL;         // --> [CFG] Profondeur legale minimale autorisee
    WinchSyncError          : BOOL;         // --> [SAFE] Desynchronisme bloquant M1/M2
    WinchSyncDeltaM         : REAL;         // --> [HW] Ecart codeurs M1/M2 pour diagnostic
    M1_CablePosM            : REAL;         // --> [HW] Position cable treuil M1 (recalee)
    M2_CablePosM            : REAL;         // --> [HW] Position cable treuil M2 (recalee)
    M1_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M1 (m/s)
    M2_MeasuredSpeedMps     : REAL;         // --> [HW] Vitesse lineaire mesuree M2 (m/s)
    SpeedMismatchThresholdMps : REAL;       // --> [CFG] Seuil ecart vitesse ; 0 = controle desactive
    SpeedMismatchTimeout    : TIME;         // --> [CFG] Duree de confirmation ; 0 = controle desactive
    CableLimitM1AscentM     : REAL;         // --> [CFG] Limite haute d'exploitation M1

    // === FEEDBACKS TRANSLATION M3 ===
    Translation_At_P1           : BOOL;     // --> [HW] Capteur position P1 (arret travail)
    Translation_At_Tremie       : BOOL;     // --> [HW] Capteur fin de course tremie
    Translation_At_Maintenance : BOOL;     // --> [HW] Capteur fin de course maintenance
    Translation_Busy            : BOOL;     // --> [HW] Mouvement translation en cours
    Translation_Done            : BOOL;     // --> [HW] Cible translation atteinte

    // === FEEDBACKS BENNE ===
    Benne_Busy              : BOOL;         // --> [HW] Mouvement machoires benne en cours
    Benne_Done              : BOOL;         // --> [HW] Mouvement ouverture/fermeture termine
    Benne_IsOpen            : BOOL;         // --> [HW] Benne mecaniquement ouverte memorisee
    Benne_IsClosed          : BOOL;         // --> [HW] Benne mecaniquement fermee memorisee
    Benne_IsRoughlyClosed   : BOOL;         // --> [HW] Benne a peu pres fermee (tolerance matiere)

    // === REFERENCEMENT CODEURS ===
    HomedM1                 : BOOL;         // --> [HW] Codeur M1 reference
    HomedM2                 : BOOL;         // --> [HW] Codeur M2 reference
    TopPositionSensor       : BOOL;         // --> [HW] Capteur position haute (referencement)
    HomingRequest           : BOOL;         // --> [CMD] Demande de referencement (front)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & DEFECTUOSITES ===
    Ready                   : BOOL;         // <-- [STAT] Sequenceur disponible
    Fault                   : ST_Fault;     // <-- [SAFE] Socle defaut transverse (live + latche)
    Lifecycle               : ST_Lifecycle; // <-- [STAT] Cycle de vie (Busy, Done, Waiting)
    SpeedMismatchMps        : REAL;         // <-- [DIAG] Ecart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive     : BOOL;         // <-- [DIAG] Seuil vitesse depasse sur cycle courant
    SpeedMismatchConfirmed  : BOOL;         // <-- [DIAG] Ecart vitesse confirme pendant timeout

    // === ORDRES ACTIONNEURS (COMMANDES STRUCTUREES) ===
    WinchM1Cmd              : ST_fbCycle_WinchCmdDemand;        // <-- [ACT] Demande treuil M1
    WinchM2Cmd              : ST_fbCycle_WinchCmdDemand;        // <-- [ACT] Demande treuil M2
    TranslationCmd          : ST_fbCycle_TranslationCmdDemand;  // <-- [ACT] Demande translation M3
    BucketCmd               : ST_fbCycle_BucketCmdDemand;       // <-- [ACT] Demande benne

    // === METADONNEES & SYNOPTIQUE ===
    CycleStep               : E_CycleStep;          // <-- [STAT] Etape active du Grafcet
    CycleStateStr           : STRING(80);           // <-- [STAT] Libelle en clair de l'etape
    CycleStepAtError        : E_CycleStep;          // <-- [DIAG] Etape specifique au moment du defaut
    OperatorActionId        : UINT;                 // <-- [DIAG] ID action operateur requise
    OperatorAction          : STRING(120);          // <-- [DIAG] Message explicatif pour l'IHM
    ExpectedAxis            : E_OperatorAxis;       // <-- [STAT] Organe joystick/bouton attendu
    ExpectedDirection       : INT;                  // <-- [STAT] Sens attendu (-1, 0, +1)
    WaitingForOperator      : BOOL;                 // <-- [STAT] En attente d'une action operateur
    WaitingForProcess       : BOOL;                 // <-- [STAT] En attente d'une condition procede
    RequestActive           : BOOL;                 // <-- [STAT] Demande de mouvement active
END_VAR
VAR_IN_OUT
    // === STRUCTURES PARTAGEES & COMPTEURS ===
    SampleCount             : INT;          // <-> [BUS] Compteur de prelevements (RETAIN)
END_VAR
VAR
    // === DETECTEURS DE FRONTS ===
    ResetEdge               : R_TRIG;       // . [LOC] Detecteur front montant Reset
    StartEdge               : R_TRIG;       // . [LOC] Detecteur front montant StartCycle
    DeadmanArmedEdge        : R_TRIG;       // . [LOC] Detecteur front montant DeadmanArmed (demarrage joystick)
    AbortEdge               : R_TRIG;       // . [LOC] Detecteur front montant AbortCycle
    ErrorEdge               : R_TRIG;       // . [LOC] Detecteur front montant Error
    EnableEdge              : R_TRIG;       // . [LOC] Detecteur front montant Enable (retour en semi-auto)

    // === ETATS INTERNES ===
    State                   : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape courante machine d'etat
    SavedState              : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape memorisee
    PausedState             : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape en pause lors de la bascule hors auto
    WaitingResume           : BOOL := FALSE;                             // . [LOC] En attente de validation consciente pour reprendre
    SampleCountDone         : BOOL := FALSE;                             // . [LOC] F6/F2: front de comptage SampleCount (1 seul increment par cycle)

    // === MEMORISATIONS & REGISTRES INTERNES ===
    TouchPositionM          : REAL;         // . [LOC] Position M1 memorisee lors du contact fond
    RaiseTargetM            : REAL;         // . [LOC] Profondeur de remontee memorisee
    SelectedWorkTarget      : INT;          // . [LOC] Cible de travail memorisee

    // === TEMPORISATEURS INTERNES ===
    DrainingTimer           : TON;          // . [LOC] Temporisateur de vidage (egouttage)
    StabilizationTimer      : TON;          // . [LOC] Temporisation maximale de remontee lente
    SpeedMismatchTimer      : TON;          // . [LOC] Confirmation temporelle ecart de vitesse
    StepMaxTimer            : TON;          // . [LOC] Tempo max d'etape

    // === CONSTANTES & CONFIGURATIONS INTERNES ===
    CtrlAscentDistM         : REAL := 2.0;      // . [LOC] Distance de remontee lente de controle
    CtrlAscentToleranceM    : REAL := 0.25;     // . [LOC] Ecart maximal admis entre codeurs
    CtrlAscentTimeout       : TIME := T#30s;    // . [LOC] Temps max pour zone de stabilisation
    DrainingTime            : TIME := T#5s;     // . [LOC] Temps d'egouttage par defaut
    StepMaxTimeout          : TIME := T#60s;    // . [LOC] Tempo max d'etape

    // === SOCLE DEFAUT TRANSVERSE ===
    instFault               : FB_FaultCore;                  // * [INST] Socle defaut transverse
    instCauses              : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes de defaut
END_VAR

// === IMPLEMENTATION ===


// 🔑 1. FRONTS ET CAUSES
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
DeadmanArmedEdge(CLK := DeadmanArmed);
AbortEdge(CLK := AbortCycle);
EnableEdge(CLK := Enable);

// ⏱️ Surveillance indépendante de la remontée lente
StabilizationTimer(IN := (State = E_CycleStep.X7_CTRL_ASCENT), PT := CtrlAscentTimeout);

// 📏 Comparaison vitesse réelle M1/M2
SpeedMismatchMps := ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps);
SpeedMismatchActive := (State = E_CycleStep.X7_CTRL_ASCENT)
                       AND CycleMotionPermit
                       AND (SpeedMismatchThresholdMps > 0.0)
                       AND (SpeedMismatchTimeout > T#0ms)
                       AND (SpeedMismatchMps > SpeedMismatchThresholdMps);
SpeedMismatchTimer(IN := SpeedMismatchActive, PT := SpeedMismatchTimeout);
SpeedMismatchConfirmed := SpeedMismatchTimer.Q;

// Tempo max d'étape (R5) — lancée SEULEMENT si pilotage joystick actif (pas de défaut au repos)
StepMaxTimer(IN := CycleMotionPermit AND (State <> E_CycleStep.X0_PREPARATION)
                  AND (State <> E_CycleStep.X13_DONE_SYNC)
                  AND (State <> E_CycleStep.STABILIZING),
             PT := StepMaxTimeout);

// Table des causes de défaut
instCauses[0].Active   := LimitLegalReached AND (State = E_CycleStep.X4_DESCEND_OPEN);
instCauses[0].Latching := TRUE;
instCauses[0].Texte    := 'Limite legale de profondeur atteinte pendant descente';

instCauses[1].Active   := WinchSyncError AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[1].Latching := TRUE;
instCauses[1].Texte    := 'Desynchronisme treuils M1/M2 bloquant';

instCauses[2].Active   := SpeedMismatchConfirmed AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[2].Latching := TRUE;
instCauses[2].Texte    := 'Ecart de vitesse M1/M2 confirme en montee';

instCauses[3].Active   := NOT HeartbeatIhmOk AND (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.STABILIZING);
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Perte communication IHM pendant cycle';

instCauses[4].Active   := StepMaxTimer.Q AND (State <> E_CycleStep.STABILIZING);
instCauses[4].Latching := TRUE;
instCauses[4].Texte    := 'Depassement tempo maximale d etape (blocage mouvement)';

instCauses[5].Active   := (StabilizationTimer.Q OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM))
                          AND (State = E_CycleStep.X7_CTRL_ASCENT);
instCauses[5].Latching := TRUE;
instCauses[5].Texte    := 'Defaut de stabilisation / tolerance ecart codeurs en remontee controle';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
ErrorEdge(CLK := Fault.Error);



// 🛑 2. GATES DE SÉCURITÉ ET NEUTRALISATION
IF NOT Enable OR NOT PowerContactorEngaged THEN
    WinchM1Cmd.StartStop   := FALSE;
    WinchM1Cmd.Direction   := 0;
    WinchM1Cmd.SpeedPct    := 0.0;

    WinchM2Cmd.StartStop   := FALSE;
    WinchM2Cmd.Direction   := 0;
    WinchM2Cmd.SpeedPct    := 0.0;

    TranslationCmd.Start   := FALSE;
    TranslationCmd.Target  := 0;

    BucketCmd.Open         := FALSE;
    BucketCmd.Close        := FALSE;
    BucketCmd.KoboldContactorCmd := FALSE;

    // Si on quitte le semi-auto alors qu'un cycle était en cours, on mémorise l'étape pour la pause
    IF (State <> E_CycleStep.X0_PREPARATION) AND (State <> E_CycleStep.X13_DONE_SYNC) AND (State <> E_CycleStep.STABILIZING) THEN
        PausedState := State;
        WaitingResume := TRUE;
    END_IF;

    CycleStep            := State;
    CycleStateStr        := 'Cycle desactive : securite absente ou mode hors semi-auto';
    Ready                := FALSE;
    Lifecycle.Busy       := FALSE;
    Lifecycle.Done       := FALSE;
    SpeedMismatchTimer(IN := FALSE, PT := SpeedMismatchTimeout);
    SpeedMismatchMps := 0.0;
    SpeedMismatchActive := FALSE;
    SpeedMismatchConfirmed := FALSE;
    OperatorActionId := 0;
    OperatorAction := 'Passer en mode Semi-Auto et engager la securite pour activer le cycle.';
    ExpectedAxis := E_OperatorAxis.NONE;
    ExpectedDirection := 0;
    WaitingForOperator := FALSE;
    WaitingForProcess := FALSE;
    RequestActive := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;

// Au retour en Semi-Auto (front montant Enable), si une étape était en cours, on exige une reprise consciente
// 🔒 F6 (correctif WORKING_COPY) : le gate réel est placé juste avant le CASE (après la gestion
// défaut/abort) pour ne pas court-circuiter la détection de défaut. Voir §3.

// 🧊 R9 — capture l'étape spécifique AVANT la bascule vers STABILIZING
IF ErrorEdge.Q THEN
    CycleStepAtError := State;
    State := E_CycleStep.STABILIZING;
END_IF;

IF ResetEdge.Q THEN
    SavedState := E_CycleStep.X0_PREPARATION;
    IF State = E_CycleStep.STABILIZING THEN
        State := E_CycleStep.X0_PREPARATION;
    END_IF;
END_IF;

// Gestion de l'Abandon explicite
IF AbortEdge.Q THEN
    State := E_CycleStep.X0_PREPARATION;
    WaitingResume := FALSE;
    PausedState := E_CycleStep.X0_PREPARATION;
END_IF;

// 🔒 F6 (correctif WORKING_COPY) : gate de reprise consciente — placé APRÈS la gestion
// défaut/abort pour ne pas court-circuiter la détection de défaut.
// Tant que WaitingResume est actif, toutes les demandes actionneurs sont neutralisées et
// l'étape est figée : aucun redémarrage automatique du mouvement au retour en semi-auto.
// La reprise n'est possible que par un front StartCycle (appui conscient).
IF WaitingResume THEN
    WinchM1Cmd.StartStop   := FALSE;
    WinchM1Cmd.Direction   := 0;
    WinchM1Cmd.SpeedPct    := 0.0;
    WinchM2Cmd.StartStop   := FALSE;
    WinchM2Cmd.Direction   := 0;
    WinchM2Cmd.SpeedPct    := 0.0;
    TranslationCmd.Start   := FALSE;
    TranslationCmd.Target  := 0;
    BucketCmd.Open         := FALSE;
    BucketCmd.Close        := FALSE;
    BucketCmd.KoboldContactorCmd := FALSE;
    CycleStep              := PausedState;
    CycleStateStr          := 'Cycle en pause : reprise consciente requise (StartCycle).';
    WaitingForOperator     := TRUE;
    WaitingForProcess      := FALSE;
    OperatorActionId       := 16#0400;
    OperatorAction         := 'Reprendre le cycle : appuyer sur StartCycle.';
    ExpectedAxis           := E_OperatorAxis.BUTTON;
    ExpectedDirection      := 0;
    RequestActive          := FALSE;
    // Reprise uniquement sur front StartCycle (appui conscient)
    IF StartEdge.Q THEN
        WaitingResume := FALSE;
    END_IF;
    RETURN;
END_IF;



// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état) — CASE sur enum unique (R1)
CASE State OF

    E_CycleStep.X0_PREPARATION:
        CycleStep := E_CycleStep.X0_PREPARATION;
        CycleStateStr := 'X0 - Verification coherence systeme';
        WinchM1Cmd.StartStop := FALSE; WinchM1Cmd.Direction := 0; WinchM1Cmd.SpeedPct := 0.0;
        WinchM2Cmd.StartStop := FALSE; WinchM2Cmd.Direction := 0; WinchM2Cmd.SpeedPct := 0.0;
        TranslationCmd.Start := FALSE; TranslationCmd.Target := 0;
        BucketCmd.Open := FALSE; BucketCmd.Close := FALSE; BucketCmd.KoboldContactorCmd := FALSE;
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0400;
        OperatorAction := 'Demander le demarrage du cycle (Bouton IHM ou armement Homme-Mort).';

        // Transition si système sain et réarmé (front reset ou démarrage).
        // 🔫 D2 : démarrage par bouton IHM (StartEdge) OU armement homme-mort joystick
        IF (StartEdge.Q OR DeadmanArmedEdge.Q) AND NOT Fault.Error THEN
            WaitingResume := FALSE;
            SampleCountDone := FALSE;   // 🔒 F2 : réarmement du front de comptage à chaque entrée en cycle
            State := E_CycleStep.X1_HOMING;
        END_IF;

    E_CycleStep.X1_HOMING:
        CycleStep := E_CycleStep.X1_HOMING;
        CycleStateStr := 'X1 - Referencement codeurs (vitesses lentes)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0401;
        OperatorAction := 'Maintenir la montee lente vers les capteurs de referencement.';

        // Vitesses lentes pour chercher capteur top + référencement
        IF NOT HomedM1 OR NOT HomedM2 THEN
            WinchM1Cmd.StartStop := CycleMotionPermit;
            WinchM1Cmd.Direction := 1;   // montée lente vers capteur top
            WinchM1Cmd.SpeedPct := 10.0;
            WinchM2Cmd.StartStop := CycleMotionPermit;
            WinchM2Cmd.Direction := 1;
            WinchM2Cmd.SpeedPct := 10.0;
            IF HomingRequest THEN
                State := E_CycleStep.X2_WORK_POS_SELECT;
            END_IF;
        ELSE
            // déjà homé → passe vite
            State := E_CycleStep.X2_WORK_POS_SELECT;
        END_IF;

    E_CycleStep.X2_WORK_POS_SELECT:
        CycleStep := E_CycleStep.X2_WORK_POS_SELECT;
        CycleStateStr := 'X2 - Selection position travail';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        ExpectedDirection := 0;
        WaitingForOperator := (SelTarget = 0) OR NOT CycleMotionPermit;
        WaitingForProcess := (SelTarget <> 0) AND CycleMotionPermit;
        OperatorActionId := 16#0402;
        OperatorAction := 'Selectionner la cible et maintenir la translation vers la position de travail.';

        IF (SelTarget = 1) OR (SelTarget = 3) OR (SelTarget = 4) THEN
            SelectedWorkTarget := SelTarget;
            TranslationCmd.Target := SelTarget;
            TranslationCmd.Start := CycleMotionPermit;
            // Arrivée à la cible (Trémie/P1/Maintenance)
            IF CycleMotionPermit AND (
                (SelTarget = 1 AND Translation_At_Tremie) OR
                (SelTarget = 3 AND Translation_At_P1) OR
                (SelTarget = 4 AND Translation_At_Maintenance)) THEN
                TranslationCmd.Start := FALSE;
                State := E_CycleStep.X3_OPEN_BUCKET;
            END_IF;
        END_IF;

    E_CycleStep.X3_OPEN_BUCKET:
        CycleStep := E_CycleStep.X3_OPEN_BUCKET;
        CycleStateStr := 'X3 - Ouverture benne';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 0;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0403;
        OperatorAction := 'Maintenir le joystick : ouverture complete de la benne.';

        IF Benne_IsOpen THEN
            State := E_CycleStep.X4_DESCEND_OPEN;
        ELSE
            BucketCmd.Open := CycleMotionPermit;
            IF CycleMotionPermit AND Benne_Done AND Benne_IsOpen THEN
                BucketCmd.Open := FALSE;
                State := E_CycleStep.X4_DESCEND_OPEN;
            END_IF;
        END_IF;

    E_CycleStep.X4_DESCEND_OPEN:
        CycleStep := E_CycleStep.X4_DESCEND_OPEN;
        CycleStateStr := 'X4 - Plongee benne ouverte (synchro)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0404;
        OperatorAction := 'Maintenir la descente : plongee synchro et detection fond Kobold.';

        // M1 et M2 descendent ensemble (synchro gérée en aval)
        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := -1;
        WinchM1Cmd.SpeedPct  := 50.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := -1;
        WinchM2Cmd.SpeedPct  := 50.0;
        BucketCmd.KoboldContactorCmd := TRUE;

        // Transition uniquement sur le retour dédié Kobold.
        IF CycleMotionPermit AND KoboldContactFond THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            BucketCmd.KoboldContactorCmd := FALSE;
            TouchPositionM := M1_CablePosM;
            IF LimitLegalDepthM < -0.01 THEN
                RaiseTargetM := MAX(TouchPositionM + 0.5, LimitLegalDepthM + 0.5);
            ELSE
                RaiseTargetM := TouchPositionM + 0.5;
            END_IF;
            State := E_CycleStep.X5_BOTTOM_CONFIRMED;
        END_IF;

    E_CycleStep.X5_BOTTOM_CONFIRMED:
        CycleStep := E_CycleStep.X5_BOTTOM_CONFIRMED;
        CycleStateStr := 'X5 - Fond confirme : remontee securisee';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0405;
        OperatorAction := 'Fond confirme : maintenir la montee jusqu a la hauteur de fermeture.';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct := 20.0;

        IF CycleMotionPermit AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.X6_CLOSE_BUCKET;
        END_IF;

    E_CycleStep.X6_CLOSE_BUCKET:
        CycleStep := E_CycleStep.X6_CLOSE_BUCKET;
        CycleStateStr := 'X6 - Fermeture benne (tolerance a peu pres ferme)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0406;
        OperatorAction := 'Maintenir la commande : fermeture de la benne.';

        WinchM1Cmd.StartStop := FALSE;
        BucketCmd.Close := TRUE;

        IF CycleMotionPermit AND (Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)) THEN
            BucketCmd.Close := FALSE;
            State := E_CycleStep.X7_CTRL_ASCENT;
        END_IF;

    E_CycleStep.X7_CTRL_ASCENT:
        CycleStep := E_CycleStep.X7_CTRL_ASCENT;
        CycleStateStr := 'X7 - Remontee lente de controle';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0407;
        OperatorAction := 'Maintenir la montee lente : palier de controle et synchronisme.';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 20.0;

        IF CycleMotionPermit
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_CycleStep.X8_ASCENT_LOADED;
        END_IF;

    E_CycleStep.X8_ASCENT_LOADED:
        CycleStep := E_CycleStep.X8_ASCENT_LOADED;
        CycleStateStr := 'X8 - Remontee en charge';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := 1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#0408;
        OperatorAction := 'Maintenir la montee en charge jusqu a la limite haute.';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 70.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 70.0;

        IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.X9_DRAIN_PAUSE;
        END_IF;

    E_CycleStep.X9_DRAIN_PAUSE:
        CycleStep := E_CycleStep.X9_DRAIN_PAUSE;
        CycleStateStr := 'X9 - Egouttage du godet en cours';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.NONE;
        ExpectedDirection := 0;
        WaitingForOperator := FALSE;
        WaitingForProcess := TRUE;
        OperatorActionId := 16#0409;
        OperatorAction := 'Egouttage du godet en cours (temporisation).';
        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;

        DrainingTimer(IN := TRUE, PT := DrainingTime);
        IF CycleMotionPermit AND DrainingTimer.Q THEN
            DrainingTimer(IN := FALSE);
            State := E_CycleStep.X10_TRANSLATE_DUMP;
        END_IF;

    E_CycleStep.X10_TRANSLATE_DUMP:
        CycleStep := E_CycleStep.X10_TRANSLATE_DUMP;
        CycleStateStr := 'X10 - Deplacement vers tremie (grille/crible libres)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_X;
        ExpectedDirection := -1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#040A;
        OperatorAction := 'Maintenir la translation vers la tremie de dechargement.';

        TranslationCmd.Target := 1; // Trémie
        TranslationCmd.Start := CycleMotionPermit;

        IF CycleMotionPermit AND Translation_At_Tremie THEN
            TranslationCmd.Start := FALSE;
            State := E_CycleStep.X11_OPEN_DUMP;
        END_IF;

    E_CycleStep.X11_OPEN_DUMP:
        CycleStep := E_CycleStep.X11_OPEN_DUMP;
        CycleStateStr := 'X11 - Vidange / ouverture du godet (montee possible, descente ouvre)';
        Lifecycle.Busy := TRUE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.JOYSTICK_Y;
        ExpectedDirection := -1;
        WaitingForOperator := NOT CycleMotionPermit;
        WaitingForProcess := CycleMotionPermit;
        OperatorActionId := 16#040B;
        OperatorAction := 'Deflechir vers le bas pour ouvrir la benne et vider la charge.';

        // 🔒 F1 (correctif WORKING_COPY) : suppression du read-before-write.
        // L'original évaluait BucketCmd.Open avec (WinchM1Cmd.Direction = -1) APRÈS avoir forcé
        // Direction := 1 → ouverture jamais commandée. Ici, l'ouverture est commandée quand le
        // manche est défléchi (pattern cohérent avec X3), et la sortie se fait sur Benne_Done
        // AND Benne_IsOpen. (La sémantique "descente ouvre" nécessiterait une entrée joystick,
        // absente de l'interface — remontée à l'orchestrateur.)
        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 20.0;

        BucketCmd.Open := CycleMotionPermit;

        IF CycleMotionPermit AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.Open := FALSE;
            State := E_CycleStep.X13_DONE_SYNC;
        END_IF;

    E_CycleStep.X13_DONE_SYNC:
        CycleStep := E_CycleStep.X13_DONE_SYNC;
        CycleStateStr := 'X13 - Cycle automatique complete - pret';
        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;
        TranslationCmd.Start := FALSE;
        Lifecycle.Done := TRUE;
        Lifecycle.Busy := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#040D;
        OperatorAction := 'Cycle termine avec succes. Relancer un nouveau cycle.';

        // Compteur de prélèvements (RETAIN)
        // 🔒 F2 (correctif WORKING_COPY) : incrément cadré par front (1 seul par cycle).
        // L'original incrémentait à CHAQUE scan passé en X13 → compteur falsifié.
        IF NOT SampleCountDone THEN
            SampleCount := SampleCount + 1;
            SampleCountDone := TRUE;
        END_IF;

        IF StartEdge.Q THEN
            SampleCountDone := FALSE;
            Lifecycle.Done := FALSE;
            State := E_CycleStep.X0_PREPARATION;
        END_IF;

    E_CycleStep.STABILIZING:
        CycleStep := E_CycleStep.STABILIZING;
        CycleStateStr := 'X14 - Cycle en attente / stabilisation (STAB)';
        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;
        TranslationCmd.Start := FALSE;
        BucketCmd.Open := FALSE;
        BucketCmd.Close := FALSE;
        Lifecycle.Busy := FALSE;
        Lifecycle.Done := FALSE;
        ExpectedAxis := E_OperatorAxis.BUTTON;
        ExpectedDirection := 0;
        WaitingForOperator := TRUE;
        WaitingForProcess := FALSE;
        OperatorActionId := 16#0480;
        OperatorAction := 'Cycle stabilise sur anomalie : acquitter le defaut pour reinitialiser.';

END_CASE;



// 🛑 Relâchement du manche (retour au centre) : neutralisation des demandes actives
IF Lifecycle.Busy AND NOT CycleMotionPermit THEN
    WinchM1Cmd.StartStop := FALSE;
    WinchM2Cmd.StartStop := FALSE;
    TranslationCmd.Start := FALSE;
    BucketCmd.Open := FALSE;
    BucketCmd.Close := FALSE;
    BucketCmd.KoboldContactorCmd := FALSE;
END_IF;

RequestActive := WinchM1Cmd.StartStop OR WinchM2Cmd.StartStop OR TranslationCmd.Start OR BucketCmd.Open OR BucketCmd.Close;


END_FUNCTION_BLOCK
