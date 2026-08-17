(* ═══════════════════════════════════════════════════════════════
   ⚖️ FB_WinchSync — Surveillance d'écart M1/M2 (M1: moteur de retenue, M2: moteur Benne — squelette liaisons — pas de correction)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md §9
   🔌 FB STANDARD (Partie3 §1bis) : pas un FB de mouvement, pas de StartStop/SafeStop —
      1 seule instance (surveille les 2 treuils, pas 1 par treuil comme FB_Safety_Winch).
   🎯 PÉRIMÈTRE CE LOT (squelette de liaisons, décisions Partie9 §9 déjà actées) :
      - Calcule `DeltaPosM = |CablePosM1 - CablePosM2|` (fiable seulement si les 2 treuils
        sont homés — sinon 0.0, pas de comparaison).
      - `SyncActive` selon `Mode` : MAINT_N1 = imposée (non désactivable, sécurité
        maintenue) ; MAINT_N2 = activable/désactivable via `SyncEnable` (FB_Modes, 🔧 REX
        2026-07-08 : ex-`OverrideSync` inversé) ; MANUEL/SEMI_AUTO = active par défaut.
      - `SyncWarn` = AVERTISSEMENT IHM SEULEMENT (Partie5 §6, comme `SyncWarn`/
        `ForceImbalance` cités en exemple) — **PAS de SafeStop** : aucune correction de
        vitesse n'existe aujourd'hui côté FB_Winch (pas d'entrée dédiée), donc rien à
        piloter automatiquement ce lot. Surveillance visuelle opérateur en attendant.
   🔴 HORS PÉRIMÈTRE CE LOT : régulation/correction active de l'écart (nécessiterait une
      entrée de correction sur FB_Winch, pas encore conçue) — squelette de surveillance
      uniquement, comme demandé (« même s'il n'est pas complet à l'intérieur »).

   🔧 REX 2026-07-08 (5) — incident terrain : écart mineur transitoire (0.24m, mécanique,
      coast-down différentiel M1/M2 à l'arrêt réel — normal et inévitable) déclenchait bit0
      et bloquait le mouvement dans les DEUX sens (régression, déblocage possible seulement
      via Reset+MAINT_N2+SyncEnable=FALSE). Root cause : phénomène mécanique, pas un bug du
      couplage croisé logiciel (bit1). Deux correctifs :
      1) `SignedDeltaPosM` (nouvelle sortie, calculé AVANT le ABS() de `DeltaPosM`) : signe
         positif = M1 "plus haut" que M2, négatif = M2 plus haut. Consommé par PRG_06 pour
         arbitrer DIRECTIONNELLEMENT le blocage bit0 — seul le sens qui AGGRAVE l'écart reste
         bloqué, l'autre sens (qui le réduit) reste autorisé. Méca E (FB_Safety_Winch, écart
         critique 2.0m) et bit1 restent le filet réel si l'écart continue de dériver.
      2) Filtre temporel `DeviationTimer` (même pattern que `MismatchTimer` bit1) sur bit0,
         800ms 🔧 théorique à ajuster sur site — absorbe le transitoire mécanique normal
         d'arrêt (~900ms de temporisations frein cumulées M1+M2).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_WinchSync) ===

FUNCTION_BLOCK PUBLIC FB_WinchSync
VAR_INPUT
    Enable          : BOOL;        // Standard — Partie5 §2 : FB_WinchSync.Enable := SyncEnable (câblage PRG_MAIN)
    Reset           : BOOL;        // Acquittement défaut (front)
    PowerContactorEngaged : BOOL;        // Standard
    Mode            : E_Mode;      // Arbitre SyncActive (voir en-tête)
    CablePosM1      : REAL;        // Sortie FB_Encoder_Scale M1
    CablePosM2      : REAL;        // Sortie FB_Encoder_Scale M2
    HomedM1         : BOOL;        // Sortie FB_Encoder_Homing M1
    HomedM2         : BOOL;        // Sortie FB_Encoder_Homing M2
    SyncEnable      : BOOL;        // 🔧 REX 2026-07-08 : ex-OverrideSync inversé — Sortie FB_Modes, TRUE=synchro voulue
    CfgSyncToleranceM  : REAL := 0.10; // RETAIN site (PRG_MAIN) — écart max toléré avant SyncWarn
    ActiveOffsetM   : REAL := 0.0; // 🪣 Offset cible appliqué (ex: benne fermé/ouvert)
    
    // 🆕 Signaux de commande réels des treuils (pour contrôle de cohérence)
    RelayFwdM1      : BOOL;
    RelayFwdM2      : BOOL;
    RelayRevM1      : BOOL;
    RelayRevM2      : BOOL;
    Contactor1_M1   : BOOL;
    Contactor1_M2   : BOOL;
    Contactor2_M1   : BOOL;
    Contactor2_M2   : BOOL;
    Contactor3_M1   : BOOL;
    Contactor3_M2   : BOOL;
    Contactor4_M1   : BOOL;
    Contactor4_M2   : BOOL;
    // 🌐 Bypass Global : force ErrorId = 0, ignore toute erreur de synchro
    BypassGlobal    : BOOL := FALSE;
