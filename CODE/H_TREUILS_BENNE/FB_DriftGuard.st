(* =======================================================================
   📐 FB_DriftGuard — Détection de dérive de position sous armement
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Capture position de référence et détection de dérive anormale
   📄 Doc métier : DOC/AF/AF_Partie-10_Fonction_Winch_v2.0.md
   🔌 Interface : Brique interne de sécurité (compose FB_Safety_Winch)
   🔒 Sécurité : Détection de mouvement non commandé et glissement
   ======================================================================= *)

FUNCTION_BLOCK PUBLIC FB_DriftGuard
VAR_INPUT
    // === COMMANDES ET SEUILS ===
    Arm                             : BOOL;                           // --> [CMD] Condition d'armement de la surveillance
    PositionM                       : REAL;                           // --> [HW] Position courante a surveiller (m)
    ToleranceM                      : REAL;                           // --> [CFG] Tolerance de derive maximale autorisee (m)
END_VAR
VAR_OUTPUT
    // === MESURES ET ETATS ===
    RefPosM                         : REAL;                           // <-- [DIAG] Position de reference capturee a l'armement (m)
    DriftM                          : REAL;                           // <-- [DIAG] Derive absolue courante (m)
    Violation                       : BOOL;                           // <-- [STAT] Alarme derive maximale depassee
END_VAR
VAR
    // === VARIABLES LOCALES INTERNES ===
    WasArmed                        : BOOL;                           // . [LOC] Memoire etat armement cycle precedent
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_DriftGuard) ===

IF Arm THEN
    IF NOT WasArmed THEN
        RefPosM := PositionM;   // Capture au 1er cycle armé uniquement
        WasArmed := TRUE;
    END_IF;
    DriftM := ABS(PositionM - RefPosM);
    Violation := DriftM > ToleranceM;
ELSE
    WasArmed := FALSE;
    DriftM := 0.0;
    Violation := FALSE;
END_IF;
