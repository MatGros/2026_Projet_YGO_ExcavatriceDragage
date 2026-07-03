
// === IMPLEMENTATION (à coller dans le corps ST du POU FB_WinchSync) ===

// 🛑 1. GATE
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    State := E_State.DISABLED;
    DeltaPosM := 0.0;
    SyncActive := FALSE;
    SyncWarn := FALSE;
    Error := FALSE;
    ErrorId := 16#0000;
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
