(* ═══════════════════════════════════════════════════════════════
   🪣 FB_Bucket — Commande d'ouverture/fermeture du benne
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie12_Fonction_Benne_v1.1.md
   🔌 Conforme au contrat FB standard (Partie3 §1bis).
   ⚠️ REX 2026-07-07 : inversion du sens moteur M2 constatée sur site
      (ré-câblage/relabel %Q0.0 et %Q0.3) → ENROULAGE M2 (Direction=+1)
      FERME désormais le benne, DEROULAGE M2 (Direction=-1) l'OUVRE
      (c'était l'inverse avant). Voir Partie12 v1.1 §REX.
   ⚠️ REX 2026-07-07 (2) : ajout du garde-fou HomedM1/HomedM2 — CablePosM1/M2
      ne sont fiables que si les codeurs absolus sont référencés (Partie10).
      Sans ça, une position aberrante (codeur non homé) pourrait faire
      mémoriser un IsOpen/IsClosed faux dès l'entrée en BUSY.
   🔧 REX 2026-07-07 (3) : Méca C couche 1 (bit4) — M1 DOIT rester immobile pendant
      que M2 bouge seul. Si M1 glisse de plus de M1SlipToleranceM (1.0 m) pendant
      BUSY → SevereError (coupe M2 via le mécanisme existant) + sortie dédiée
      M1SlipDetected (à consommer côté PRG_06_WinchControl pour forcer SafeStop
      sur M1 spécifiquement — FB_Bucket ne pilote pas M1). Couche de secours si
      cette couche ne suffit pas : voir FB_Safety_Winch bit9 (tolérance 2.0 m,
      escalade PowerCutOff).
   🆕 REX 2026-07-08 (mise en service, demande utilisateur) :
      - `ConfirmOpenPosition` : bouton IHM dédié de RÉFÉRENCEMENT du benne en position ouverte
        (mise en service). Action de CONFIRMATION pure (aucun mouvement) — mémorise
        BucketState.IsOpen directement, à utiliser juste après le référencement des codeurs
        M1/M2 (les 2 à la même valeur, benne physiquement ouvert vérifié par l'opérateur —
        voir DOC/AF_Partie10_Fonction_Encoder_Homing_v1.7.md "flux nominal, benne ouvert").
        Remplace le contournement précédent (un CmdOpen qui se terminait par coïncidence car la
        cible était déjà atteinte) par une action explicite et auditable. Même principe que
        `ConfirmCoherence` dans FB_Encoder_Homing (front, gardée par Mode MAINT_N1/N2).
   🆕 REX 2026-07-08 (audit sécurité, demande utilisateur) :
      - `M1_Busy`/`M2_Busy` : la demande d'ouverture/fermeture n'est acceptée (mémorisation
        `CloseReq`/`OpenReq` + transition vers BUSY) QUE si les deux treuils sont à l'arrêt —
        tous modes. Avant ce correctif, rien ne le garantissait ; un mouvement manuel sur M1
        pouvait "traverser" l'armement du benne (trou détecté par audit automatisme/IHM).
      - Sens inverse borné pendant BUSY : l'opérateur peut désormais pousser le joystick dans
        le sens opposé au sens principal (recul/annulation partielle), mais UNIQUEMENT jusqu'à
        la position M2 mémorisée au démarrage de la demande (`M2StartPosM`) — jamais au-delà
        (pas de réouverture/refermeture complète depuis ce sens inverse).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Bucket
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
    Config              : ST_BucketConfig; // Configuration (RETAIN site)
    TimeoutDuration     : TIME := T#30s;    // Timeout de mouvement configurable
    M1SlipToleranceM    : REAL := 1.0;      // 🔧 REX 2026-07-07 : tolérance glissement M1 pendant Busy (m)
    M1_Busy             : BOOL;             // 🆕 REX 2026-07-08 : instWinchM1.Busy — doit être à l'arrêt pour armer une demande
    M2_Busy             : BOOL;             // 🆕 REX 2026-07-08 : instWinchM2.Busy — doit être à l'arrêt pour armer une demande
     ConfirmOpenPosition : BOOL;             // 🆕 REX 2026-07-08 : bouton IHM référencement benne ouvert (front, mise en service — voir bandeau)
     ConfirmClosePosition : BOOL;            // 🆕 REX 2026-07-08 : bouton IHM référencement benne fermé (front, mise en service)
     InhibitM1           : BOOL;             // 🆕 REX 2026-07-08 : M1 est inhibé
     InhibitM2           : BOOL;             // 🆕 REX 2026-07-08 : M2 est inhibé
 END_VAR
VAR_OUTPUT
    Ready               : BOOL;             // FB prêt à fonctionner
    Busy                : BOOL;             // Mouvement en cours
    Done                : BOOL;             // Mouvement terminé avec succès
    Error               : BOOL;             // Présence d'un défaut
    ErrorId             : WORD;             // bit0: "Timeout mouvement benne" - Timeout mouvement, bit1: "Incohérence position benne" - Incohérence boot, bit2: "Limites placement benne dépassées" - Limites dépassées, bit3: "Codeur(s) benne non référencé(s)" - Codeur(s) M1/M2 non référencé(s), bit4: "Glissement M1 détecté" - Glissement M1 pendant Busy
    M1SlipDetected      : BOOL;             // 🔧 REX 2026-07-07 : à consommer côté PRG_06_WinchControl (force SafeStop M1)
    CloseReq            : BOOL;             // 🆕 REX 2026-07-08 : demande de fermeture mémorisée — image IHM (FALSE = pas de demande active
                                             // ou objectif atteint/retour position départ ; TRUE = demande armée ou mouvement en cours)
    OpenReq             : BOOL;             // 🆕 REX 2026-07-08 : demande d'ouverture mémorisée — même principe
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
    BucketState        : ST_BucketState;  // État physique du benne mémorisé (RETAIN)
END_VAR
VAR
    FirstCycle          : BOOL := TRUE;     // Drapeau de premier cycle API
    ResetEdge           : R_TRIG;           // Détecteur de front montant Reset
    ErrorEdge           : R_TRIG;           // Détecteur de front montant Error
    TonTimeout          : TON;              // Temporisateur de timeout de mouvement
    SevereError         : BOOL;             // Erreur grave nécessitant l'arrêt
    MaxAllowedOffset    : REAL;             // Offset max calculé dynamiquement
    BusyEdge            : R_TRIG;           // 🔧 REX 2026-07-07 — détecte l'entrée en Busy (arme la réf. M1)
    M1RefPosM           : REAL;             // 🔧 REX 2026-07-07 — position M1 mémorisée à l'entrée en Busy
    M2StartPosM         : REAL;             // 🆕 REX 2026-07-08 — position M2 mémorisée à l'entrée en Busy (borne le recul autorisé)
    WasOpenAtStart      : BOOL;             // 🆕 REX 2026-07-08 — état IsOpen mémorisé à l'entrée en Busy (restauré si recul complet)
    WasClosedAtStart    : BOOL;             // 🆕 REX 2026-07-08 — état IsClosed mémorisé à l'entrée en Busy (restauré si recul complet)
    LeftStartSinceArm   : BOOL;             // 🆕 REX 2026-07-08 — a réellement quitté la position de départ (évite un retour instantané au 1er cycle Busy)
    ConfirmOpenEdge     : R_TRIG;           // 🆕 REX 2026-07-08 — détecteur de front ConfirmOpenPosition
    ConfirmCloseEdge    : R_TRIG;           // 🆕 REX 2026-07-08 — détecteur de front ConfirmClosePosition
END_VAR

// 🛑 1. GATE DE SÉCURITÉ
IF NOT Enable OR NOT EmergencyStopOk THEN
    IF (State = E_State.BUSY) OR CloseReq OR OpenReq THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
    Ready := FALSE;
    Busy := FALSE;
    Done := FALSE;
    M2_StartStop := FALSE;
    M2_Direction := 0;
    M2_ForceSlowSpeed := FALSE;
    State := E_State.DISABLED;
    M1SlipDetected := FALSE; // 🔧 REX 2026-07-07
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
    ErrorId := ErrorId OR 16#0002;
    // 🆕 REX 2026-07-08 : Force l'état inconnu (ni ouvert ni fermé) si incohérence active
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;
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

// 🆕 3bis-bis. CONFIRMATION MANUELLE POSITION OUVERTE (mise en service, REX 2026-07-08) — voir bandeau
// Action de CONFIRMATION pure (aucun mouvement, ne pilote pas M2) : mémorise BucketState.IsOpen
// directement, à utiliser juste après le référencement des codeurs (M1=M2, benne physiquement
// ouvert vérifié par l'opérateur). Gardée comme ConfirmCoherence (FB_Encoder_Homing) : front,
// MAINT_N1/N2 uniquement, codeurs déjà référencés, treuils à l'arrêt (pas de séquence en cours).
ConfirmOpenEdge(CLK := ConfirmOpenPosition);
IF ConfirmOpenEdge.Q
   AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2)
   AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.IsOpen := TRUE;
    BucketState.IsClosed := FALSE;
    BucketState.LastPosM2Open := CablePosM2;
    BucketState.LastPosM2Close := CablePosM2 - Config.OffsetOpenM + Config.OffsetCloseM; // 🆕 Initialisation théorique cohérente avec les offsets configurés
    BucketState.StateIncoherent := FALSE;
    ErrorId := 16#0000;             // 🆕 REX 2026-07-08 : Réinitialisation complète des défauts benne lors du référencement manuel
    CloseReq := FALSE;              // 🆕 REX 2026-07-08 : Reset des demandes en attente pour éviter les démarrages intempestifs
    OpenReq := FALSE;
