(* ═══════════════════════════════════════════════════════════════
   🔄 FB_Cycle — Séquenceur du Cycle Automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie-04_Cycle_Sequenceur_v1.4.md
   🔌 Conforme au contrat FB standard (Partie3 §1bis).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_Cycle
VAR_INPUT
    Enable              : BOOL;         // Activation générale du séquenceur
    Reset               : BOOL;         // Acquittement défaut (front)
    EmergencyStopOk     : BOOL;         // Chaîne de sécurité OK
    CycleMotionPermit   : BOOL;         // Homme-mort + joystick actif
    HeartbeatIhmOk      : BOOL;         // 💓 IHM↔PLC valide ; FALSE = repli cycle obligatoire

    // Commandes opérateur
    StartCycle          : BOOL;         // Demande lancement / reprise cycle (IHM)
    PauseCycle          : BOOL;         // Demande pause temporaire (IHM)
    AbortCycle          : BOOL;         // Demande abandon cycle (IHM)

    // Cibles et paramètres
    TargetDepthM        : REAL;         // Profondeur de consigne (négative)
    TargetOffsetM       : REAL;         // Écart de fermeture benne cible
    SelectedTargetNum_IHM : INT;        // Cible sélectionnée (2=P2, 3=P1 — 🆕 REX 2026-07-18, ex-1=Fosse1/2=Fosse2, voir AF_Partie-02 v2.12 §3bis)

    // Feedbacks physique & matériel
    KoboldContactFond   : BOOL;         // Retour dédié Kobold : TRUE = contact fond détecté
    LimitLegalReached   : BOOL;         // Limite légale atteinte (descente interdite)
    LimitLegalDepthM    : REAL;         // Profondeur légale minimale autorisée
    WinchSyncError      : BOOL;         // Désynchronisme bloquant M1/M2
    WinchSyncDeltaM     : REAL;         // Écart codeurs M1/M2 pour diagnostic
    M1_CablePosM        : REAL;         // Position câble treuil M1 (recalée)
    M2_CablePosM        : REAL;         // Position câble treuil M2 (recalée)
    M1_MeasuredSpeedMps : REAL;         // Vitesse linéaire mesurée M1 (m/s)
    M2_MeasuredSpeedMps : REAL;         // Vitesse linéaire mesurée M2 (m/s)
    SpeedMismatchThresholdMps : REAL;   // Seuil écart vitesse ; 0 = contrôle désactivé
    SpeedMismatchTimeout      : TIME;   // Durée de confirmation ; 0 = contrôle désactivé
    CableLimitM1AscentM       : REAL;   // Limite haute d'exploitation M1 ; seuil de fin ASCENDING_LOADED

    // Feedbacks Translation M3 — 🆕 REX 2026-07-18 : Fosse1/Fosse2 renommés P1/P2 (AF_Partie-02 v2.12 §3bis)
    Translation_At_P1       : BOOL;         // Capteur position P1 (ex-Fosse1)
    Translation_At_P2       : BOOL;         // Capteur position P2 (ex-Fosse2)
    Translation_At_Maintenance : BOOL;      // Capteur fin de course maintenance
    Translation_At_Tremie   : BOOL;         // Capteur fin de course trémie
    Translation_Busy        : BOOL;         // Mouvement translation en cours
    Translation_Done        : BOOL;         // Cible translation atteinte

    // Feedbacks Benne
    Benne_Busy        : BOOL;         // Mouvement mâchoires benne en cours
    Benne_Done        : BOOL;         // Mouvement ouverture/fermeture terminé
    Benne_IsOpen      : BOOL;         // Benne mécaniquement ouvert mémorisé
    Benne_IsClosed    : BOOL;         // Benne mécaniquement fermé mémorisé
END_VAR

VAR_OUTPUT
    Ready               : BOOL;         // Séquenceur disponible
    Busy                : BOOL;         // Cycle automatique actif
    Done                : BOOL;         // Cycle automatique complété
    Error               : BOOL;         // Défaut cycle
    ErrorId             : WORD;         // bit0: Timeout descente/limite, bit1: désynchronisme treuils, bit2: cible invalide, bit3: stabilisation M1/M2 impossible, bit4: écart vitesse M1/M2 confirmé, bit5: perte heartbeat IHM
    SpeedMismatchMps    : REAL;         // Écart absolu de vitesse M1/M2 (m/s)
    SpeedMismatchActive : BOOL;         // Seuil vitesse dépassé sur le cycle courant
    SpeedMismatchConfirmed : BOOL;      // Écart vitesse confirmé pendant SpeedMismatchTimeout

    // Commandes Winch M1 (Enrouleur)
    CmdWinchM1_StartStop : BOOL;
    CmdWinchM1_Direction : INT;
    CmdWinchM1_SpeedPct  : REAL;

    // Commandes Winch M2 (Benne)
    CmdWinchM2_StartStop : BOOL;
    CmdWinchM2_Direction : INT;
    CmdWinchM2_SpeedPct  : REAL;

    // Commandes Translation M3 (Translation)
    CmdTranslationM3_Start   : BOOL;
    CmdTranslationM3_Target  : INT;

    // Commandes FB_Bucket
    CmdBucket_Open      : BOOL;
    CmdBucket_Close     : BOOL;
    KoboldContactorCmd  : BOOL;         // Commande contacteur puissance Kobold (recherche fond)

    // Métadonnées d'affichage IHM
    CycleStep           : E_CycleStep;  // Étape active du Grafcet
    CycleStateStr       : STRING(80);   // Libellé en clair de l'étape
END_VAR

VAR
    ResetEdge           : R_TRIG;
    StartEdge           : R_TRIG;
    PauseEdge           : R_TRIG;
    AbortEdge           : R_TRIG;

    // Séquencement
    State               : E_CycleStep := E_CycleStep.INIT; // Étape courante
    SavedState          : E_CycleStep := E_CycleStep.INIT; // Étape sauvegardée lors d'une pause
    IsPaused            : BOOL := FALSE;                   // Drapeau de mise en pause active

    // Mémorisations et Timers
    TouchPositionM      : REAL;         // Position M1 mémorisée lors du contact fond
    RaiseTargetM        : REAL;         // Profondeur de remontée mémorisée
    DrainingTimer       : TON;          // Temporisateur de vidage (égouttage)
    StabilizationTimer  : TON;          // Temporisation maximale de remontée lente après fermeture
    SpeedMismatchTimer  : TON;          // Confirmation temporelle écart de vitesse M1/M2
    SelectedWorkTarget  : INT;          // Cible de travail mémorisée pour le retour (2=P2 ou 3=P1 — 🆕 REX 2026-07-18)
    
    // Paramètres internes
    CtrlAscentDistM     : REAL := 2.0;  // Distance de remontée lente de contrôle
    CtrlAscentToleranceM : REAL := 0.25; // Écart maximal admis entre les deux codeurs
    CtrlAscentTimeout    : TIME := T#30s; // Temps maximal pour atteindre la zone de stabilisation
    DrainingTime        : TIME := T#5s; // Temps d'égouttage par défaut
END_VAR

// === IMPLEMENTATION ===

// 🛑 1. GATES DE SÉCURITÉ ET BLOCAGE
IF NOT Enable OR NOT EmergencyStopOk THEN
    CmdWinchM1_StartStop := FALSE;
    CmdWinchM1_Direction := 0;
    CmdWinchM1_SpeedPct  := 0.0;

    CmdWinchM2_StartStop := FALSE;
    CmdWinchM2_Direction := 0;
    CmdWinchM2_SpeedPct  := 0.0;

    CmdTranslationM3_Start   := FALSE;
    CmdTranslationM3_Target  := 0;
    CmdBucket_Open      := FALSE;
    CmdBucket_Close     := FALSE;
    KoboldContactorCmd  := FALSE;

    State                := E_CycleStep.INIT;
    CycleStep            := E_CycleStep.INIT;
    CycleStateStr        := 'ARRÊT : SÉCURITÉ ABSENTE OU AUTO DÉSACTIVÉ';
    Ready                := FALSE;
    Busy                 := FALSE;
    Done                 := FALSE;
    IsPaused             := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
ResetEdge(CLK := Reset);
StartEdge(CLK := StartCycle);
PauseEdge(CLK := PauseCycle);
AbortEdge(CLK := AbortCycle);

// ⏱️ T36 — surveillance indépendante de la remontée lente : un codeur bloqué
// ne doit jamais laisser le cycle attendre indéfiniment.
StabilizationTimer(IN := (State = E_CycleStep.CTRL_ASCENDING), PT := CtrlAscentTimeout);

// 📏 T43 — comparaison vitesse réelle M1/M2.
// Le contrôle est volontairement désactivé tant que le seuil et la durée ne sont pas définis.
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
// La sortie SafeStop reste gérée par les blocs safety métier ; ce bit protège le séquenceur.
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

// 🔁 2. LOGIQUE DU SÉQUENCEUR (Machine d'état)
CASE State OF

    E_CycleStep.INIT: // 🔄 ÉTAPE 0 : Initialisation et vérifications
        CycleStep := E_CycleStep.INIT;
        CycleStateStr := 'VÉRIFICATION COHÉRENCE SYSTÈME';
        
        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;
        CmdTranslationM3_Start   := FALSE;
        CmdBucket_Open      := FALSE;
        CmdBucket_Close     := FALSE;
        KoboldContactorCmd  := FALSE;
        Busy                 := FALSE;
        Done                 := FALSE;

        // Transition si système sain et réarmé (front reset ou démarrage)
        IF StartEdge.Q THEN
            State := E_CycleStep.WORK_POS_SELECT;
        END_IF;

    E_CycleStep.WORK_POS_SELECT: // 📍 ÉTAPE 1 : Sélection position travail
        CycleStep := E_CycleStep.WORK_POS_SELECT;
        CycleStateStr := 'SÉLECTION POSITION TRAVAIL (FOSSE 1 / 2)';
        Busy := TRUE;

        // Choix cible — 🆕 REX 2026-07-18 : zone de travail = P2/P1 (cibles 2/3), ex-Fosse1/Fosse2
        // (cibles 1/2), suite au remap 5 positions Trémie(1)/P2(2)/P1(3)/Maintenance(4)
        IF (SelectedTargetNum_IHM <> 2) AND (SelectedTargetNum_IHM <> 3) THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0004; // cible de travail invalide
            State := E_CycleStep.ERROR_HOLD;
        ELSIF SelectedTargetNum_IHM = 2 OR SelectedTargetNum_IHM = 3 THEN
            SelectedWorkTarget := SelectedTargetNum_IHM;
            CmdTranslationM3_Target := SelectedWorkTarget;
            CmdTranslationM3_Start := CycleMotionPermit;

            // Attente positionnement translation
            IF CycleMotionPermit AND ((SelectedWorkTarget = 2 AND Translation_At_P2)
               OR (SelectedWorkTarget = 3 AND Translation_At_P1)) THEN
                CmdTranslationM3_Start := FALSE;
                State := E_CycleStep.DESCENDING_OPEN;
            END_IF;
        END_IF;

    E_CycleStep.DESCENDING_OPEN: // ⬇️ ÉTAPE 2 : Plongée benne ouvert
        CycleStep := E_CycleStep.DESCENDING_OPEN;
        CycleStateStr := 'PLONGÉE BENNE OUVERT';

        // M1 et M2 descendent ensemble (synchro gérée en aval)
        CmdWinchM1_StartStop := TRUE;
        CmdWinchM1_Direction := -1;
        CmdWinchM1_SpeedPct  := 50.0; // Vitesse de descente 50%

        CmdWinchM2_StartStop := TRUE;
        CmdWinchM2_Direction := -1;
        CmdWinchM2_SpeedPct  := 50.0;
        KoboldContactorCmd   := TRUE;

        // Transition uniquement sur le retour dédié Kobold.
        IF CycleMotionPermit AND KoboldContactFond THEN
            CmdWinchM1_StartStop := FALSE;
            CmdWinchM2_StartStop := FALSE;
            KoboldContactorCmd := FALSE;
            TouchPositionM := M1_CablePosM; // Mémorisation position contact
            IF LimitLegalDepthM < -0.01 THEN
                RaiseTargetM := MAX(TouchPositionM + 0.5, LimitLegalDepthM + 0.5);
            ELSE
                RaiseTargetM := TouchPositionM + 0.5;
            END_IF;
            State := E_CycleStep.BOTTOM_TOUCH_WAIT;
        ELSIF LimitLegalReached THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0001;
            CmdWinchM1_StartStop := FALSE;
            CmdWinchM2_StartStop := FALSE;
            KoboldContactorCmd := FALSE;
            State := E_CycleStep.ERROR_HOLD;
        END_IF;

    E_CycleStep.BOTTOM_TOUCH_WAIT: // ⏳ ÉTAPE 3 : Temporisation contact fond
        CycleStep := E_CycleStep.BOTTOM_TOUCH_WAIT;
        CycleStateStr := 'REMONTÉE SÉCURISÉE APRÈS CONTACT FOND';

        CmdWinchM1_StartStop := TRUE;
        CmdWinchM1_Direction := 1;
        CmdWinchM1_SpeedPct := 20.0;
        CmdWinchM2_StartStop := TRUE;
        CmdWinchM2_Direction := 1;
        CmdWinchM2_SpeedPct := 20.0;

        // Les deux treuils restent synchronisés jusqu'au-dessus de la limite légale.
        IF CycleMotionPermit AND (M1_CablePosM >= RaiseTargetM) AND (M2_CablePosM >= RaiseTargetM) THEN
            CmdWinchM1_StartStop := FALSE;
            CmdWinchM2_StartStop := FALSE;
            State := E_CycleStep.SYNCHRO_ADJUST;
        END_IF;

    E_CycleStep.SYNCHRO_ADJUST: // 🪣 ÉTAPE 4 : Fermeture du benne (Excavation)
        CycleStep := E_CycleStep.SYNCHRO_ADJUST;
        CycleStateStr := 'FERMETURE DU GODET / EXCAVATION';

        CmdWinchM1_StartStop := FALSE; // M1 reste immobile
        
        // Déclenchement fermeture benne
        CmdBucket_Close := TRUE;

        // Transition si benne fermé avec succès
        IF CycleMotionPermit AND Benne_Done AND Benne_IsClosed THEN
            CmdBucket_Close := FALSE;
            State := E_CycleStep.CTRL_ASCENDING;
        END_IF;

    E_CycleStep.CTRL_ASCENDING: // ⬆️ ÉTAPE 5 : Remontée lente de contrôle
        CycleStep := E_CycleStep.CTRL_ASCENDING;
        CycleStateStr := 'REMONTÉE LENTE DE CONTRÔLE';

        // M1 et M2 montent lentement en synchro
        CmdWinchM1_StartStop := TRUE;
        CmdWinchM1_Direction := 1;
        CmdWinchM1_SpeedPct  := 20.0; // 20% max

        CmdWinchM2_StartStop := TRUE;
        CmdWinchM2_Direction := 1;
        CmdWinchM2_SpeedPct  := 20.0;

        // 🛡️ Contrôle des deux codeurs : la benne chargée doit remonter avec
        // M1 et M2. Un seul codeur arrivé ne suffit pas.
        IF WinchSyncError OR (ABS(M1_CablePosM - M2_CablePosM) > CtrlAscentToleranceM) THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008; // stabilisation/désynchronisme après fermeture
            State := E_CycleStep.ERROR_HOLD;
        // Transition uniquement lorsque les deux treuils sont au-dessus de la
        // zone de contrôle et restent synchronisés.
        ELSIF CycleMotionPermit
           AND (M1_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (M2_CablePosM >= (TouchPositionM + CtrlAscentDistM))
           AND (ABS(M1_CablePosM - M2_CablePosM) <= CtrlAscentToleranceM) THEN
            State := E_CycleStep.ASCENDING_LOADED;
        ELSIF StabilizationTimer.Q THEN
            Error := TRUE;
            ErrorId := ErrorId OR 16#0008; // un treuil n'a pas atteint la zone de contrôle
            State := E_CycleStep.ERROR_HOLD;
        END_IF;

    E_CycleStep.ASCENDING_LOADED: // 🚀 ÉTAPE 6 : Remontée pleine vitesse
        CycleStep := E_CycleStep.ASCENDING_LOADED;
        CycleStateStr := 'REMONTÉE EN CHARGE';

        CmdWinchM1_StartStop := TRUE;
        CmdWinchM1_Direction := 1;
        CmdWinchM1_SpeedPct  := 70.0; // Grande vitesse 70%

        CmdWinchM2_StartStop := TRUE;
        CmdWinchM2_Direction := 1;
        CmdWinchM2_SpeedPct  := 70.0;

        // 🔧 WINCH-CORE-01 : transition alignée sur la limite haute d'exploitation
        // réellement utilisée par FB_Winch. Aucun seuil dérivé de la cible homing :
        // 8,0 m = exploitation ; 8,5 m = capteur haut/homing uniquement.
        IF CycleMotionPermit AND M1_CablePosM >= CableLimitM1AscentM THEN
            CmdWinchM1_StartStop := FALSE;
            CmdWinchM2_StartStop := FALSE;
            State := E_CycleStep.DRAINING_PAUSE;
        END_IF;

    E_CycleStep.DRAINING_PAUSE: // 💧 ÉTAPE 7 : Égouttage temporisé
        CycleStep := E_CycleStep.DRAINING_PAUSE;
        CycleStateStr := 'ÉGOUTTAGE DU GODET EN COURS';

        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;

        DrainingTimer(IN := TRUE, PT := DrainingTime);
        IF CycleMotionPermit AND DrainingTimer.Q THEN
            DrainingTimer(IN := FALSE);
            State := E_CycleStep.TRANSLATION_MOVE;
        END_IF;

    E_CycleStep.TRANSLATION_MOVE: // ↔️ ÉTAPE 8 : Déplacement vers trémie
        CycleStep := E_CycleStep.TRANSLATION_MOVE;
        CycleStateStr := 'DÉPLACEMENT VERS TRÉMIE DE VIDANGE';

        CmdTranslationM3_Target := 1; // Trémie — 🆕 REX 2026-07-18 : ex-4, remap 5 positions (AF_Partie-02 v2.12 §3bis)
        CmdTranslationM3_Start := TRUE;

        // Transition si translation arrivé à la trémie
        IF CycleMotionPermit AND Translation_At_Tremie THEN
            CmdTranslationM3_Start := FALSE;
            State := E_CycleStep.DESCENDING_OPEN_DUMP;
        END_IF;

    E_CycleStep.DESCENDING_OPEN_DUMP: // 🗑️ ÉTAPE 9 : Ouverture benne (Vidange)
        CycleStep := E_CycleStep.DESCENDING_OPEN_DUMP;
        CycleStateStr := 'VIDANGE / OUVERTURE DU GODET';

        // Déclenchement ouverture benne
        CmdBucket_Open := TRUE;

        // Transition si benne ouvert avec succès
        IF CycleMotionPermit AND Benne_Done AND Benne_IsOpen THEN
            CmdBucket_Open := FALSE;
            State := E_CycleStep.RETURN_WORK_POS;
        END_IF;

    E_CycleStep.RETURN_WORK_POS: // 🔙 ÉTAPE 10 : Retour fosse de travail
        CycleStep := E_CycleStep.RETURN_WORK_POS;
        CycleStateStr := 'RETOUR VERS FOSSE DE TRAVAIL';

        CmdTranslationM3_Target := SelectedWorkTarget;
        CmdTranslationM3_Start := TRUE;

        // Transition si translation de retour sur sa position de travail
        IF CycleMotionPermit AND ((SelectedWorkTarget = 2 AND Translation_At_P2)
           OR (SelectedWorkTarget = 3 AND Translation_At_P1)) THEN
            CmdTranslationM3_Start := FALSE;
            State := E_CycleStep.READY;
        END_IF;

    E_CycleStep.READY: // 🏁 ÉTAPE 11 : Prêt / Cycle terminé
        CycleStep := E_CycleStep.READY;
        CycleStateStr := 'CYCLE AUTOMATIQUE COMPLÉTÉ - PRÊT';
        
        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;
        CmdTranslationM3_Start   := FALSE;
        Done                 := TRUE;
        Busy                 := FALSE;

        // Rebouclage manuel ou auto sur Start
        IF StartEdge.Q THEN
            Done := FALSE;
            State := E_CycleStep.DESCENDING_OPEN;
        END_IF;

    E_CycleStep.ERROR_HOLD: // 🛑 ÉTAPE 12 : Maintien sur arrêt / pause
        CycleStep := E_CycleStep.ERROR_HOLD;
        CycleStateStr := 'CYCLE SUSPENDU (PAUSE OU ARRÊT DE SÉCURITÉ)';

        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;
        CmdTranslationM3_Start   := FALSE;
        
        // Relâchement des commandes benne
        CmdBucket_Open := FALSE;
        CmdBucket_Close := FALSE;
END_CASE;

// 🛑 Relâchement homme-mort : aucune demande d'actionneur ne reste active.
// L'étape est mémorisée et reprend au prochain appui valide.
IF Busy AND NOT CycleMotionPermit THEN
    CmdWinchM1_StartStop := FALSE;
    CmdWinchM2_StartStop := FALSE;
    CmdTranslationM3_Start := FALSE;
    CmdBucket_Open := FALSE;
    CmdBucket_Close := FALSE;
    KoboldContactorCmd := FALSE;
END_IF;
