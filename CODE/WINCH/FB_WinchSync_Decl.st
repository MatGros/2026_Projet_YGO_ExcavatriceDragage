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
END_VAR
VAR_OUTPUT
    Ready           : BOOL;
    Busy            : BOOL;
    Done            : BOOL;
    Error           : BOOL;
    ErrorId         : WORD;        // bit0 : écart hors tolérance (SyncActive uniquement) ; bit1 : incohérence de commande (sens/paliers différents)
    State           : E_State;
    StateAtError    : E_State;
    DeltaPosM       : REAL;        // |CablePosM1 - CablePosM2|, 0.0 si pas les 2 homés
    SyncActive      : BOOL;        // Surveillance imposée/activable selon Mode (voir en-tête)
    SyncWarn        : BOOL;        // ⚠️ Avertissement IHM uniquement (Partie5 §6) — PAS de SafeStop
END_VAR
VAR
    ResetEdge       : R_TRIG;
    ErrorEdge       : R_TRIG;
    MismatchActive  : BOOL;        // 🆕 Indique une discordance active de commande
    MismatchTimer   : TON;         // 🆕 Filtre temporel pour éviter les faux déclenchements transitoires
END_VAR