END_IF;

// 🆕 3bis-ter. CONFIRMATION MANUELLE POSITION FERMÉE (mise en service, REX 2026-07-08)
// Même principe que ConfirmOpenPosition, mais pour initialiser le benne comme FERMÉ.
ConfirmCloseEdge(CLK := ConfirmClosePosition);
IF ConfirmCloseEdge.Q
   AND (Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2)
   AND NOT M1_Busy AND NOT M2_Busy THEN
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := TRUE;
    BucketState.LastPosM2Close := CablePosM2;
    BucketState.LastPosM2Open := CablePosM2 - Config.OffsetCloseM + Config.OffsetOpenM; // 🆕 Initialisation théorique cohérente avec les offsets configurés
    BucketState.StateIncoherent := FALSE;
    ErrorId := 16#0000;             // 🆕 REX 2026-07-08 : Réinitialisation complète des défauts benne lors du référencement manuel
    CloseReq := FALSE;              // 🆕 REX 2026-07-08 : Reset des demandes en attente pour éviter les démarrages intempestifs
    OpenReq := FALSE;
END_IF;

// 🔍 3ter. MÉCA C COUCHE 1 — GLISSEMENT M1 PENDANT BUSY (bit4) — REX 2026-07-07
// M1 doit rester immobile pendant que M2 bouge seul. Référence prise à l'entrée en Busy.
BusyEdge(CLK := (State = E_State.BUSY));
IF BusyEdge.Q THEN
    M1RefPosM := CablePosM1;
    M2StartPosM := CablePosM2;   // 🆕 REX 2026-07-08 — borne le recul autorisé (voir §6 CASE BUSY)
    // 🆕 REX 2026-07-08 (demande utilisateur) : mémorise l'état d'origine (restauré si recul complet
    // jusqu'à M2StartPosM, voir §6 CASE BUSY) puis passe en position transitoire dès le démarrage du
    // mouvement — ni ouvert ni fermé pendant le trajet, quel que soit l'état mémorisé avant.
    WasOpenAtStart := BucketState.IsOpen;
    WasClosedAtStart := BucketState.IsClosed;
    LeftStartSinceArm := FALSE;
    BucketState.IsOpen := FALSE;
    BucketState.IsClosed := FALSE;
