(* ═══════════════════════════════════════════════════════════════
   🎚️ FB_Modes — Arbitrage du mode machine (MVP — diffusion, pas encore overrides complets)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie5_Modes_Maintenance_v1.2.md §1/§2
   🔌 FB STANDARD (Partie3 §1bis) : pas un FB de mouvement, pas de StartStop/SafeStop.
   🎯 RÔLE CE LOT : sélectionner/arbitrer `Mode` (source unique diffusée à TOUS les FB
      métier) + garde-fous minimaux :
      - Refuse `SEMI_AUTO` si un défaut codeur est présent (`EncoderFaultPresent`,
        agrégat `FB_Encoder_Safety` M1/M2) → repli `MAINT_N1`, ErrorId bit0.
      - Sort `SyncEnable` (🔧 REX 2026-07-08 : logique positive, ex-`OverrideSync` inversé) pour
        `FB_WinchSync.Enable` (Partie5 §2 : `FB_WinchSync.Enable := SyncEnable`).
   🔧 REX 2026-07-07 : contrôle `PasswordOk`/bit1 (`MAINT_N2` sans mot de passe) retiré à la
      demande explicite de l'utilisateur — l'accès à `MAINT_N2` est désormais géré **uniquement**
      côté IHM (visibilité des actions selon niveau utilisateur), pas de filet de sécurité côté
      automate. `ModeRequest = MAINT_N2` est donc accepté sans condition supplémentaire.
   🔴 HORS PÉRIMÈTRE CE LOT (Partie5 §2/§3, pas encore codé faute de FB_Cycle/FB_Bucket) :
      `OverrideBucket`, `OverrideLimit`/limite légale de dragage. À ajouter quand
      `FB_Cycle`/`FB_Bucket` existeront — ne pas inventer un override sans consommateur.
   🆕 REX 2026-07-08 : `InhibitM1`/`InhibitM2` (mise en service, demande utilisateur) — permet
      d'inhiber complètement un treuil (commande ET sa propre supervision safety) pour le tester
      seul, désynchronisation assumée. UNIQUEMENT actionnable en MAINT_N2 (plus restrictif
      que `SyncEnable`) — arbitrage centralisé ICI, aucun autre fichier ne doit re-tester
      Mode=MAINT_N2 pour ce besoin.
   🆕 REX 2026-07-08 (2) : `HomingApproachEnable` — corrige un trou constaté en test : l'arrêt normal à
      l'approche du capteur haut (`PRG_06_WinchControl.st`, seuil `HomingTargetMx_M -
      WinchTopStopMarginM`) était bypassé par le simple fait d'être en MAINT_N2, SANS bit dédié —
      donc désactivé pendant N'IMPORTE QUELLE opération N2, même sans rapport avec un homing.
      Remplacé par un vrai bit d'autorisation explicite (même pattern que `SyncEnable`), commun
      aux 2 treuils (référencement nominal déjà sur les 2 ensemble) : l'opérateur doit désormais
      ACTIVER consciemment cette case en plus d'être en MAINT_N2, pas juste sélectionner le mode.
   🔧 REX 2026-07-08 (3) : `OverrideSync` renommé `SyncEnable`, polarité inversée (demande
      utilisateur, IHM plus simple) — TRUE = synchro ACTIVE (au lieu de TRUE = synchro désactivée).
   ⚠️ Dépendance croisée `EncoderFaultPresent` (FB_Encoder_Safety, appelé APRÈS ce FB dans
      PRG_MAIN car dépend de CablePosM/Homing) consommée avec 1 CYCLE DE RETARD — même
      principe déjà assumé pour HomingRefRaw (Partie10 §9bis).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Modes) ===

FUNCTION_BLOCK PUBLIC FB_Modes
VAR_INPUT
    Enable              : BOOL;        // Standard
    Reset               : BOOL;        // Acquittement défaut (front) — bit0
    EmergencyStopOk     : BOOL;        // Standard
    ModeRequest         : E_Mode;      // 🖥️ GVL_Modes_Stub.ModeRequest_IHM — sélecteur forceable
    SyncEnableRequest   : BOOL;        // 🖥️ GVL_Modes_Stub.SyncEnableRequest_IHM — case à cocher, coché = synchro voulue
    InhibitM1Request    : BOOL;        // 🆕 REX 2026-07-08 : GVL_IHM.M1TreuilRetenue.CmdInhibit — bouton IHM inhibition M1
    InhibitM2Request    : BOOL;        // 🆕 REX 2026-07-08 : GVL_IHM.M2TreuilBucket.CmdInhibit — bouton IHM inhibition M2
    HomingApproachEnableRequest : BOOL;     // 🆕 REX 2026-07-08 (2) : GVL_IHM.Commun.HomingApproachEnableRequest — case IHM
                                        // autorisant à dépasser l'arrêt normal haut (approche capteur pour homing)
    EncoderFaultPresent : BOOL;        // Agrégat instEncoderSafetyM1/M2.EncoderIncoherent (OR), 1 cycle de retard
    JoystickWinchSelectRequest : INT;  // 🆕 TASK-0001 : 1=M1, 2=M2, 3=Couplé (brut IHM)
END_VAR
VAR_OUTPUT
    Ready               : BOOL;
    Busy                : BOOL;
    Done                : BOOL;
    Error               : BOOL;
    ErrorId             : WORD;        // bit0: "Mode Semi-Auto refusé (Défaut Codeur)" - SEMI_AUTO refusé (défaut codeur)
    State               : E_State;
    StateAtError        : E_State;
    Mode                : E_Mode;      // 🎯 Mode ARBITRÉ — diffusé à TOUS les FB métier (remplace E_Mode.MAINT_N1 codé en dur)
    SyncEnable          : BOOL;        // → FALSE seulement si Mode=MAINT_N1/N2 ET SyncEnableRequest décoché (Décision D_OVERRIDESYNC 2026-07-04)
    InhibitM1           : BOOL;        // 🆕 REX 2026-07-08 : actif SEULEMENT si Mode=MAINT_N2 AND InhibitM1Request
    InhibitM2           : BOOL;        // 🆕 REX 2026-07-08 : actif SEULEMENT si Mode=MAINT_N2 AND InhibitM2Request
    HomingApproachEnable     : BOOL;        // 🆕 REX 2026-07-08 (2) : actif SEULEMENT si Mode=MAINT_N2 AND HomingApproachEnableRequest
    JoystickWinchSelectArbitrated : INT; // 🆕 TASK-0001 : arbitré, forcé à 3 (Couplé) hors MAINT_N2
END_VAR
VAR
    ResetEdge           : R_TRIG;
    ErrorEdge           : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Modes) ===

// 🛑 1. GATE — repli sur le mode de sécurité de veille (DISABLE) si désactivé
// ou si l'arrêt d'urgence est déclenché.
IF NOT Enable OR NOT EmergencyStopOk THEN
    Mode := E_Mode.DISABLE;
    SyncEnable := TRUE;
    InhibitM1 := FALSE;
    InhibitM2 := FALSE;
    HomingApproachEnable := FALSE;
    JoystickWinchSelectArbitrated := 3; // Par défaut couplé
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🔍 3. GARDE-FOUS
// bit0 : SEMI_AUTO demandé mais défaut codeur présent → refusé, repli MAINT_N1
IF (ModeRequest = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📤 4. ARBITRAGE DU MODE
// 🔧 REX 2026-07-07 : plus de garde-fou mot de passe ici — MAINT_N2 accepté directement,
// l'accès est filtré en amont côté IHM (visibilité des actions selon niveau utilisateur).
IF (ModeRequest = E_Mode.SEMI_AUTO) AND EncoderFaultPresent THEN
    Mode := E_Mode.MAINT_N1;
ELSE
    Mode := ModeRequest;
END_IF;

// 📤 5. SYNC ENABLE — actionnable en MAINT_N1 OU MAINT_N2 (Décision D_OVERRIDESYNC 2026-07-04)
// Anciennement restreint à MAINT_N2 uniquement, mais l'opérateur peut avoir besoin de la
// procédure de récupération mou câble dès MAINT_N1. 🔧 REX 2026-07-08 : polarité inversée —
// FALSE (désactivé) seulement si en MAINT_N1/N2 ET case décochée ; TRUE partout ailleurs.
SyncEnable := NOT ((Mode = E_Mode.MAINT_N1 OR Mode = E_Mode.MAINT_N2) AND NOT SyncEnableRequest);

// 📤 5bis. INHIBITION TREUIL — mise en service, demande utilisateur (REX 2026-07-08)
// UNIQUEMENT actionnable en MAINT_N2 (contrairement à SyncEnable, actionnable aussi N1) —
// action plus sensible (neutralise complètement un treuil ET sa propre supervision safety),
// réservée au niveau de droits le plus élevé. Centralisé ICI (comme SyncEnable) : aucun
// autre fichier ne doit re-tester Mode=MAINT_N2 pour ce besoin.
InhibitM1 := (Mode = E_Mode.MAINT_N2) AND InhibitM1Request;
InhibitM2 := (Mode = E_Mode.MAINT_N2) AND InhibitM2Request;

// 📤 5ter. OVERRIDE ARRÊT HAUT — mise en service, demande utilisateur (REX 2026-07-08 (2))
// UNIQUEMENT actionnable en MAINT_N2 — remplace l'ancien test direct Mode<>MAINT_N2 dans
// PRG_06_WinchControl.st, qui bypassait l'arrêt normal pour N'IMPORTE QUELLE opération N2.
// Désormais un choix conscient explicite est requis EN PLUS du mode.
HomingApproachEnable := (Mode = E_Mode.MAINT_N2) AND HomingApproachEnableRequest;

// 📤 5quater. SÉLECTEUR JOYSTICK — TASK-0001 (2026-07-15)
// M1 seul (=1) ou M2 seul (=2) au joystick est réservé au mode MAINT_N2
// pour éviter de désynchroniser accidentellement les treuils (câble en travers).
// Forcé à Couplé (=3) dans tous les autres modes (MAINT_N1, SEMI_AUTO, DISABLE).
IF Mode = E_Mode.MAINT_N2 THEN
    JoystickWinchSelectArbitrated := JoystickWinchSelectRequest;
ELSE
    JoystickWinchSelectArbitrated := 3; // Couplé forcé
END_IF;

// 📤 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

Busy := FALSE;
Done := FALSE;
