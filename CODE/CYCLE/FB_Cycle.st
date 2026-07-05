(* ═══════════════════════════════════════════════════════════════
   🔄 FB_Cycle — Séquenceur du Cycle Automatique (Grafcet de dragage)
   ───────────────────────────────────────────────────────────────
   📄 Doc : DOC/AF_Partie4_Cycle_Sequenceur_v1.2.md
   🔌 Conforme au contrat FB standard (Partie3 §1bis).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK FB_Cycle
VAR_INPUT
    Enable              : BOOL;         // Activation générale du séquenceur
    Reset               : BOOL;         // Acquittement défaut (front)
    EmergencyStopOk     : BOOL;         // Chaîne de sécurité OK

    // Commandes opérateur
    StartCycle          : BOOL;         // Demande lancement / reprise cycle (IHM)
    PauseCycle          : BOOL;         // Demande pause temporaire (IHM)
    AbortCycle          : BOOL;         // Demande abandon cycle (IHM)

    // Cibles et paramètres
    TargetDepthM        : REAL;         // Profondeur de consigne (négative)
    TargetOffsetM       : REAL;         // Écart de fermeture grappin cible
    SelectedTargetNum_IHM : INT;        // Cible sélectionnée (1=Fosse1, 2=Fosse2)

    // Feedbacks physique & matériel
    BottomTouched       : BOOL;         // Capteur mou de câble / fond touché
    M1_CablePosM        : REAL;         // Position câble treuil M1 (recalée)
    M2_CablePosM        : REAL;         // Position câble treuil M2 (recalée)

    // Feedbacks Chariot M3
    Chariot_At_Fosse1   : BOOL;         // Capteur fin de course fosse 1
    Chariot_At_Fosse2   : BOOL;         // Capteur fin de course fosse 2
    Chariot_At_Maintenance : BOOL;      // Capteur fin de course maintenance
    Chariot_At_Tremie   : BOOL;         // Capteur fin de course trémie
    Chariot_Busy        : BOOL;         // Mouvement chariot en cours
    Chariot_Done        : BOOL;         // Cible chariot atteinte

    // Feedbacks Grappin
    Grappin_Busy        : BOOL;         // Mouvement mâchoires grappin en cours
    Grappin_Done        : BOOL;         // Mouvement ouverture/fermeture terminé
    Grappin_IsOpen      : BOOL;         // Grappin mécaniquement ouvert mémorisé
    Grappin_IsClosed    : BOOL;         // Grappin mécaniquement fermé mémorisé
END_VAR

VAR_OUTPUT
    Ready               : BOOL;         // Séquenceur disponible
    Busy                : BOOL;         // Cycle automatique actif
    Done                : BOOL;         // Cycle automatique complété
    Error               : BOOL;         // Défaut cycle
    ErrorId             : WORD;         // Code défaut (ex: 1=Timeout, 2=Incohérence)

    // Commandes Winch M1 (Enrouleur)
    CmdWinchM1_StartStop : BOOL;
    CmdWinchM1_Direction : INT;
    CmdWinchM1_SpeedPct  : REAL;

    // Commandes Winch M2 (Grappin)
    CmdWinchM2_StartStop : BOOL;
    CmdWinchM2_Direction : INT;
    CmdWinchM2_SpeedPct  : REAL;

    // Commandes Chariot M3 (Translation)
    CmdChariotM3_Start   : BOOL;
    CmdChariotM3_Target  : INT;

    // Commandes FB_Grappin
    CmdGrappin_Open      : BOOL;
    CmdGrappin_Close     : BOOL;

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
    SelectedWorkTarget  : INT;          // Cible de travail mémorisée pour le retour (1 ou 2)
    
    // Paramètres internes
    CtrlAscentDistM     : REAL := 2.0;  // Distance de remontée lente de contrôle
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

    CmdChariotM3_Start   := FALSE;
    CmdChariotM3_Target  := 0;
    CmdGrappin_Open      := FALSE;
    CmdGrappin_Close     := FALSE;

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
        CmdChariotM3_Start   := FALSE;
        CmdGrappin_Open      := FALSE;
        CmdGrappin_Close     := FALSE;
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

        // Choix cible
        IF SelectedTargetNum_IHM = 1 OR SelectedTargetNum_IHM = 2 THEN
            SelectedWorkTarget := SelectedTargetNum_IHM;
            CmdChariotM3_Target := SelectedWorkTarget;
            CmdChariotM3_Start := TRUE;
            
            // Attente positionnement chariot
            IF (SelectedWorkTarget = 1 AND Chariot_At_Fosse1) 
               OR (SelectedWorkTarget = 2 AND Chariot_At_Fosse2) THEN
                CmdChariotM3_Start := FALSE;
                State := E_CycleStep.DESCENDING_OPEN;
            END_IF;
        END_IF;

    E_CycleStep.DESCENDING_OPEN: // ⬇️ ÉTAPE 2 : Plongée grappin ouvert
        CycleStep := E_CycleStep.DESCENDING_OPEN;
        CycleStateStr := 'PLONGÉE GRAPPIN OUVERT';

        // M1 et M2 descendent ensemble (synchro gérée en aval)
        CmdWinchM1_StartStop := TRUE;
        CmdWinchM1_Direction := -1;
        CmdWinchM1_SpeedPct  := 50.0; // Vitesse de descente 50%

        CmdWinchM2_StartStop := TRUE;
        CmdWinchM2_Direction := -1;
        CmdWinchM2_SpeedPct  := 50.0;

        // Transition si fond touché (mou de câble détecté)
        IF BottomTouched THEN
            CmdWinchM1_StartStop := FALSE;
            CmdWinchM2_StartStop := FALSE;
            TouchPositionM := M1_CablePosM; // Mémorisation position contact
            State := E_CycleStep.BOTTOM_TOUCH_WAIT;
        END_IF;

    E_CycleStep.BOTTOM_TOUCH_WAIT: // ⏳ ÉTAPE 3 : Temporisation contact fond
        CycleStep := E_CycleStep.BOTTOM_TOUCH_WAIT;
        CycleStateStr := 'ATTENTE DÉPOSE FOND';

        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;

        // Transition après pose confirmée (ici instantanée, prête pour tempo)
        State := E_CycleStep.SYNCHRO_ADJUST;

    E_CycleStep.SYNCHRO_ADJUST: // 🪣 ÉTAPE 4 : Fermeture du grappin (Excavation)
        CycleStep := E_CycleStep.SYNCHRO_ADJUST;
        CycleStateStr := 'FERMETURE DU GODET / EXCAVATION';

        CmdWinchM1_StartStop := FALSE; // M1 reste immobile
        
        // Déclenchement fermeture grappin
        CmdGrappin_Close := TRUE;

        // Transition si grappin fermé avec succès
        IF Grappin_Done AND Grappin_IsClosed THEN
            CmdGrappin_Close := FALSE;
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

        // Transition après remontée de contrôle de 2.0 mètres
        IF M1_CablePosM >= (TouchPositionM + CtrlAscentDistM) THEN
            State := E_CycleStep.ASCENDING_LOADED;
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

        // Transition si position haute (butée haute virtuelle) atteinte
        IF M1_CablePosM >= GVL_PERSISTENT.HomingTargetM1_M - 2.0 THEN // -2m de la butée haute
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
        IF DrainingTimer.Q THEN
            DrainingTimer(IN := FALSE);
            State := E_CycleStep.CHARIOT_MOVE;
        END_IF;

    E_CycleStep.CHARIOT_MOVE: // ↔️ ÉTAPE 8 : Déplacement vers trémie
        CycleStep := E_CycleStep.CHARIOT_MOVE;
        CycleStateStr := 'DÉPLACEMENT VERS TRÉMIE DE VIDANGE';

        CmdChariotM3_Target := 4; // Trémie
        CmdChariotM3_Start := TRUE;

        // Transition si chariot arrivé à la trémie
        IF Chariot_At_Tremie THEN
            CmdChariotM3_Start := FALSE;
            State := E_CycleStep.DESCENDING_OPEN_DUMP;
        END_IF;

    E_CycleStep.DESCENDING_OPEN_DUMP: // 🗑️ ÉTAPE 9 : Ouverture grappin (Vidange)
        CycleStep := E_CycleStep.DESCENDING_OPEN_DUMP;
        CycleStateStr := 'VIDANGE / OUVERTURE DU GODET';

        // Déclenchement ouverture grappin
        CmdGrappin_Open := TRUE;

        // Transition si grappin ouvert avec succès
        IF Grappin_Done AND Grappin_IsOpen THEN
            CmdGrappin_Open := FALSE;
            State := E_CycleStep.RETURN_WORK_POS;
        END_IF;

    E_CycleStep.RETURN_WORK_POS: // 🔙 ÉTAPE 10 : Retour fosse de travail
        CycleStep := E_CycleStep.RETURN_WORK_POS;
        CycleStateStr := 'RETOUR VERS FOSSE DE TRAVAIL';

        CmdChariotM3_Target := SelectedWorkTarget;
        CmdChariotM3_Start := TRUE;

        // Transition si chariot de retour sur sa fosse
        IF (SelectedWorkTarget = 1 AND Chariot_At_Fosse1) 
           OR (SelectedWorkTarget = 2 AND Chariot_At_Fosse2) THEN
            CmdChariotM3_Start := FALSE;
            State := E_CycleStep.READY;
        END_IF;

    E_CycleStep.READY: // 🏁 ÉTAPE 11 : Prêt / Cycle terminé
        CycleStep := E_CycleStep.READY;
        CycleStateStr := 'CYCLE AUTOMATIQUE COMPLÉTÉ - PRÊT';
        
        CmdWinchM1_StartStop := FALSE;
        CmdWinchM2_StartStop := FALSE;
        CmdChariotM3_Start   := FALSE;
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
        CmdChariotM3_Start   := FALSE;
        
        // Relâchement des commandes grappin
        CmdGrappin_Open := FALSE;
        CmdGrappin_Close := FALSE;
END_CASE;
