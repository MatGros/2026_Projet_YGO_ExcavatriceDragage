(* =======================================================================
   🪣 FB_Bucket — Commande d'ouverture et de fermeture du benne
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Pilotage synchrone et séquencement d'ouverture/fermeture benne
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.1.md
   🔌 Interface : FB standard (Partie3 §1bis)
   🔒 Sécurité : Surveillance du glissement M1 et interlocks de mouvement
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_Bucket
VAR_INPUT
    // === COMMANDES ET ETATS GENERAL ===
    Enable                          : BOOL;                           // --> [CMD] Autorisation generale FB
    Reset                           : BOOL;                           // --> [CMD] Acquittement defauts sur front
    Mode                            : E_Mode;                         // --> [CMD] Mode de marche machine
    CmdOpen_IHM                     : BOOL;                           // --> [CMD] Demande ouverture depuis IHM
    CmdClose_IHM                    : BOOL;                           // --> [CMD] Demande fermeture depuis IHM
    MotionRequestActive             : BOOL;                           // --> [CMD] Intention mouvement arbitree
    MotionDirection                 : INT;                            // --> [CMD] Sens arbitre (1: montee, -1: descente)
    ConfirmOpenPosition             : BOOL;                           // --> [CMD] Bouton IHM confirmation benne ouvert
    ConfirmClosePosition            : BOOL;                           // --> [CMD] Bouton IHM confirmation benne ferme

    // === SECOURS ET HARDWARE ===
    PowerContactorEngaged           : BOOL;                           // --> [SAFE] Condition d'arret d'urgence / puissance
    CablePosM1                      : REAL;                           // --> [HW] Position reelle cable treuil M1 (m)
    CablePosM2                      : REAL;                           // --> [HW] Position reelle cable treuil M2 (m)
    HomedM1                         : BOOL;                           // --> [HW] Codeur M1 reference
    HomedM2                         : BOOL;                           // --> [HW] Codeur M2 reference
    M1_Busy                         : BOOL;                           // --> [HW] Treuil M1 en mouvement (Busy)
    M2_Busy                         : BOOL;                           // --> [HW] Treuil M2 en mouvement (Busy)
    InhibitM1                       : BOOL;                           // --> [HW] Treuil M1 inhibe
    InhibitM2                       : BOOL;                           // --> [HW] Treuil M2 inhibe

    // === REGLAGES ET CONFIGURATION ===
    Config                          : ST_BucketConfig;                // --> [CFG] Configuration parametres benne
    CfgTimeoutDuration              : TIME := T#60s;                  // --> [CFG] Timeout de mouvement configurable
    M1SlipToleranceM                : REAL := 1.0;                    // --> [CFG] Tolerance glissement M1 pendant Busy (m)

    // === BYPASSES ET SIMULATION ===
    BypassGlobal                    : BOOL := FALSE;                  // --> [TST] Force ErrorId=0 global
END_VAR
VAR_OUTPUT
    // === ETATS IEC ET SYNOPTIQUE ===
    Ready                           : BOOL;                           // <-- [STAT] FB pret a fonctionner
    Status                          : ST_Status;                    // <-- [FB] Statut complet (Busy/Done/Error/ErrorId/State/StateAtError)

    // === DEMANDES ET ORDRES ACTIONNEURS ===
    CloseReq                        : BOOL;                           // <-- [STAT] Demande de fermeture memorisee
    OpenReq                         : BOOL;                           // <-- [STAT] Demande d'ouverture memorisee
    M2_StartStop                    : BOOL;                           // <-- [ACT] Ordre StartStop vers Winch M2
    M2_Direction                    : INT;                            // <-- [ACT] Ordre Direction vers Winch M2
    M2_ForceSlowSpeed               : BOOL;                           // <-- [ACT] Forcage vitesse lente sur M2

    // === DIAGNOSTICS ET MESURES ===
    M1SlipDetected                  : BOOL;                           // <-- [DIAG] Glissement M1 detecte
    ActiveOffsetM                   : REAL;                           // <-- [DIAG] Decalage cible pour FB_WinchSync
    DeltaPosition_M                 : REAL;                           // <-- [DIAG] Ecart reel signe M2 - M1 (m)
    RemainingTravelM                : REAL;                           // <-- [DIAG] Distance restante avant cible (m)
END_VAR
VAR_IN_OUT
    // === STRUCTURES DE DONNÉES PARTAGÉES ===
    BucketState                     : ST_BucketState;                 // <-> [BUS] Etat physique memorise du benne
END_VAR
VAR
    // === DETECTEURS ET TIMERS INTERNES ===
    ResetEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Reset
    ErrorEdge                       : R_TRIG;                         // . [LOC] Detecteur front montant Erreur
    BusyEdge                        : R_TRIG;                         // . [LOC] Detecteur entree en etat Busy
    ConfirmOpenEdge                 : R_TRIG;                         // . [LOC] Detecteur front confirmation ouverture
    ConfirmCloseEdge                : R_TRIG;                         // . [LOC] Detecteur front confirmation fermeture
    TonTimeout                      : TON;                            // . [LOC] Temporisateur timeout de mouvement

    // === VARIABLES LOCALES CALCULÉES ===
    FirstCycle                      : BOOL := TRUE;                  // . [LOC] Drapeau de premier cycle API
    SevereError                     : BOOL;                           // . [LOC] Erreur grave necessitant arret
    MaxAllowedOffset                : REAL;                           // . [LOC] Offset max calcule dynamiquement
    M1RefPosM                       : REAL;                           // . [LOC] Position M1 memorisee a l'entree Busy
    M2StartPosM                     : REAL;                           // . [LOC] Position M2 memorisee a l'entree Busy
    WasOpenAtStart                  : BOOL;                           // . [LOC] Etat IsOpen memorise a l'entree Busy
    WasClosedAtStart                : BOOL;                           // . [LOC] Etat IsClosed memorise a l'entree Busy
    LeftStartSinceArm               : BOOL;                           // . [LOC] Quitte position de depart
    HoldOffsetM                     : REAL;                           // . [LOC] Ecart reel mémorise (gel en position intermediaire)
END_VAR

{region "§1 Gate securite"}
// 🛑 1. GATE DE SÉCURITÉ
IF NOT Enable OR NOT PowerContactorEngaged THEN
    IF (Status.State = E_State.BUSY) OR CloseReq OR OpenReq THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
    Ready := FALSE;
    Status.Busy := FALSE;
    Status.Done := FALSE;
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_ForceSlowSpeed := FALSE;
    Status.State := E_State.DISABLED;
    M1SlipDetected := FALSE;
    // Les requêtes internes sont réinitialisées
    CloseReq := FALSE;
    OpenReq := FALSE;
    RETURN;
END_IF;

// 🟢 ÉTAT INITIAL READY SI DISABLED PRÉCÉDEMMENT
IF Status.State = E_State.DISABLED THEN
    Status.State := E_State.READY;
END_IF;

{endregion}

{region "§2 Reset et bypass"}
// 🔑 2. GESTION DU RESET (FRONT MONTANT)
ResetEdge(CLK := Reset);

// 🌐 BYPASS GLOBAL : force ErrorId = 0 (ignore toutes les erreurs benne)
IF BypassGlobal THEN
    Status.ErrorId := 16#0000;
END_IF;

IF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFA; // Efface les bits 0 et 2 (Timeout, Limites)
END_IF;

{endregion}

{region "§3 Coherence et etat mecanique benne"}
// 📏 3. DÉTECTION D'INCOHÉRENCE AU BOOT (PREMIER CYCLE API)
IF FirstCycle THEN
    FirstCycle := FALSE;
    IF Config.CoherenceLimitM > 0.01 THEN
        IF BucketState.IsOpen AND NOT BucketState.IsClosed THEN
            IF ABS(CablePosM2 - BucketState.LastPosM2Open) > Config.CoherenceLimitM THEN
                BucketState.StateIncoherent := TRUE;
            END_IF;
        ELSIF BucketState.IsClosed AND NOT BucketState.IsOpen THEN
            IF ABS(CablePosM2 - BucketState.LastPosM2Close) > Config.CoherenceLimitM THEN
                BucketState.StateIncoherent := TRUE;
            END_IF;
        ELSE
            // Si l'état n'a jamais été initialisé (les deux FALSE/TRUE), on signale une incohérence
            BucketState.StateIncoherent := TRUE;
        END_IF;
    ELSE
        // Limite non configurée ou invalide, par précaution on force l'incohérence
        BucketState.StateIncoherent := TRUE;
    END_IF;
END_IF;

// Met à jour le bit1 d'erreur si incohérence détectée
IF BucketState.StateIncoherent THEN
    Status.ErrorId := Status.ErrorId OR 16#0002;
    // Force l'état inconnu (ni ouvert ni fermé) si incohérence active
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;
ELSE
    Status.ErrorId := Status.ErrorId AND 16#FFFD;
END_IF;

// 🧲 3bis. GARDE-FOU CODEURS NON RÉFÉRENCÉS (bit 3)
// CablePosM1/CablePosM2 ne sont fiables que si le homing (Partie10) a été fait sur les 2 treuils.
// Continu (pas de front Reset) : se lève/efface tout seul selon l'état réel du homing.
IF NOT HomedM1 OR NOT HomedM2 THEN
    Status.ErrorId := Status.ErrorId OR 16#0008;
ELSE
    Status.ErrorId := Status.ErrorId AND 16#FFF7;
END_IF;

// 3bis-bis. CONFIRMATION MANUELLE POSITION OUVERTE — voir bandeau
// Action de CONFIRMATION (aucun mouvement, ne pilote pas M2) : acquitte les défauts et réinitialise
// les demandes. L'état IsOpen/IsClosed reste STRICTEMENT évalué en continu (§3bis-quater) selon la position codeur réelle.
ConfirmOpenEdge(CLK := ConfirmOpenPosition);
IF ConfirmOpenEdge.Q
   AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2)
   AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.LastPosM2Open := CablePosM2;
    BucketState.LastPosM2Close := CablePosM2 - Config.OffsetOpenM + Config.OffsetCloseM;
    Status.ErrorId := 16#0000;      // Réinitialisation complète des défauts benne lors du référencement manuel
    CloseReq := FALSE;              // Reset des demandes en attente pour éviter les démarrages intempestifs
    OpenReq := FALSE;
