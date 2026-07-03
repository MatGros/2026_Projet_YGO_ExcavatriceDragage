(* ═══════════════════════════════════════════════════════════════
   ⚖️ FB_WinchSync — Surveillance d'écart M1/M2 (squelette liaisons — pas de correction)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie9_Fonction_Winch_v1.1.md §9
   🔌 FB STANDARD (Partie3 §1bis) : pas un FB de mouvement, pas de StartStop/SafeStop —
      1 seule instance (surveille les 2 treuils, pas 1 par treuil comme FB_Safety_Winch).
   🎯 PÉRIMÈTRE CE LOT (squelette de liaisons, décisions Partie9 §9 déjà actées) :
      - Calcule `DeltaPosM = |CablePosM1 - CablePosM2|` (fiable seulement si les 2 treuils
        sont homés — sinon 0.0, pas de comparaison).
      - `SyncActive` selon `Mode` : MAINT_N1 = imposée (non désactivable, sécurité
        maintenue) ; MAINT_N2 = activable/désactivable via `OverrideSync` (FB_Modes) ;
        MANUEL/SEMI_AUTO = active par défaut (pas de logique dédiée sans FB_Cycle).
      - `SyncWarn` = AVERTISSEMENT IHM SEULEMENT (Partie5 §6, comme `SyncWarn`/
        `ForceImbalance` cités en exemple) — **PAS de SafeStop** : aucune correction de
        vitesse n'existe aujourd'hui côté FB_Winch (pas d'entrée dédiée), donc rien à
        piloter automatiquement ce lot. Surveillance visuelle opérateur en attendant.
   🔴 HORS PÉRIMÈTRE CE LOT : régulation/correction active de l'écart (nécessiterait une
      entrée de correction sur FB_Winch, pas encore conçue) — squelette de surveillance
      uniquement, comme demandé (« même s'il n'est pas complet à l'intérieur »).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_WinchSync) ===

FUNCTION_BLOCK PUBLIC FB_WinchSync
VAR_INPUT
    Enable          : BOOL;        // Standard — Partie5 §2 : FB_WinchSync.Enable := NOT OverrideSync (câblage PRG_MAIN)
    Reset           : BOOL;        // Acquittement défaut (front)
    EmergencyStopOk : BOOL;        // Standard
    Mode            : E_Mode;      // Arbitre SyncActive (voir en-tête)
    CablePosM1      : REAL;        // Sortie FB_Encoder_Scale M1
    CablePosM2      : REAL;        // Sortie FB_Encoder_Scale M2
    HomedM1         : BOOL;        // Sortie FB_Encoder_Homing M1
    HomedM2         : BOOL;        // Sortie FB_Encoder_Homing M2
    OverrideSync    : BOOL;        // Sortie FB_Modes (actionnable UNIQUEMENT MAINT_N2)
    SyncToleranceM  : REAL := 0.10; // RETAIN site (PRG_MAIN) — écart max toléré avant SyncWarn
    ActiveOffsetM   : REAL := 0.0; // 🪣 Offset cible appliqué (ex: grappin fermé/ouvert)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;
    Busy            : BOOL;
    Done            : BOOL;
    Error           : BOOL;
    ErrorId         : WORD;        // bit0 : écart hors tolérance (SyncActive uniquement)
    State           : E_State;
    StateAtError    : E_State;
    DeltaPosM       : REAL;        // |CablePosM1 - CablePosM2|, 0.0 si pas les 2 homés
    SyncActive      : BOOL;        // Surveillance imposée/activable selon Mode (voir en-tête)
    SyncWarn        : BOOL;        // ⚠️ Avertissement IHM uniquement (Partie5 §6) — PAS de SafeStop
END_VAR
VAR
    ResetEdge       : R_TRIG;
    ErrorEdge       : R_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_WinchSync) ===

// 🛑 1. GATE
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    DeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT
ResetEdge(CLK := Reset);

// 🎚️ 3. SyncActive SELON MODE (Partie9 §9, décisions actées 2026-07-02)
CASE Mode OF
    E_Mode.MAINT_N1:
        SyncActive := TRUE;                  // Imposée, non désactivable (sécurité maintenue N1)
    E_Mode.MAINT_N2:
        SyncActive := NOT OverrideSync;       // Activable/désactivable par l'opérateur N2
    ELSE
        SyncActive := TRUE;                  // MANUEL/SEMI_AUTO : pas de logique dédiée (FB_Cycle absent), actif par prudence
END_CASE;

// 📏 4. ÉCART M1/M2 — fiable UNIQUEMENT si les 2 treuils sont homés
IF HomedM1 AND HomedM2 THEN
    DeltaPosM := ABS(CablePosM1 - CablePosM2 + ActiveOffsetM);
ELSE
    DeltaPosM := 0.0;
END_IF;

// 🔍 5. DÉTECTION ÉCART HORS TOLÉRANCE — bit0
IF SyncActive AND HomedM1 AND HomedM2 AND (DeltaPosM > SyncToleranceM) THEN
    ErrorId := ErrorId OR 16#0001;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📤 6. SORTIES ÉTAT
Error := (ErrorId <> 16#0000);
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

SyncWarn := Error;   // ⚠️ IHM uniquement — voir en-tête, pas de SafeStop
Busy := FALSE;
Done := FALSE;
