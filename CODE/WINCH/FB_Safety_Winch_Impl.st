
// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Safety_Winch) ===

// 🛑 1. GATE — sécurité par défaut : pas de surveillance active = arrêt forcé du domaine
IF NOT Enable OR NOT EmergencyStopOk THEN
    Ready := FALSE;
    SafeStop := TRUE;              // Fail-safe : tant que la surveillance n'est pas garantie, on arrête
    ForbidDescent := TRUE;         // Fail-safe : cohérent avec SafeStop (descente a fortiori interdite)
    PowerCutOff := FALSE;
    State := E_State.DISABLED;
    RETURN;
END_IF;

Ready := TRUE;
State := E_State.READY;

// 🔑 2. RESET FRONT — efface le bit dont la cause a disparu
ResetEdge(CLK := Reset);

// 🔍 3. DIAGNOSTIC DU DOMAINE TREUIL
IF NOT JoystickOnline OR NOT JoystickOperational THEN
    ErrorId := ErrorId OR 16#0001;       // Perte joystick/CAN : pas de commande opérateur valide
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 🔍 3bis. PERTE CODEUR DE CE TREUIL (câblé — lot Codeur 2026-07-02)
IF NOT EncoderAvailable THEN
    ErrorId := ErrorId OR 16#0002;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFD;
END_IF;

// 🔍 3ter. SURCHAUFFE MOTEUR (câblé — I/O réel 2026-07-02) — bit2, participe au SafeStop total
IF ThermalFeedback THEN
    ErrorId := ErrorId OR 16#0004;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

// 🔍 3quater. MOU DE CÂBLE (câblé — I/O réel 2026-07-02, commun M1/M2) — bit3, N'ARRÊTE PAS
// la remontée : voir §4ter Partie9 (ForbidDescent dédié, distinct de SafeStop ci-dessous).
IF SlackCableDetected THEN
    ErrorId := ErrorId OR 16#0008;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFF7;
END_IF;

// 🔍 3quinquies. ROTATION DE PHASE (câblé — I/O réel, commun M1/M2, 2026-07-03octodecies) —
// bit4, participe au SafeStop total (sens moteur potentiellement inversé, danger 2 sens).
IF NOT PhaseRotationOk THEN
    ErrorId := ErrorId OR 16#0010;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFEF;
END_IF;

// 🔍 3sexties. FIN DE COURSE HAUT / CAPTEUR DE POSITION HAUTE (anti-débordement) — bit5
// Si le capteur physique de position haute est actif ET qu'on n'est pas en phase de référencement (homing),
// alors on lève le défaut pour interdire uniquement la montée.
IF TopPositionSensor AND NOT InReferencingMode THEN
    ErrorId := ErrorId OR 16#0020;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFDF;
END_IF;

// 🔍 3septies. LONGUEUR MAX DE CÂBLE (profondeur max autorisée) — bit6
// Sécurité active tout le temps. Si la position de câble descend sous la limite basse physique (CablePosM <= CableLimitDescentM),
// alors on interdit uniquement la descente.
IF (CableLimitDescentM < 0.0) AND (CablePosM <= CableLimitDescentM) THEN
    ErrorId := ErrorId OR 16#0040;
ELSIF ResetEdge.Q THEN
    ErrorId := ErrorId AND 16#FFBF;
END_IF;

// 📤 4. ARBITRAGE DES SORTIES MAÎTRESSES
Error := (ErrorId <> 16#0000);       // 🧭 Partie3 §4 : miroir de TOUT le domaine, y compris mou de câble (visible IHM)
ErrorEdge(CLK := Error);
IF ErrorEdge.Q THEN
    StateAtError := State;
END_IF;

// 🟧 SafeStop : bits 0 (joystick)/1 (codeur)/2 (thermique)/4 (rotation phase) — arrêt total des
// 2 sens. Le mou de câble (bit3), le fin de course haut (bit5) et la longueur max câble (bit6)
// sont EXCLUS : ils n'interdisent qu'un seul sens de marche (voir ForbidDescent/ForbidAscent).
SafeStop := (ErrorId AND 16#0017) <> 16#0000;

// 🆕 ForbidDescent : reflète le bit3 (mou de câble) OU le bit6 (longueur max de câble) — interdit la descente.
ForbidDescent := (ErrorId AND 16#0048) <> 16#0000;

// 🆕 ForbidAscent : reflète le bit5 (fin de course haut) — interdit la montée.
ForbidAscent := (ErrorId AND 16#0020) <> 16#0000;

PowerCutOff := FALSE;       // 🧨 TBD — pas de ST_ContactorCheck de puissance câblé dans ce lot

// Busy, Done non utilisés mais présents pour conformité (comme FB_DiagCanOpen)
Busy := FALSE;
Done := FALSE;