END_IF;

// 3bis-ter. CONFIRMATION MANUELLE POSITION FERMÉE
// Même principe que ConfirmOpenPosition pour acquitter et réinitialiser.
ConfirmCloseEdge(CLK := ConfirmClosePosition);
IF ConfirmCloseEdge.Q
   AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2)
   AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.LastPosM2Close := CablePosM2;
    BucketState.LastPosM2Open := CablePosM2 - Config.OffsetCloseM + Config.OffsetOpenM;
    Status.ErrorId := 16#0000;      // Réinitialisation complète des défauts benne lors du référencement manuel
    CloseReq := FALSE;              // Reset des demandes en attente pour éviter les démarrages intempestifs
    OpenReq := FALSE;
END_IF;

// 3bis-quater. DÉTECTION AUTOMATIQUE EN CONTINU (5 ZONES CLAIRES OPÉRATEUR) :
// Recalcule IsOpen, IsClosed, TooOpen, TooClosed, IsIntermediate en PERMANENCE à partir de
// l'écart réel Delta = CablePosM2 - CablePosM1 et de la tolérance Config.CoherenceLimitM.
// Actif à l'arrêt (NOT M1_Busy/M2_Busy), hors séquence active (State <> BUSY), codeurs référencés.
IF (Status.State <> E_State.BUSY) AND NOT M1_Busy AND NOT M2_Busy AND HomedM1 AND HomedM2
   AND (Config.CoherenceLimitM > 0.01) THEN

    // 1. Zone Benne Ouverte (Delta proche de OffsetOpenM)
    IF ABS((CablePosM2 - CablePosM1) - Config.OffsetOpenM) <= Config.CoherenceLimitM THEN
        BucketState.IsOpen := TRUE;
        BucketState.IsClosed := FALSE;
        BucketState.TooOpen := FALSE;
        BucketState.TooClosed := FALSE;
        BucketState.IsIntermediate := FALSE;
        BucketState.LastPosM2Open := CablePosM2;
        BucketState.StateIncoherent := FALSE;

    // 2. Zone Benne Fermée (Delta proche de OffsetCloseM)
    ELSIF ABS((CablePosM2 - CablePosM1) - Config.OffsetCloseM) <= Config.CoherenceLimitM THEN
        BucketState.IsClosed := TRUE;
        BucketState.IsOpen := FALSE;
        BucketState.TooOpen := FALSE;
        BucketState.TooClosed := FALSE;
        BucketState.IsIntermediate := FALSE;
        BucketState.LastPosM2Close := CablePosM2;
        BucketState.StateIncoherent := FALSE;

    // 3. Zone Trop Ouvert (Dépassement en ouverture : Delta < OffsetOpenM - Tolerance)
    ELSIF (CablePosM2 - CablePosM1) < (Config.OffsetOpenM - Config.CoherenceLimitM) THEN
        BucketState.IsOpen := FALSE;
        BucketState.IsClosed := FALSE;
        BucketState.TooOpen := TRUE;
        BucketState.TooClosed := FALSE;
        BucketState.IsIntermediate := FALSE;
        BucketState.StateIncoherent := TRUE;

    // 4. Zone Trop Fermé (Dépassement en fermeture : Delta > OffsetCloseM + Tolerance)
    ELSIF (CablePosM2 - CablePosM1) > (Config.OffsetCloseM + Config.CoherenceLimitM) THEN
        BucketState.IsOpen := FALSE;
        BucketState.IsClosed := FALSE;
        BucketState.TooOpen := FALSE;
        BucketState.TooClosed := TRUE;
        BucketState.IsIntermediate := FALSE;
        BucketState.StateIncoherent := TRUE;

    // 5. Zone Intermédiaire / Entrebâillée (entre OffsetOpenM + Tol et OffsetCloseM - Tol)
    ELSE
        BucketState.IsOpen := FALSE;
        BucketState.IsClosed := FALSE;
        BucketState.TooOpen := FALSE;
        BucketState.TooClosed := FALSE;
        BucketState.IsIntermediate := TRUE;
        BucketState.StateIncoherent := FALSE;
    END_IF;