END_VAR
VAR_OUTPUT
    Ready           : BOOL;
    Busy            : BOOL;
    Done            : BOOL;
    Error           : BOOL;
    ErrorId         : WORD;        // bit0: "Écart synchronisme trop important" - écart hors tolérance (SyncActive uniquement) ; bit1: "Incohérence commande synchro" - incohérence de commande (sens/paliers différents)
    State           : E_State;
    StateAtError    : E_State;
    DeltaPosM       : REAL;        // |CablePosM1 - CablePosM2|, 0.0 si pas les 2 homés
    SignedDeltaPosM : REAL;        // 🆕 REX 2026-07-08 (5) : signé, > 0 = M1 plus haut que M2 — pour arbitrage directionnel PRG_06
    SyncActive      : BOOL;        // Surveillance imposée/activable selon Mode (voir en-tête)
    SyncWarn        : BOOL;        // ⚠️ Avertissement IHM uniquement (Partie5 §6) — PAS de SafeStop
    SyncDegradedStep1 : BOOL;      // 🐢 2026-08-15 (T113) : Écart modéré actif -> force le Palier 1 sur les 2 treuils
END_VAR
VAR
    ResetEdge       : R_TRIG;
    ErrorEdge       : R_TRIG;
    MismatchActive  : BOOL;        // 🆕 Indique une discordance active de commande
    MismatchTimer   : TON;         // 🆕 Filtre temporel pour éviter les faux déclenchements transitoires
    DeviationActive : BOOL;        // 🆕 REX 2026-07-08 (5) : écart hors tolérance actif (avant filtre)
    DeviationTimer  : TON;         // 🆕 REX 2026-07-08 (5) : filtre temporel bit0, même pattern que MismatchTimer
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_WinchSync) ===

{region "Gate neutralisation"}
// 🛑 1. GATE
IF NOT Enable OR NOT PowerContactorEngaged THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    DeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE;
    SyncDegradedStep1 := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
    RETURN;
END_IF;

{endregion}

{region "Initialisation et activation synchro"}
Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🌐 BYPASS GLOBAL : force ErrorId = 0 et ignore toute la surveillance synchro
IF BypassGlobal THEN
    ErrorId := 16#0000;
END_IF;

// 🎚️ 3. SyncActive SELON MODE (Partie9 §9, décisions actées 2026-07-02)
CASE Mode OF
    E_Mode.MAINT_N1:
        SyncActive := TRUE;                  // Imposée, non désactivable (sécurité maintenue N1)
    E_Mode.MAINT_N2:
        SyncActive := SyncEnable;             // 🔧 REX 2026-07-08 : ex-NOT OverrideSync, polarité déjà positive
    ELSE
        SyncActive := TRUE;                  // MANUEL/SEMI_AUTO : pas de logique dédiée (FB_Cycle absent), actif par prudence
END_CASE;

{endregion}

{region "Calcul ecart position"}
// 📏 4. ÉCART M1/M2 — calculé en continu si les 2 treuils sont homés (même si BypassGlobal est actif)
IF HomedM1 AND HomedM2 THEN
    SignedDeltaPosM := CablePosM1 - CablePosM2 + ActiveOffsetM;
    DeltaPosM := ABS(SignedDeltaPosM);
ELSE
    SignedDeltaPosM := 0.0;
    DeltaPosM := 0.0;
END_IF;

{endregion}

{region "Surveillance synchronisme"}
// 🌐 BYPASS GLOBAL : si actif, on saute TOUTE la logique d'erreur/surveillance
IF NOT BypassGlobal THEN

// 🔍 5. DÉTECTION ÉCART HORS TOLÉRANCE — bit0
// 🔧 REX 2026-07-08 (5) : filtre temporel (même pattern que MismatchTimer bit1) — absorbe le
// transitoire mécanique normal d'arrêt (coast-down différentiel M1/M2), évite le blocage
// intempestif constaté sur incident terrain (0.24m transitoire).
// 🆕 2026-08-15 (T113) : Si écart > CfgSyncToleranceM -> alarme d'écart (SyncWarn / bit0) et
// dégradation en vitesse lente Palier 1 (SyncDegradedStep1). L'arrêt brutal SafeStop est
// réservé à l'écart critique Méca E (> CriticalSyncToleranceM).
DeviationActive := SyncActive AND HomedM1 AND HomedM2 AND (DeltaPosM > CfgSyncToleranceM);
DeviationTimer(IN := DeviationActive, PT := T#800ms);  // 🔧 théorique, à ajuster sur site — absorbe le transitoire mécanique normal d'arrêt (coast-down différentiel M1/M2)
IF DeviationTimer.Q THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q AND NOT DeviationActive THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🐢 T113 : Dégradation au Palier 1 dès que l'écart dépasse la tolérance (sans attendre le SafeStop)
SyncDegradedStep1 := SyncActive AND HomedM1 AND HomedM2 AND ((DeltaPosM > CfgSyncToleranceM) OR ((ErrorId AND 16#0001) <> 16#0000));

// 🔍 5bis. COHÉRENCE DES COMMANDES SÉCURITÉ — bit1
// Vérifie que les commandes envoyées aux deux treuils sont identiques (sens et contacteurs)
// Filtre de 500ms pour tolérer les transitions et rampes.
MismatchActive := SyncActive AND (
    (RelayFwdM1 <> RelayFwdM2) OR
    (RelayRevM1 <> RelayRevM2) OR
    (Contactor1_M1 <> Contactor1_M2) OR
    (Contactor2_M1 <> Contactor2_M2) OR
    (Contactor3_M1 <> Contactor3_M2) OR
    (Contactor4_M1 <> Contactor4_M2)
);

MismatchTimer(IN := MismatchActive, PT := T#500ms);

IF MismatchTimer.Q THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF; // fin du IF MismatchActive

ELSE
    SyncDegradedStep1 := FALSE;
END_IF; // fin IF NOT BypassGlobal

{endregion}

{region "Etats et diagnostic"}
// 📤 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SyncWarn := Error;   // ⚠️ IHM uniquement — voir en-tête, pas de SafeStop
Busy := FALSE;
Done := FALSE;

{endregion}
