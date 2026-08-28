(* =======================================================================
   🔄 ST_ChainCycleSemiAuto — Diagnostic chronologique Séquenceur Semi-Auto
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Vue dépannage / Watch CODESYS pour le cycle semi-automatique
   📄 Doc métier : DOC/AF/AF_Partie-14_Fonction_Troubleshooting/FB_TroubleshootingView_v1.2.md
   🔒 Sécurité : 100% lecture seule / diagnostic d'observation
   ======================================================================= *)

TYPE ST_ChainCycleSemiAuto :
STRUCT
    // 🚦 1. Conditions d'engagement et autorisations
    Idx101_ModeSemiAutoActive        : BOOL; // 1 = Mode arbitré SEMI_AUTO actif | 0 = Autre mode
    Idx102_PowerAndSafetyOk          : BOOL; // 1 = Chaîne de sécurité OK (PowerContactorEngaged)
    Idx103_HeartbeatIhmOk            : BOOL; // 1 = Liaison IHM<->PLC valide
    Idx104_DeadmanArmed              : BOOL; // 1 = Bouton homme-mort armé (fenêtre 3s active)
    Idx105_MancheDeflechi            : BOOL; // 1 = Permis mouvement armé (manche hors zone neutre)
    Idx106_HomedM1M2                 : BOOL; // 1 = Codeurs treuils M1 et M2 référencés
    Idx107_StartCycleRequest         : BOOL; // 1 = Demande Start reçue (IHM)
    Idx108_AbortCycleRequest         : BOOL; // 1 = Demande Abort reçue (IHM)

    // 🔄 2. État du Séquenceur
    Idx201_Ready                     : BOOL; // 1 = Séquenceur prêt à démarrer
    Idx202_Busy                      : BOOL; // 1 = Cycle en cours d'exécution
    Idx203_Done                      : BOOL; // 1 = Cycle terminé avec succès
    Idx204_Error                     : BOOL; // 1 = Défaut ou anomalie bloquante sur le cycle
    Idx205_ErrorId                   : WORD; // Code d'erreur interne FB_Cycle
    Idx206_Step                      : E_CycleStep; // Étape courante (X0 à X13 + STABILIZING)
    Idx207_StepStr                   : STRING(80);  // Libellé explicite de l'étape
    Idx208_StepAtError               : E_CycleStep; // Étape mémorisée lors du dernier défaut
    Idx209_WaitingForOperator        : BOOL;        // 1 = En attente d'une action humaine
    Idx210_WaitingForProcess         : BOOL;        // 1 = En attente d'une condition physique/procédé
    Idx211_OperatorActionId          : UINT;        // Identifiant numérique de l'action attendue
    Idx212_OperatorAction            : STRING(120); // Description explicite de l'action/attente
    Idx213_ExpectedAxis              : E_OperatorAxis; // Organe attendu (NONE, JOYSTICK_X, JOYSTICK_Y, BUTTON)
    Idx214_ExpectedDirection         : INT;         // Sens attendu (-1, 0, +1)
    Idx215_WaitingResume             : BOOL;        // 1 = En pause suite à bascule de mode (attente StartCycle)
    Idx216_PausedState               : E_CycleStep; // Étape mémorisée prête pour reprise

    // 🎯 3. Consignes & Feedbacks Opérationnels
    Idx301_TargetPosition            : INT;  // Cible translation sélectionnée (1=Trémie, 3=P1)
    Idx302_TargetDepth_M             : REAL; // Profondeur de consigne (m)
    Idx303_KoboldBottomTouch         : BOOL; // 1 = Détection contact fond Kobold
    Idx304_SpeedMismatchActive       : BOOL; // 1 = Alerte écart de vitesse M1/M2 active
    Idx305_LimitLegalReached         : BOOL; // 1 = Limite légale atteinte (descente bloquée)
    Idx306_WinchSyncError            : BOOL; // 1 = Erreur de synchronisme M1/M2
END_STRUCT
END_TYPE