END_IF;

// 🔍 3ter. MÉCA C COUCHE 1 — GLISSEMENT M1 PENDANT BUSY (bit4)
// M1 doit rester immobile pendant que M2 bouge seul. Référence prise à l'entrée en Busy.
BusyEdge(CLK := (Status.State = E_State.BUSY));
IF BusyEdge.Q THEN
    M1RefPosM := CablePosM1;
    M2StartPosM := CablePosM2;   // Borne le recul autorisé (voir §6 CASE BUSY)
    // Mémorise l'état d'origine (restauré si recul complet jusqu'à M2StartPosM, voir §6 CASE BUSY)
    // puis passe en position transitoire dès le démarrage du mouvement — ni ouvert ni fermé pendant
    // le trajet, quel que soit l'état mémorisé avant.
    WasOpenAtStart := BucketState.IsOpen;
    WasClosedAtStart := BucketState.IsClosed;
    LeftStartSinceArm := FALSE;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;
END_IF;

IF (Status.State = E_State.BUSY) AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM) AND NOT InhibitM1 THEN
    Status.ErrorId := Status.ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFEF;
END_IF;
M1SlipDetected := (Status.ErrorId AND 16#0010) <> 16#0000;

{endregion}

{region "§4 Surveillance limites timeout et arret"}
// 🚨 4. SURVEILLANCE DES LIMITES DE PLACEMENT (Limites dépassées - bit 2)
// On s'assure que l'écart réel M1/M2 ne dépasse pas les offsets de configuration + marge de sécurité de 1m
MaxAllowedOffset := MAX(ABS(Config.OffsetOpenM), ABS(Config.OffsetCloseM)) + 1.0;
IF (ABS(CablePosM1 - CablePosM2) > MaxAllowedOffset) AND NOT InhibitM1 AND NOT InhibitM2 THEN
    Status.ErrorId := Status.ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    Status.ErrorId := Status.ErrorId AND 16#FFFB;
END_IF;

// ⏲️ 5. SURVEILLANCE TIMEOUT MOUVEMENT (bit 0)
// Déclenche si le mouvement actif (M2_StartStop = TRUE) dure plus longtemps que le timeout
TonTimeout(IN := (Status.State = E_State.BUSY AND M2_StartStop), PT := CfgTimeoutDuration);
IF TonTimeout.Q THEN
    Status.ErrorId := Status.ErrorId OR 16#0001;
END_IF;

// ❌ Évaluation des erreurs graves (Timeout, Limites dépassées, Codeur(s) non référencé(s), ou Glissement M1)
SevereError := (Status.ErrorId AND 16#001D) <> 16#0000;

IF SevereError THEN
    IF (Status.State = E_State.BUSY) OR CloseReq OR OpenReq THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_ForceSlowSpeed := FALSE;
    CloseReq := FALSE;
    OpenReq := FALSE;
    // On repasse en READY et attend un Reset
    Status.State := E_State.READY;
END_IF;

{endregion}

{region "§5 Machine etat commande"}
// 🎛️ 6. MACHINE À ÉTATS DE COMMANDE
CASE Status.State OF
    E_State.READY:
        Ready := TRUE;
        Status.Busy := FALSE;
        Status.Done := FALSE;
        M2_StartStop := FALSE;
        M2_Direction := 0;
        M2_ForceSlowSpeed := FALSE;
        RemainingTravelM := 0.0; // Pas de mouvement en cours

        // Demande benne acceptée UNIQUEMENT si M1 ET M2 sont à l'arrêt (tous
        // modes) — évite qu'un mouvement en cours sur l'un des deux treuils "traverse" l'armement
        // du benne. Ni mémorisation de la requête, ni démarrage tant que ce
        // n'est pas vrai — l'opérateur doit refaire la demande une fois les treuils arrêtés.
        IF NOT M1_Busy AND NOT M2_Busy THEN
            // Mémorisation des requêtes IHM (l'une annule l'autre)
            IF CmdClose_IHM AND NOT SevereError THEN
                CloseReq := TRUE;
                OpenReq := FALSE;
            ELSIF CmdOpen_IHM AND NOT SevereError THEN
                OpenReq := TRUE;
                CloseReq := FALSE;
            END_IF;

            // Condition d'activation du mouvement (Requête IHM + Validation Joystick dans le bon sens)
            // Sens inversés (enroulage ferme, déroulage ouvre)
            IF CloseReq AND MotionRequestActive AND (MotionDirection = 1) THEN
                Status.State := E_State.BUSY;
            ELSIF OpenReq AND MotionRequestActive AND (MotionDirection = -1) THEN
                Status.State := E_State.BUSY;
            END_IF;
        END_IF;

    E_State.BUSY:
        Ready := TRUE;
        Status.Busy := TRUE;
        Status.Done := FALSE;
        M2_ForceSlowSpeed := TRUE; // Vitesse lente forcée sans contacteurs

        // Distance restante avant cible, pour affichage IHM (aiguille/jauge)
        // Toujours positive, décroît vers 0 à mesure que M2 approche la cible.
        IF CloseReq THEN
            RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
        ELSIF OpenReq THEN
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
        ELSE
            RemainingTravelM := 0.0;
        END_IF;

        // Interlock Homme-mort joystick
        // Sens inverse autorisé (recul/annulation partielle) pendant CloseReq/OpenReq, mais BORNÉ
        // à la position de départ (M2StartPosM, mémorisée à l'entrée en Busy) — ne permet jamais de
        // dépasser cette position dans le sens opposé au sens principal.
        IF NOT MotionRequestActive THEN
            // Si relâchement de l'intention opérateur, arrêt temporaire du mouvement.
            M2_StartStop := FALSE;
            M2_Direction := 0;
        ELSIF CloseReq THEN
            IF (MotionDirection = 1) THEN
                // Sens principal (fermeture) : M2 enroule (monte)
                M2_StartStop := TRUE;
                M2_Direction := 1;
            ELSIF (MotionDirection = -1) AND (CablePosM2 > M2StartPosM) THEN
                // Sens inverse : recul autorisé UNIQUEMENT tant qu'on n'est pas revenu à la position
                // de départ (pas au-delà, donc pas de ré-ouverture complète depuis ici)
                M2_StartStop := TRUE;
                M2_Direction := -1;
            ELSE
                // Mauvais sens, ou position de départ déjà atteinte en reculant : arrêt
                M2_StartStop := FALSE;
                M2_Direction := 0;
            END_IF;
        ELSIF OpenReq THEN
            IF (MotionDirection = -1) THEN
                // Sens principal (ouverture) : M2 déroule (descend)
                M2_StartStop := TRUE;
                M2_Direction := -1;
            ELSIF (MotionDirection = 1) AND (CablePosM2 < M2StartPosM) THEN
                // Sens inverse : recul autorisé UNIQUEMENT tant qu'on n'est pas revenu à la position
                // de départ (pas au-delà, donc pas de re-fermeture complète depuis ici)
                M2_StartStop := TRUE;
                M2_Direction := 1;
            ELSE
                M2_StartStop := FALSE;
                M2_Direction := 0;
            END_IF;
        ELSE
            M2_StartStop := FALSE;
            M2_Direction := 0;
        END_IF;

        // Détecte qu'on a réellement quitté la position de départ (évite que le test de retour
        // ci-dessous ne se déclenche instantanément au 1er cycle de Busy, où CablePosM2 =
        // M2StartPosM par définition).
        IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
            LeftStartSinceArm := TRUE;
        END_IF;

        // Condition d'arrêt automatique de la fermeture
        IF CloseReq THEN
            // Compense l'inertie mécanique (coast-down) : coupe la commande
            // CloseAnticipationM avant OffsetCloseM pour amener l'arrêt réel près du
            // vrai offset au lieu de le dépasser.
            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM - Config.CloseAnticipationM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                // Mémorisation de l'état physique fermé
                BucketState.IsOpen := FALSE;
                BucketState.IsClosed := TRUE;
                BucketState.LastPosM2Close := CablePosM2;
                BucketState.StateIncoherent := FALSE; // recalage réussi

                CloseReq := FALSE;
                Status.State := E_State.DONE;
            // Recul complet jusqu'à la position de départ — restaure l'état d'origine
            // (physiquement, on est revenu là où on a commencé)
            ELSIF LeftStartSinceArm AND (CablePosM2 <= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;

                CloseReq := FALSE;
                Status.State := E_State.DONE;
            END_IF;
        END_IF;

        // Condition d'arrêt automatique de l'ouverture
        IF OpenReq THEN
            // Même logique que la fermeture ci-dessus, inertie différente en ouverture
            // (OpenAnticipationM distinct).
            IF CablePosM2 <= (CablePosM1 + Config.OffsetOpenM + Config.OpenAnticipationM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                // Mémorisation de l'état physique ouvert
                BucketState.IsOpen := TRUE;
                BucketState.IsClosed := FALSE;
                BucketState.LastPosM2Open := CablePosM2;
                BucketState.StateIncoherent := FALSE; // recalage réussi

                OpenReq := FALSE;
                Status.State := E_State.DONE;
            // Recul complet jusqu'à la position de départ — restaure l'état d'origine
            // (physiquement, on est revenu là où on a commencé)
            ELSIF LeftStartSinceArm AND (CablePosM2 >= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;

                OpenReq := FALSE;
                Status.State := E_State.DONE;
            END_IF;
        END_IF;

    E_State.DONE:
        Ready := TRUE;
        Status.Busy := FALSE;
        Status.Done := TRUE;
        M2_StartStop := FALSE;
        M2_Direction := 0;
        M2_ForceSlowSpeed := FALSE;
        RemainingTravelM := 0.0; // Cible atteinte

        // Attente du relâchement de la validation joystick pour repasser à READY
        IF NOT MotionRequestActive THEN
            Status.State := E_State.READY;
        END_IF;
END_CASE;

// 📤 7. GESTION DES SORTIES D'ÉTAT GLOBALES
Status.Error := (Status.ErrorId <> 16#0000);
ErrorEdge(CLK := Status.Error);
IF ErrorEdge.Q THEN
    Status.StateAtError := Status.State;
END_IF;

// Calcul continu de l'écart réel signé M2 - M1 pour l'affichage IHM et l'aide au pilotage
DeltaPosition_M := CablePosM2 - CablePosM1;

// Détermination de l'offset actif pour le synchronisme de FB_WinchSync ET pour l'affichage IHM
// (M2PositionCorrected, côté PRG_07_Supervision).
// CloseReq/OpenReq sont pris en compte (pas seulement IsClosed/IsOpen, qui sont FALSE pendant
// TOUT le trajet depuis l'état transitoire) pour que la position corrigée de M2 converge
// progressivement vers M1 pendant l'enroulage.
IF Status.State = E_State.BUSY THEN
    // Pendant le déplacement, l'offset actif suit la différence réelle de câble (M2 - M1) afin que
    // la position corrigée de M2 reste stable (égale à M1, cad la hauteur du benne) sans à-coup,
    // tandis que le câble brut de M2 montre son enroulement.
    ActiveOffsetM := CablePosM2 - CablePosM1;
    HoldOffsetM := ActiveOffsetM;   // Mémorise l'écart réel pour le gel en position intermédiaire
ELSIF CloseReq OR BucketState.IsClosed THEN
    ActiveOffsetM := Config.OffsetCloseM;
    HoldOffsetM := ActiveOffsetM;
ELSIF OpenReq OR BucketState.IsOpen THEN
    ActiveOffsetM := Config.OffsetOpenM;
    HoldOffsetM := ActiveOffsetM;
ELSE
    // Position intermédiaire non référencée : gèle l'écart réel mémorisé (HoldOffsetM) au lieu de
    // sauter vers la config. Évite l'à-coup sur la position corrigée M2 / la synchro.
    ActiveOffsetM := HoldOffsetM;
END_IF;

{endregion}