END_IF;

IF (State = E_State.BUSY) AND (ABS(CablePosM1 - M1RefPosM) > M1SlipToleranceM) AND NOT InhibitM1 THEN
    ErrorId := ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFEF;
END_IF;
M1SlipDetected := (ErrorId AND 16#0010) <> 16#0000;

// 🚨 4. SURVEILLANCE DES LIMITES DE PLACEMENT (Limites dépassées - bit 2)
// On s'assure que l'écart réel M1/M2 ne dépasse pas les offsets de configuration + marge de sécurité de 1m
MaxAllowedOffset := MAX(ABS(Config.OffsetOpenM), ABS(Config.OffsetCloseM)) + 1.0;
IF (ABS(CablePosM1 - CablePosM2) > MaxAllowedOffset) AND NOT InhibitM1 AND NOT InhibitM2 THEN
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

// ❌ Évaluation des erreurs graves (Timeout, Limites dépassées, Codeur(s) non référencé(s), ou Glissement M1)
SevereError := (ErrorId AND 16#001D) <> 16#0000;

IF SevereError THEN
    IF (State = E_State.BUSY) OR CloseReq OR OpenReq THEN
        BucketState.StateIncoherent := TRUE;
    END_IF;
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

        // 🆕 REX 2026-07-08 : demande benne acceptée UNIQUEMENT si M1 ET M2 sont à l'arrêt (tous
        // modes) — évite qu'un mouvement en cours sur l'un des deux treuils "traverse" l'armement
        // du benne (audit sécurité). Ni mémorisation de la requête, ni démarrage tant que ce
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
            // ⚠️ REX 2026-07-07 : sens inversés (enroulage ferme désormais, déroulage ouvre)
            IF CloseReq AND JoystickY_StartStop AND (JoystickY_Direction = 1) THEN
                State := E_State.BUSY;
            ELSIF OpenReq AND JoystickY_StartStop AND (JoystickY_Direction = -1) THEN
                State := E_State.BUSY;
            END_IF;
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
        // 🆕 REX 2026-07-08 : sens inverse autorisé (recul/annulation partielle) pendant CloseReq/
        // OpenReq, mais BORNÉ à la position de départ (M2StartPosM, mémorisée à l'entrée en Busy) —
        // ne permet jamais de dépasser cette position dans le sens opposé au sens principal.
        IF NOT JoystickY_StartStop THEN
            // Si relâchement du joystick, arrêt temporaire du mouvement
            M2_StartStop := FALSE;
            M2_Direction := 0;
        ELSIF CloseReq THEN
            IF (JoystickY_Direction = 1) THEN
                // Sens principal (fermeture) : M2 enroule (monte) — REX 2026-07-07
                M2_StartStop := TRUE;
                M2_Direction := 1;
            ELSIF (JoystickY_Direction = -1) AND (CablePosM2 > M2StartPosM) THEN
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
            IF (JoystickY_Direction = -1) THEN
                // Sens principal (ouverture) : M2 déroule (descend) — REX 2026-07-07
                M2_StartStop := TRUE;
                M2_Direction := -1;
            ELSIF (JoystickY_Direction = 1) AND (CablePosM2 < M2StartPosM) THEN
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

        // 🆕 REX 2026-07-08 : détecte qu'on a réellement quitté la position de départ (évite que le
        // test de retour ci-dessous ne se déclenche instantanément au 1er cycle de Busy, où
        // CablePosM2 = M2StartPosM par définition).
        IF (CloseReq AND (CablePosM2 > M2StartPosM)) OR (OpenReq AND (CablePosM2 < M2StartPosM)) THEN
            LeftStartSinceArm := TRUE;
        END_IF;

        // Condition d'arrêt automatique de la fermeture
        IF CloseReq THEN
            // Cible atteinte : M2 a assez enroulé (CablePosM2 croissant) — REX 2026-07-07
            IF CablePosM2 >= (CablePosM1 + Config.OffsetCloseM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                // Mémorisation de l'état physique fermé
                BucketState.IsOpen := FALSE;
                BucketState.IsClosed := TRUE;
                BucketState.LastPosM2Close := CablePosM2;
                BucketState.StateIncoherent := FALSE; // recalage réussi

                CloseReq := FALSE;
                State := E_State.DONE;
            // 🆕 REX 2026-07-08 (demande utilisateur) : recul complet jusqu'à la position de départ —
            // restaure l'état d'origine (physiquement, on est revenu là où on a commencé)
            ELSIF LeftStartSinceArm AND (CablePosM2 <= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;

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
                BucketState.IsOpen := TRUE;
                BucketState.IsClosed := FALSE;
                BucketState.LastPosM2Open := CablePosM2;
                BucketState.StateIncoherent := FALSE; // recalage réussi

                OpenReq := FALSE;
                State := E_State.DONE;
            // 🆕 REX 2026-07-08 (demande utilisateur) : recul complet jusqu'à la position de départ —
            // restaure l'état d'origine (physiquement, on est revenu là où on a commencé)
            ELSIF LeftStartSinceArm AND (CablePosM2 >= M2StartPosM) THEN
                M2_StartStop := FALSE;
                M2_Direction := 0;

                BucketState.IsOpen := WasOpenAtStart;
                BucketState.IsClosed := WasClosedAtStart;

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

// Détermination de l'offset actif pour le synchronisme de FB_WinchSync ET pour l'affichage IHM
// (M2PositionCorrected, côté PRG_09_Supervision).
// 🔧 REX 2026-07-08 : ajout de CloseReq/OpenReq (pas seulement IsClosed/IsOpen, qui sont FALSE
// pendant TOUT le trajet depuis le REX du 2026-07-08 sur l'état transitoire) — sinon
// ActiveOffsetM restait figé sur OffsetOpenM (défaut) pendant le trajet entier d'une fermeture,
// donc M2PositionCorrected = CablePosM2 brut tout du long, avec un saut brutal uniquement à
// l'arrivée (constat terrain) au lieu de converger progressivement vers M1 pendant l'enroulage.
IF State = E_State.BUSY THEN
    // 🔧 REX 2026-07-08 : pendant le déplacement, l'offset actif suit la différence réelle
    // de câble (M2 - M1) afin que la position corrigée de M2 reste stable (égale à M1, cad la hauteur du benne)
    // sans à-coup, tandis que le câble brut de M2 montre son enroulement.
    ActiveOffsetM := CablePosM2 - CablePosM1;
ELSIF CloseReq OR BucketState.IsClosed THEN
    ActiveOffsetM := Config.OffsetCloseM;
ELSE
    // Par défaut, ou en cours/état d'ouverture, on applique l'offset ouvert
    ActiveOffsetM := Config.OffsetOpenM;
END_IF;
