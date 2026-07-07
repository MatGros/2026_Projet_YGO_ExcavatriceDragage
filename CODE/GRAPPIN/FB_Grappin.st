(* ═══════════════════════════════════════════════════════════════
   🪣 FB_Grappin — Commande d'ouverture/fermeture du grappin
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie12_Fonction_Grappin_v1.1.md
   🔌 Conforme au contrat FB standard (Partie3 §1bis).
   ⚠️ REX 2026-07-07 : inversion du sens moteur M2 constatée sur site
      (ré-câblage/relabel %Q0.0 et %Q0.3) → ENROULAGE M2 (Direction=+1)
      FERME désormais le grappin, DEROULAGE M2 (Direction=-1) l'OUVRE
      (c'était l'inverse avant). Voir Partie12 v1.1 §REX.
   ⚠️ REX 2026-07-07 (2) : ajout du garde-fou HomedM1/HomedM2 — CablePosM1/M2
      ne sont fiables que si les codeurs absolus sont référencés (Partie10).
      Sans ça, une position aberrante (codeur non homé) pourrait faire
      mémoriser un IsOpen/IsClosed faux dès l'entrée en BUSY.
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Grappin
VAR_INPUT
    Enable              : BOOL;             // Activation générale
    Reset               : BOOL;             // Acquittement défauts (front)
    EmergencyStopOk     : BOOL;             // Condition d'arrêt d'urgence
    Mode                : E_Mode;           // Mode de marche machine
    CmdOpen_IHM         : BOOL;             // Demande d'ouverture depuis l'IHM
    CmdClose_IHM        : BOOL;             // Demande de fermeture depuis l'IHM
    JoystickY_StartStop : BOOL;             // Homme-mort joystick (AxisCmdY.StartStop)
    JoystickY_Direction : INT;              // Sens joystick (AxisCmdY.Direction : 1=montée, -1=descente)
    CablePosM1          : REAL;             // Position réelle câble treuil M1 (mètres)
    CablePosM2          : REAL;             // Position réelle câble treuil M2 (mètres)
    HomedM1             : BOOL;             // Codeur M1 référencé (instHomingM1.Homed) — REX 2026-07-07
    HomedM2             : BOOL;             // Codeur M2 référencé (instHomingM2.Homed) — REX 2026-07-07
    Config              : ST_GrappinConfig; // Configuration (RETAIN site)
    TimeoutDuration     : TIME := T#30s;    // Timeout de mouvement configurable
END_VAR
VAR_OUTPUT
    Ready               : BOOL;             // FB prêt à fonctionner
    Busy                : BOOL;             // Mouvement en cours
    Done                : BOOL;             // Mouvement terminé avec succès
    Error               : BOOL;             // Présence d'un défaut
    ErrorId             : WORD;             // bit0: Timeout mouvement, bit1: Incohérence boot, bit2: Limites dépassées, bit3: Codeur(s) M1/M2 non référencé(s)
    State               : E_State;          // État opérationnel du FB
    StateAtError        : E_State;          // État lors de l'apparition de l'erreur
    ActiveOffsetM       : REAL;             // Décalage cible à injecter dans FB_WinchSync
    M2_StartStop        : BOOL;             // Sortie consigne StartStop vers Winch M2
    M2_Direction        : INT;              // Sortie consigne Direction vers Winch M2
    M2_ForceSlowSpeed   : BOOL;             // TRUE = Bloque les contacteurs de vitesse de M2
    RemainingTravelM    : REAL;             // 🔧 REX 2026-07-07 : distance restante avant cible (m, toujours
                                             // positive, décroît vers 0) — 0.0 hors mouvement (READY/DONE)
END_VAR
VAR_IN_OUT
    GrappinState        : ST_GrappinState;  // État physique du grappin mémorisé (RETAIN)
END_VAR
VAR
    FirstCycle          : BOOL := TRUE;     // Drapeau de premier cycle API
    ResetEdge           : R_TRIG;           // Détecteur de front montant Reset
    ErrorEdge           : R_TRIG;           // Détecteur de front montant Error
    TonTimeout          : TON;              // Temporisateur de timeout de mouvement
    CloseReq            : BOOL;             // Demande de fermeture mémorisée
    OpenReq             : BOOL;             // Demande d'ouverture mémorisée
    SevereError         : BOOL;             // Erreur grave nécessitant l'arrêt
    MaxAllowedOffset    : REAL;             // Offset max calculé dynamiquement
END_VAR

// 🛑 1. GATE DE SÉCURITÉ
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_ForceSlowSpeed := FALSE;
    State := E_State.DISABLED;
    // Les requêtes internes sont réinitialisées
    CloseReq := FALSE;
    OpenReq := FALSE;
    RETURN;
END_IF;

// 🟢 ÉTAT INITIAL READY SI DISABLED PRÉCÉDEMMENT
IF State = E_State.DISABLED THEN
    State := E_State.READY;
END_IF;

// 🔑 2. GESTION DU RESET (FRONT MONTANT)
ResetEdge(CLK := Reset);
IF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFA; // Efface les bits 0 et 2 (Timeout, Limites)
END_IF;

// 📏 3. DÉTECTION D'INCOHÉRENCE AU BOOT (PREMIER CYCLE API)
IF FirstCycle THEN
    FirstCycle := FALSE;
    IF Config.CoherenceLimitM > 0.01 THEN
        IF GrappinState.IsOpen AND NOT GrappinState.IsClosed THEN
            IF ABS(CablePosM2 - GrappinState.LastPosM2Open) > Config.CoherenceLimitM THEN
                GrappinState.StateIncoherent := TRUE;
            END_IF;
        ELSIF GrappinState.IsClosed AND NOT GrappinState.IsOpen THEN
            IF ABS(CablePosM2 - GrappinState.LastPosM2Close) > Config.CoherenceLimitM THEN
                GrappinState.StateIncoherent := TRUE;
            END_IF;
        ELSE
            // Si l'état n'a jamais été initialisé (les deux FALSE/TRUE), on signale une incohérence
            GrappinState.StateIncoherent := TRUE;
        END_IF;
    ELSE
        // Limite non configurée ou invalide, par précaution on force l'incohérence
        GrappinState.StateIncoherent := TRUE;
    END_IF;
END_IF;

// Met à jour le bit1 d'erreur si incohérence détectée
IF GrappinState.StateIncoherent THEN
    ErrorId := ErrorId OR 16#0002;
ELSE
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 🧲 3bis. GARDE-FOU CODEURS NON RÉFÉRENCÉS (bit 3) — REX 2026-07-07
// CablePosM1/CablePosM2 ne sont fiables que si le homing (Partie10) a été fait sur les 2 treuils.
// Continu (pas de front Reset) : se lève/efface tout seul selon l'état réel du homing.
IF NOT HomedM1 OR NOT HomedM2 THEN
    ErrorId := ErrorId OR 16#0008;
ELSE
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🚨 4. SURVEILLANCE DES LIMITES DE PLACEMENT (Limites dépassées - bit 2)
// On s'assure que l'écart réel M1/M2 ne dépasse pas les offsets de configuration + marge de sécurité de 1m
MaxAllowedOffset := MAX(ABS(Config.OffsetOpenM), ABS(Config.OffsetCloseM)) + 1.0;
IF ABS(CablePosM1 - CablePosM2) > MaxAllowedOffset THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// ⏲️ 5. SURVEILLANCE TIMEOUT MOUVEMENT (bit 0)
// Déclenche si le mouvement actif (M2_StartStop = TRUE) dure plus longtemps que le timeout
TonTimeout(IN := (State = E_State.BUSY AND M2_StartStop), PT := TimeoutDuration);
IF TonTimeout.Q THEN
    ErrorId := ErrorId OR 16#0001;
END_IF;

// ❌ Évaluation des erreurs graves (Timeout, Limites dépassées, ou Codeur(s) non référencé(s))
SevereError := (ErrorId AND 16#000D) <> 16#0000;

IF SevereError THEN
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_ForceSlowSpeed := FALSE;
    CloseReq := FALSE;
    OpenReq := FALSE;
    // On repasse en READY et attend un Reset
    State := E_State.READY;
END_IF;

// 🎛️ 6. MACHINE À ÉTATS DE COMMANDE
CASE State OF
    E_State.READY:
        Ready := TRUE;
        Busy := FALSE;
        Done := FALSE;
        M2_StartStop := FALSE;
        M2_Direction := 0;
        M2_ForceSlowSpeed := FALSE;
        RemainingTravelM := 0.0; // 🔧 REX 2026-07-07 : pas de mouvement en cours

        // Mémorisation des requêtes IHM (l'une annule l'autre)
        IF CmdClose_IHM AND NOT SevereError THEN
            CloseReq := TRUE;
            OpenReq := FALSE;
        ELSIF CmdOpen_IHM AND NOT SevereError THEN
            OpenReq := TRUE;
            CloseReq := FALSE;
        END_IF;

        // Condition d'activation du mouvement (Requête IHM + Validation Joystick dans le bon sens)
        // ⚠️ REX 2026-07-07 : sens inversés (enroulage ferme désormais, déroulage ouvre)
        IF CloseReq AND JoystickY_StartStop AND (JoystickY_Direction = 1) THEN
            State := E_State.BUSY;
        ELSIF OpenReq AND JoystickY_StartStop AND (JoystickY_Direction = -1) THEN
            State := E_State.BUSY;
        END_IF;

    E_State.BUSY:
        Ready := TRUE;
        Busy := TRUE;
        Done := FALSE;
        M2_ForceSlowSpeed := TRUE; // Vitesse lente forcée sans contacteurs

        // 📏 REX 2026-07-07 : distance restante avant cible, pour affichage IHM (aiguille/jauge)
        // Toujours positive, décroît vers 0 à mesure que M2 approche la cible.
        IF CloseReq THEN
            RemainingTravelM := MAX(0.0, (CablePosM1 + Config.OffsetCloseM) - CablePosM2);
        ELSIF OpenReq THEN
            RemainingTravelM := MAX(0.0, CablePosM2 - (CablePosM1 + Config.OffsetOpenM));
        ELSE
            RemainingTravelM := 0.0;
        END_IF;

        // Interlock Homme-mort joystick
        IF NOT JoystickY_StartStop THEN
            // Si relâchement du joystick, arrêt temporaire du mouvement
            M2_StartStop := FALSE;
            M2_Direction := 0;
        ELSIF CloseReq AND (JoystickY_Direction = 1) THEN
            // Fermeture en cours : M2 enroule (monte) — REX 2026-07-07
            M2_StartStop := TRUE;
            M2_Direction := 1;
        ELSIF OpenReq AND (JoystickY_Direction = -1) THEN
            // Ouverture en cours : M2 déroule (descend) — REX 2026-07-07
            M2_StartStop := TRUE;
            M2_Direction := -1;
        ELSE
            // Joystick poussé dans la mauvaise direction pour la requête active : arrêt
            M2_StartStop := FALSE;
            M2_Direction := 0;
        END_IF;

        // Condition d'arrêt automatique de la fermeture
        IF CloseReq THEN
            // Cible atteinte : M2 a assez enroulé (CablePosM2 croissant) — REX 2026-07-07
            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                
                // Mémorisation de l'état physique fermé
                GrappinState.IsOpen := FALSE;
                GrappinState.IsClosed := TRUE;
                GrappinState.LastPosM2Close := CablePosM2;
                GrappinState.StateIncoherent := FALSE; // recalage réussi
                
                CloseReq := FALSE;
                State := E_State.DONE;
            END_IF;
        END_IF;

        // Condition d'arrêt automatique de l'ouverture
        IF OpenReq THEN
            // Cible atteinte : M2 a assez déroulé (CablePosM2 décroissant) — REX 2026-07-07
            IF CablePosM2 <= (CablePosM1 + Config.OffsetOpenM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;
                
                // Mémorisation de l'état physique ouvert
                GrappinState.IsOpen := TRUE;
                GrappinState.IsClosed := FALSE;
                GrappinState.LastPosM2Open := CablePosM2;
                GrappinState.StateIncoherent := FALSE; // recalage réussi
                
                OpenReq := FALSE;
                State := E_State.DONE;
            END_IF;
        END_IF;

    E_State.DONE:
        Ready := TRUE;
        Busy := FALSE;
        Done := TRUE;
        M2_StartStop := FALSE;
        M2_Direction := 0;
        M2_ForceSlowSpeed := FALSE;
        RemainingTravelM := 0.0; // 🔧 REX 2026-07-07 : cible atteinte

        // Attente du relâchement de la validation joystick pour repasser à READY
        IF NOT JoystickY_StartStop THEN
            State := E_State.READY;
        END_IF;
END_CASE;

// 📤 7. GESTION DES SORTIES D'ÉTAT GLOBALES
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// Détermination de l'offset actif pour le synchronisme de FB_WinchSync
IF GrappinState.IsClosed THEN
    ActiveOffsetM := Config.OffsetCloseM;
ELSE
    // Par défaut ou si ouvert, on applique l'offset ouvert
    ActiveOffsetM := Config.OffsetOpenM;
END_IF;
