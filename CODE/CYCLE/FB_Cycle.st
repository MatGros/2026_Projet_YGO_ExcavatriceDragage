(* ═══════════════════════════════════════════════════════════════
   🔄 FB_Cycle — Séquenceur du Cycle Automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF/AF_Partie-04_Mode_SemiAuto_Sequenceur_v2.0.md
   🔌 Conforme au contrat FB standard (Partie3 §1bis).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_Cycle
VAR_INPUT
    Enable                  : BOOL;         // Activation générale du séquenceur
    Reset                   : BOOL;         // Acquittement défaut (front)
    PowerContactorEngaged   : BOOL;         // Chaîne de sécurité OK
    CycleMotionPermit       : BOOL;         // Homme-mort + joystick actif
    HeartbeatIhmOk          : BOOL;         // 💓 IHM↔PLC valide ; FALSE = repli cycle obligatoire

    // Commandes opérateur
    StartCycle              : BOOL;         // Demande lancement / reprise cycle (IHM)
    PauseCycle              : BOOL;         // Demande pause temporaire (IHM)
    AbortCycle              : BOOL;         // Demande abandon cycle (IHM)

    // Cibles et paramètres
    SetDepthM               : REAL;         // Profondeur de consigne (négative)
    SetOffsetM              : REAL;         // Écart de fermeture benne cible
    SelectedTargetNum_IHM   : INT;          // Cible sélectionnée (2=P2, 3=P1)

    // Feedbacks physique & matériel
    KoboldContactFond       : BOOL;         // Retour dédié Kobold : TRUE = contact fond détecté
    LimitLegalReached       : BOOL;         // Limite légale atteinte (descente interdite)
    LimitLegalDepthM        : REAL;         // Profondeur légale minimale autorisée
    WinchSyncError          : BOOL;         // Désynchronisme bloquant M1/M2
    WinchSyncDeltaM         : REAL;         // Écart codeurs M1/M2 pour diagnostic
    M1_CablePosM            : REAL;         // Position câble treuil M1 (recalée)
    M2_CablePosM            : REAL;         // Position câble treuil M2 (recalée)
    M1_MeasuredSpeedMps     : REAL;         // Vitesse linéaire mesurée M1 (m/s)
    M2_MeasuredSpeedMps     : REAL;         // Vitesse linéaire mesurée M2 (m/s)
    SpeedMismatchThresholdMps : REAL;       // Seuil écart vitesse ; 0 = contrôle désactivé
    SpeedMismatchTimeout    : TIME;         // Durée de confirmation ; 0 = contrôle désactivé
    CableLimitM1AscentM     : REAL;         // Limite haute d'exploitation M1 ; seuil de fin ASCENDING_LOADED

    // Feedbacks Translation M3
    Translation_At_P1           : BOOL;     // Capteur position P1 (ex-Fosse1)
    Translation_At_P2           : BOOL;     // Capteur position P2 (ex-Fosse2)
    Translation_At_Maintenance  : BOOL;     // Capteur fin de course maintenance
    Translation_At_Tremie       : BOOL;     // Capteur fin de course trémie
    Translation_Busy            : BOOL;     // Mouvement translation en cours
    Translation_Done            : BOOL;     // Cible translation atteinte

    // Feedbacks Benne
    Benne_Busy              : BOOL;         // Mouvement mâchoires benne en cours
    Benne_Done              : BOOL;         // Mouvement ouverture/fermeture terminé
    Benne_IsOpen            : BOOL;         // Benne mécaniquement ouvert mémorisé
    Benne_IsClosed          : BOOL;         // Benne mécaniquement fermé mémorisé
END_VAR
VAR_OUTPUT
    Ready                   : BOOL;         // Séquenceur disponible
    Busy                    : BOOL;         // Cycle automatique actif
    Done                    : BOOL;         // Cycle automatique complété
    Error                   : BOOL;         // Défaut cycle
    ErrorId                 : WORD;         // bit0: Timeout/limite, bit1: désynchronisme, bit2: cible invalide, bit3: stabilisation impossible, bit4: écart vitesse, bit5: perte heartbeat
    SpeedMismatchMps        : REAL;         // Écart absolu vitesse M1/M2 (m/s)
    SpeedMismatchActive     : BOOL;         // Seuil vitesse dépassé sur le cycle courant
    SpeedMismatchConfirmed  : BOOL;         // Écart vitesse confirmé pendant SpeedMismatchTimeout

    // Commandes structurées (demandes de mouvement)
    WinchM1Cmd              : ST_WinchCmdDemand;        // Demande treuil M1
    WinchM2Cmd              : ST_WinchCmdDemand;        // Demande treuil M2
    TranslationCmd          : ST_TranslationCmdDemand;  // Demande translation M3
    BucketCmd               : ST_BucketCmdDemand;       // Demande benne

    // Métadonnées d'affichage IHM
    CycleStep               : E_CycleStep;  // Étape active du Grafcet
    CycleStateStr           : STRING(80);   // Libellé en clair de l'étape
END_VAR
VAR
    ResetEdge               : R_TRIG;
    StartEdge               : R_TRIG;
    PauseEdge               : R_TRIG;
    AbortEdge               : R_TRIG;

    // Séquencement
    State                   : E_CycleStep := E_CycleStep.INIT;
    SavedState              : E_CycleStep := E_CycleStep.INIT;
    IsPaused                : BOOL := FALSE;

    // Mémorisations et Timers
    TouchPositionM          : REAL;         // Position M1 mémorisée lors du contact fond
    RaiseTargetM            : REAL;         // Profondeur de remontée mémorisée
    DrainingTimer           : TON;          // Temporisateur de vidage (égouttage)
    StabilizationTimer      : TON;          // Temporisation maximale de remontée lente après fermeture
    SpeedMismatchTimer      : TON;          // Confirmation temporelle écart de vitesse M1/M2
    SelectedWorkTarget      : INT;          // Cible de travail mémorisée (2=P2 ou 3=P1)

    // Paramètres internes
    CtrlAscentDistM         : REAL := 2.0;      // Distance de remontée lente de contrôle
    CtrlAscentToleranceM    : REAL := 0.25;     // Écart maximal admis entre les deux codeurs
    CtrlAscentTimeout       : TIME := T#30s;    // Temps maximal pour atteindre la zone de stabilisation
    DrainingTime            : TIME := T#5s;     // Temps d'égouttage par défaut
END_VAR

// === IMPLEMENTATION ===

{region "Gate securite"}
// 🛑 1. GATES DE SÉCURITÉ ET BLOCAGE
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

    State                := E_CycleStep.INIT;
    CycleStep            := E_CycleStep.INIT;
    CycleStateStr        := 'ARRÊT : SÉCURITÉ ABSENTE OU AUTO DÉSACTIVÉ';
    Ready                := FALSE;
    Busy                 := FALSE;
    Done                 := FALSE;
    RETURN;
END_IF;

{endregion}

{region "Preparation surveillance et commandes cycle"}
Ready := TRUE;
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
PauseEdge(CLK := PauseCycle);
AbortEdge(CLK := AbortCycle);

// ⏱️ T36 — surveillance indépendante de la remontée lente : un codeur bloqué
// ne doit jamais laisser le cycle attendre indéfiniment.
StabilizationTimer(IN := (State = E_CycleStep.CTRL_ASCENDING), PT := CtrlAscentTimeout);

// 📏 T43 — comparaison vitesse réelle M1/M2.
SpeedMismatchMps := ABS(M1_MeasuredSpeedMps - M2_MeasuredSpeedMps);
SpeedMismatchActive := (State = E_CycleStep.CTRL_ASCENDING)
                       AND CycleMotionPermit
                       AND (SpeedMismatchThresholdMps > 0.0)
                       AND (SpeedMismatchTimeout > T#0ms)
                       AND (SpeedMismatchMps > SpeedMismatchThresholdMps);
SpeedMismatchTimer(IN := SpeedMismatchActive, PT := SpeedMismatchTimeout);
SpeedMismatchConfirmed := SpeedMismatchTimer.Q;

IF ResetEdge.Q THEN
    Error := FALSE;
    ErrorId := 16#0000;
    IsPaused := FALSE;
    SavedState := E_CycleStep.INIT;
    IF State = E_CycleStep.ERROR_HOLD THEN
        State := E_CycleStep.INIT;
    END_IF;
END_IF;

// 💓 Perte IHM : repli mémorisé. La reconnexion seule ne relance jamais le cycle.
IF NOT HeartbeatIhmOk AND State <> E_CycleStep.ERROR_HOLD THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0020;
    State := E_CycleStep.ERROR_HOLD;
END_IF;

// Défaut de synchronisme : arrêt sûr et acquittement obligatoire.
IF WinchSyncError AND State <> E_CycleStep.ERROR_HOLD THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0002;
    State := E_CycleStep.ERROR_HOLD;
END_IF;

// 🛡️ T43 — écart de vitesse confirmé : arrêt du cycle et ERROR_HOLD.
IF SpeedMismatchConfirmed AND State <> E_CycleStep.ERROR_HOLD THEN
    Error := TRUE;
    ErrorId := ErrorId OR 16#0010;
    State := E_CycleStep.ERROR_HOLD;
END_IF;

// Gestion de la Pause
IF PauseEdge.Q AND Busy AND NOT IsPaused THEN
    IsPaused := TRUE;
    SavedState := State;
    State := E_CycleStep.ERROR_HOLD; // Fige les mouvements
ELSIF StartEdge.Q AND IsPaused THEN
    IsPaused := FALSE;
    State := SavedState; // Reprise à l'étape sauvegardée
END_IF;

// Gestion de l'Abandon
IF AbortEdge.Q THEN
    IsPaused := FALSE;
    State := E_CycleStep.INIT;
END_IF;

{endregion}

{region "Machine etat cycle automatique"}
// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état)
CASE State OF

    E_CycleStep.INIT:
        CycleStep := E_CycleStep.INIT;
        CycleStateStr := 'VÉRIFICATION COHÉRENCE SYSTÈME';

        WinchM1Cmd.StartStop := FALSE;
        WinchM1Cmd.Direction := 0;
        WinchM1Cmd.SpeedPct  := 0.0;

        WinchM2Cmd.StartStop := FALSE;
        WinchM2Cmd.Direction := 0;
        WinchM2Cmd.SpeedPct  := 0.0;

        TranslationCmd.Start := FALSE;
        TranslationCmd.Target := 0;

        BucketCmd.Open  := FALSE;
        BucketCmd.Close := FALSE;
        BucketCmd.KoboldContactorCmd := FALSE;

        Busy  := FALSE;
        Done  := FALSE;

        // Transition si système sain et réarmé (front reset ou démarrage)
        IF StartEdge.Q THEN
            State := E_CycleStep.WORK_POS_SELECT;
        END_IF;

    E_CycleStep.WORK_POS_SELECT:
        CycleStep := E_CycleStep.WORK_POS_SELECT;
        CycleStateStr := 'SÉLECTION POSITION TRAVAIL (FOSSE 1 / 2)';
        Busy := TRUE;

        // Choix cible — P2/P1 (cibles 2/3)
        IF (SelectedTargetNum_IHM <> 2) AND (SelectedTargetNum_IHM <> 3) THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0004;
            State := E_CycleStep.ERROR_HOLD;
        ELSIF SelectedTargetNum_IHM = 2 OR SelectedTargetNum_IHM = 3 THEN
            SelectedWorkTarget := SelectedTargetNum_IHM;
            TranslationCmd.Target := SelectedWorkTarget;
            TranslationCmd.Start := CycleMotionPermit;

            // Attente positionnement translation
            IF CycleMotionPermit AND ((SelectedWorkTarget = 2 AND Translation_At_P2)
               OR (SelectedWorkTarget = 3 AND Translation_At_P1)) THEN
                TranslationCmd.Start := FALSE;
                State := E_CycleStep.DESCENDING_OPEN;
            END_IF;
        END_IF;

    E_CycleStep.DESCENDING_OPEN:
        CycleStep := E_CycleStep.DESCENDING_OPEN;
        CycleStateStr := 'PLONGÉE BENNE OUVERT';

        // M1 et M2 descendent ensemble (synchro gérée en aval)
        WinchM1Cmd.StartStop := TRUE;
        WinchM1Cmd.Direction := -1;
        WinchM1Cmd.SpeedPct  := 50.0;

        WinchM2Cmd.StartStop := TRUE;
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
            State := E_CycleStep.BOTTOM_TOUCH_WAIT;
        ELSIF LimitLegalReached THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0001;
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            BucketCmd.KoboldContactorCmd := FALSE;
            State := E_CycleStep.ERROR_HOLD;
        END_IF;

    E_CycleStep.BOTTOM_TOUCH_WAIT:
        CycleStep := E_CycleStep.BOTTOM_TOUCH_WAIT;
        CycleStateStr := 'REMONTÉE SÉCURISÉE APRÈS CONTACT FOND';

        WinchM1Cmd.StartStop := TRUE;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct := 20.0;

        WinchM2Cmd.StartStop := TRUE;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct := 20.0;

        // Les deux treuils restent synchronisés jusqu'au-dessus de la limite légale.
        IF CycleMotionPermit AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.SYNCHRO_ADJUST;
        END_IF;

    E_CycleStep.SYNCHRO_ADJUST:
        CycleStep := E_CycleStep.SYNCHRO_ADJUST;
        CycleStateStr := 'FERMETURE DU GODET / EXCAVATION';

        WinchM1Cmd.StartStop := FALSE;

        // Déclenchement fermeture benne
        BucketCmd.Close := TRUE;

        // Transition si benne fermé avec succès
        IF CycleMotionPermit AND Benne_Done AND Benne_IsClosed THEN
            BucketCmd.Close := FALSE;
            State := E_CycleStep.CTRL_ASCENDING;
        END_IF;

    E_CycleStep.CTRL_ASCENDING:
        CycleStep := E_CycleStep.CTRL_ASCENDING;
        CycleStateStr := 'REMONTÉE LENTE DE CONTRÔLE';

        // M1 et M2 montent lentement en synchro
        WinchM1Cmd.StartStop := TRUE;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 20.0;

        WinchM2Cmd.StartStop := TRUE;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 20.0;

        // Contrôle des deux codeurs
        IF WinchSyncError OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM) THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008;
            State := E_CycleStep.ERROR_HOLD;
        ELSIF CycleMotionPermit
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_CycleStep.ASCENDING_LOADED;
        ELSIF StabilizationTimer.Q THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008;
            State := E_CycleStep.ERROR_HOLD;
        END_IF;

    E_CycleStep.ASCENDING_LOADED:
        CycleStep := E_CycleStep.ASCENDING_LOADED;
        CycleStateStr := 'REMONTÉE EN CHARGE';

        WinchM1Cmd.StartStop := TRUE;
        WinchM1Cmd.Direction := 1;
        WinchM1Cmd.SpeedPct  := 70.0;

        WinchM2Cmd.StartStop := TRUE;
        WinchM2Cmd.Direction := 1;
        WinchM2Cmd.SpeedPct  := 70.0;

        // Transition alignée sur la limite haute d'exploitation
        IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM THEN
            WinchM1Cmd.StartStop := FALSE;
            WinchM2Cmd.StartStop := FALSE;
            State := E_CycleStep.DRAINING_PAUSE;
        END_IF;

    E_CycleStep.DRAINING_PAUSE:
        CycleStep := E_CycleStep.DRAINING_PAUSE;
        CycleStateStr := 'ÉGOUTTAGE DU GODET EN COURS';

        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;

        DrainingTimer(IN := TRUE, PT := DrainingTime);
        IF CycleMotionPermit AND DrainingTimer.Q THEN
            DrainingTimer(IN := FALSE);
            State := E_CycleStep.TRANSLATION_MOVE;
        END_IF;

    E_CycleStep.TRANSLATION_MOVE:
        CycleStep := E_CycleStep.TRANSLATION_MOVE;
        CycleStateStr := 'DÉPLACEMENT VERS TRÉMIE DE VIDANGE';

        TranslationCmd.Target := 1; // Trémie
        TranslationCmd.Start := TRUE;

        // Transition si translation arrivé à la trémie
        IF CycleMotionPermit AND Translation_At_Tremie THEN
            TranslationCmd.Start := FALSE;
            State := E_CycleStep.DESCENDING_OPEN_DUMP;
        END_IF;

    E_CycleStep.DESCENDING_OPEN_DUMP:
        CycleStep := E_CycleStep.DESCENDING_OPEN_DUMP;
        CycleStateStr := 'VIDANGE / OUVERTURE DU GODET';

        BucketCmd.Open := TRUE;

        // Transition si benne ouvert avec succès
        IF CycleMotionPermit AND Benne_Done AND Benne_IsOpen THEN
            BucketCmd.Open := FALSE;
            State := E_CycleStep.RETURN_WORK_POS;
        END_IF;

    E_CycleStep.RETURN_WORK_POS:
        CycleStep := E_CycleStep.RETURN_WORK_POS;
        CycleStateStr := 'RETOUR VERS FOSSE DE TRAVAIL';

        TranslationCmd.Target := SelectedWorkTarget;
        TranslationCmd.Start := TRUE;

        // Transition si translation de retour sur sa position de travail
        IF CycleMotionPermit AND ((SelectedWorkTarget = 2 AND Translation_At_P2)
           OR (SelectedWorkTarget = 3 AND Translation_At_P1)) THEN
            TranslationCmd.Start := FALSE;
            State := E_CycleStep.READY;
        END_IF;

    E_CycleStep.READY:
        CycleStep := E_CycleStep.READY;
        CycleStateStr := 'CYCLE AUTOMATIQUE COMPLÉTÉ - PRÊT';

        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;
        TranslationCmd.Start := FALSE;
        Done  := TRUE;
        Busy  := FALSE;

        // Rebouclage manuel ou auto sur Start
        IF StartEdge.Q THEN
            Done := FALSE;
            State := E_CycleStep.DESCENDING_OPEN;
        END_IF;

    E_CycleStep.ERROR_HOLD:
        CycleStep := E_CycleStep.ERROR_HOLD;
        CycleStateStr := 'CYCLE SUSPENDU (PAUSE OU ARRÊT DE SÉCURITÉ)';

        WinchM1Cmd.StartStop := FALSE;
        WinchM2Cmd.StartStop := FALSE;
        TranslationCmd.Start := FALSE;

        BucketCmd.Open  := FALSE;
        BucketCmd.Close := FALSE;

END_CASE;

{endregion}

{region "Repli homme mort"}
// 🛑 Relâchement homme-mort : aucune demande d'actionneur ne reste active.
// L'étape est mémorisée et reprend au prochain appui valide.
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
