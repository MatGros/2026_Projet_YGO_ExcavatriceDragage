(* =======================================================================
   ⚙️ FB_Cycle — Séquenceur du cycle automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Automate de cycle automatique de dragage (X0 à X13 + STABILIZING)
   🔒 Sécurité : Gating par mode et homme-mort, repli STABILIZING sur défaut
   🔌 Interface : Demandes de mouvements (treuils, translation, benne)
   📄 Doc métier : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.1.md
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Cycle
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
    Busy                    : BOOL;         // <-- [STAT] Cycle automatique actif
    Done                    : BOOL;         // <-- [STAT] Cycle automatique complete
    Error                   : BOOL;         // <-- [STAT] Defaut cycle
    ErrorId                 : WORD;         // <-- [DIAG] Code erreur bitmask
    SpeedMismatchMps        : REAL;         // <-- [DIAG] Ecart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive     : BOOL;         // <-- [DIAG] Seuil vitesse depasse sur cycle courant
    SpeedMismatchConfirmed  : BOOL;         // <-- [DIAG] Ecart vitesse confirme pendant timeout

    // === ORDRES ACTIONNEURS (COMMANDES STRUCTUREES) ===
    WinchM1Cmd              : ST_WinchCmdDemand;        // <-- [ACT] Demande treuil M1
    WinchM2Cmd              : ST_WinchCmdDemand;        // <-- [ACT] Demande treuil M2
    TranslationCmd          : ST_TranslationCmdDemand;  // <-- [ACT] Demande translation M3
    BucketCmd               : ST_BucketCmdDemand;       // <-- [ACT] Demande benne

    // === METADONNEES & SYNOPTIQUE ===
    CycleStep               : E_CycleStep;  // <-- [STAT] Etape active du Grafcet
    CycleStateStr           : STRING(80);   // <-- [STAT] Libelle en clair de l'etape
    CycleStepAtError        : E_CycleStep;  // <-- [DIAG] Etape specifique au moment du defaut
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

    // === ETATS INTERNES ===
    State                   : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape courante machine d'etat
    SavedState              : E_CycleStep := E_CycleStep.X0_PREPARATION; // . [LOC] Etape memorisee

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
END_VAR

// === IMPLEMENTATION ===

{region "§1 Gate securite"}
// 🛑 1. GATES DE SÉCURITÉ ET BLOCAGE (R8)
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

    State                := E_CycleStep.X0_PREPARATION;   // retour à la PREMIÈRE étape (R8)
    CycleStep            := E_CycleStep.X0_PREPARATION;
    CycleStateStr        := 'X0 - Désactivé : sécurité absente ou auto désactivé';
    Ready                := FALSE;
    Busy                 := FALSE;
    Done                 := FALSE;
    RETURN;
END_IF;
{endregion}

{region "§2 Preparation surveillance et commandes cycle"}
Ready := TRUE;
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
DeadmanArmedEdge(CLK := DeadmanArmed);
AbortEdge(CLK := AbortCycle);
ErrorEdge(CLK := Error);

// 🧊 R9 — capture l'étape spécifique AVANT la bascule vers STABILIZING
IF ErrorEdge.Q THEN
    CycleStepAtError := State;
END_IF;

// ⏱️ T36 — surveillance indépendante de la remontée lente
StabilizationTimer(IN := (State = E_CycleStep.X7_CTRL_ASCENT), PT := CtrlAscentTimeout);

// 📏 T43 — comparaison vitesse réelle M1/M2
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

IF ResetEdge.Q THEN
    Error := FALSE;
    ErrorId := 16#0000;
    SavedState := E_CycleStep.X0_PREPARATION;
    IF State = E_CycleStep.STABILIZING THEN
        State := E_CycleStep.X0_PREPARATION;
    END_IF;
END_IF;

// 💓 Perte IHM : repli mémorisé. La reconnexion seule ne relance jamais le cycle.
IF NOT HeartbeatIhmOk AND State <> E_CycleStep.STABILIZING THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0020;
    State := E_CycleStep.STABILIZING;
END_IF;

// Défaut de synchronisme : arrêt sûr et acquittement obligatoire.
IF WinchSyncError AND State <> E_CycleStep.STABILIZING THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0002;
    State := E_CycleStep.STABILIZING;
END_IF;

// 🛡️ T43 — écart de vitesse confirmé : arrêt du cycle et STABILIZING.
IF SpeedMismatchConfirmed AND State <> E_CycleStep.STABILIZING THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0010;
    State := E_CycleStep.STABILIZING;
END_IF;

// Tempo max d'étape dépassée (blocage probable) → défaut
IF StepMaxTimer.Q AND State <> E_CycleStep.STABILIZING THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0040;
    State := E_CycleStep.STABILIZING;
END_IF;

// Gestion de l'Abandon (D3 — pas de Pause)
IF AbortEdge.Q THEN
    State := E_CycleStep.X0_PREPARATION;
END_IF;
{endregion}

{region "§3 Machine etat cycle automatique"}
// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état) — CASE sur enum unique (R1)
CASE State OF

    E_CycleStep.X0_PREPARATION:
        CycleStep := E_CycleStep.X0_PREPARATION;
        CycleStateStr := 'X0 - Vérification cohérence système';
        WinchM1Cmd.StartStop := FALSE; WinchM1Cmd.Direction := 0; WinchM1Cmd.SpeedPct := 0.0;
        WinchM2Cmd.StartStop := FALSE; WinchM2Cmd.Direction := 0; WinchM2Cmd.SpeedPct := 0.0;
        TranslationCmd.Start := FALSE; TranslationCmd.Target := 0;
        BucketCmd.Open := FALSE; BucketCmd.Close := FALSE; BucketCmd.KoboldContactorCmd := FALSE;
        Busy := FALSE; Done := FALSE;

        // Transition si système sain et réarmé (front reset ou démarrage).
        // 🔫 D2 : démarrage par bouton IHM (StartEdge) OU armement homme-mort joystick
        // (DeadmanArmedEdge) — l'opérateur peut lancer depuis l'IHM ou le joystick.
        // La continuité des mouvements ne dépend que de CycleMotionPermit (manche défléchi).
        IF StartEdge.Q OR DeadmanArmedEdge.Q THEN
            State := E_CycleStep.X1_HOMING;
        END_IF;

    E_CycleStep.X1_HOMING:
        CycleStep := E_CycleStep.X1_HOMING;
        CycleStateStr := 'X1 - Référencement codeurs (vitesses lentes)';
        Busy := TRUE;

        // Vitesses lentes pour chercher capteur top + référencement
        IF NOT HomedM1 OR NOT HomedM2 THEN
            WinchM1Cmd.StartStop := CycleMotionPermit;
            WinchM1Cmd.Direction := 1;   // montée lente vers capteur top
            WinchM1Cmd.SpeedPct := 10.0;
            WinchM2Cmd.StartStop := CycleMotionPermit;
            WinchM2Cmd.Direction := 1;
            WinchM2Cmd.SpeedPct := 10.0;
            IF HomingRequest THEN
                // déclenche le référencement (via FB_Encoder_Homing en aval)
                State := E_CycleStep.X2_WORK_POS_SELECT;
            END_IF;
        ELSE
            // déjà homé → passe vite
            State := E_CycleStep.X2_WORK_POS_SELECT;
        END_IF;

    E_CycleStep.X2_WORK_POS_SELECT:
        CycleStep := E_CycleStep.X2_WORK_POS_SELECT;
        CycleStateStr := 'X2 - Sélection position travail';
        Busy := TRUE;

        // Destinations sélectionnables : Trémie(1), P1(3), Maintenance(4).
        // P2(2) n'est PAS une destination — capteur de passage en petite vitesse (PV).
        // Si aucune cible valide n'est sélectionnée, on ATTEND à X2 (pas de défaut) :
        // l'opérateur choisit la position de travail via l'IHM (SelTarget).
        IF (SelTarget = 1) OR (SelTarget = 3) OR (SelTarget = 4) THEN
            SelectedWorkTarget := SelTarget;
            TranslationCmd.Target := SelTarget;
            TranslationCmd.Start := CycleMotionPermit;
            // Arrivée à la cible (Trémie/P1/Maintenance) — capteurs PV/PVP2/P2 = ralentissement
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
        Busy := TRUE;

        // Ouverture benne ; si déjà ouverte → passe vite
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
        CycleStateStr := 'X4 - Plongée benne ouverte (synchro)';

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
        ELSIF LimitLegalReached THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0001;
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            BucketCmd.KoboldContactorCmd := FALSE;
            State := E_CycleStep.STABILIZING;
        END_IF;

    E_CycleStep.X5_BOTTOM_CONFIRMED:
        CycleStep := E_CycleStep.X5_BOTTOM_CONFIRMED;
        CycleStateStr := 'X5 - Fond confirmé : remontée sécurisée';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct := 20.0;

        // Les deux treuils restent synchronisés jusqu'au-dessus de la limite légale.
        IF CycleMotionPermit AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.X6_CLOSE_BUCKET;
        END_IF;

    E_CycleStep.X6_CLOSE_BUCKET:
        CycleStep := E_CycleStep.X6_CLOSE_BUCKET;
        CycleStateStr := 'X6 - Fermeture benne (tolérance à peu près fermé)';

        WinchM1Cmd.StartStop := FALSE;
        BucketCmd.Close := TRUE;

        // Tolérance : si benne « à peu près fermée » (matière/objet), on remonte et on contrôle
        IF CycleMotionPermit AND (Benne_Done AND (Benne_IsClosed OR Benne_IsRoughlyClosed)) THEN
            BucketCmd.Close := FALSE;
            State := E_CycleStep.X7_CTRL_ASCENT;
        END_IF;

    E_CycleStep.X7_CTRL_ASCENT:
        CycleStep := E_CycleStep.X7_CTRL_ASCENT;
        CycleStateStr := 'X7 - Remontée lente de contrôle';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 20.0;

        // Contrôle des deux codeurs
        IF WinchSyncError OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM) THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008;
            State := E_CycleStep.STABILIZING;
        ELSIF CycleMotionPermit
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_CycleStep.X8_ASCENT_LOADED;
        ELSIF StabilizationTimer.Q THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008;
            State := E_CycleStep.STABILIZING;
        END_IF;

    E_CycleStep.X8_ASCENT_LOADED:
        CycleStep := E_CycleStep.X8_ASCENT_LOADED;
        CycleStateStr := 'X8 - Remontée en charge';

        WinchM1Cmd.StartStop := CycleMotionPermit;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 70.0;
        WinchM2Cmd.StartStop := CycleMotionPermit;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 70.0;

        // Transition alignée sur la limite haute d'exploitation
        IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.X9_DRAIN_PAUSE;
        END_IF;

    E_CycleStep.X9_DRAIN_PAUSE:
        CycleStep := E_CycleStep.X9_DRAIN_PAUSE;
        CycleStateStr := 'X9 - Égouttage du godet en cours';
        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;

        DrainingTimer(IN := TRUE, PT := DrainingTime);
        // Temps écoulé affiché IHM (CycleStateStr + champ dédié)
        IF CycleMotionPermit AND DrainingTimer.Q THEN
            DrainingTimer(IN := FALSE);
            State := E_CycleStep.X10_TRANSLATE_DUMP;
        END_IF;

    E_CycleStep.X10_TRANSLATE_DUMP:
        CycleStep := E_CycleStep.X10_TRANSLATE_DUMP;
        CycleStateStr := 'X10 - Déplacement vers trémie (grille/crible libres)';

        TranslationCmd.Target := 1; // Trémie
        TranslationCmd.Start := CycleMotionPermit;

        // Avertissement IHM : grille abaissée/libre, crible libre pour réceptionner la charge
        // (porté par CycleStateStr + OperatorAction côté supervision)

        // Transition si translation arrivé à la trémie
        IF CycleMotionPermit AND Translation_At_Tremie THEN
            TranslationCmd.Start := FALSE;
            State := E_CycleStep.X11_OPEN_DUMP;
        END_IF;

    E_CycleStep.X11_OPEN_DUMP:
        CycleStep := E_CycleStep.X11_OPEN_DUMP;
        CycleStateStr := 'X11 - Vidange / ouverture du godet (montée possible, descente ouvre)';

        // Montée possible (treuils vers le haut) ; descente fait ouvrir la benne.
        // Montée : on laisse l'opérateur remonter les 2 treuils en synchro si besoin.
        WinchM1Cmd.StartStop := CycleMotionPermit AND (WinchM1Cmd.Direction = 1);
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 20.0;
        WinchM2Cmd.StartStop := CycleMotionPermit AND (WinchM2Cmd.Direction = 1);
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 20.0;

        // Descente → ouverture benne (vidage)
        BucketCmd.Open := CycleMotionPermit AND (WinchM1Cmd.Direction = -1);

        // Contrôle convoyeurs par MESSAGE utilisateur (pas encore câblé) :
        // CycleStateStr + OperatorAction côté supervision demandent de vérifier
        // que les convoyeurs sont en route avant/au lâcher.
        IF CycleMotionPermit AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.Open := FALSE;
            State := E_CycleStep.X13_DONE_SYNC;
        END_IF;

    E_CycleStep.X13_DONE_SYNC:
        CycleStep := E_CycleStep.X13_DONE_SYNC;
        CycleStateStr := 'X13 - Cycle automatique complété - prêt';
        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;
        TranslationCmd.Start := FALSE;
        Done := TRUE;
        Busy := FALSE;

        // Compteur de prélèvements (RETAIN, Q3bis) — compte inconditionnellement
        SampleCount := SampleCount + 1;

        // Rebouclage sur X0_PREPARATION (trémie, treuils hauts) — pas de retour P1
        IF StartEdge.Q THEN
            Done := FALSE;
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

END_CASE;
{endregion}

{region "§4 Repli homme mort"}
// 🛑 Relâchement du manche (retour au centre) : aucune demande d'actionneur ne reste active.
// L'étape est mémorisée et reprend au prochain appui valide (D2).
IF Busy AND NOT CycleMotionPermit THEN
    WinchM1Cmd.StartStop := FALSE;
    WinchM2Cmd.StartStop := FALSE;
    TranslationCmd.Start := FALSE;
    BucketCmd.Open := FALSE;
    BucketCmd.Close := FALSE;
    BucketCmd.KoboldContactorCmd := FALSE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
