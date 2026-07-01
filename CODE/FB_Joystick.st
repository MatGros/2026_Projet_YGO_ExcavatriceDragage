(* ═══════════════════════════════════════════════════════════════
   🕹️ FB_Joystick — Acquisition + traitement Hall (mise en conformité)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md
   ⚠️ 2 CORRECTIFS apportés dans cette itération (chaîne Winch, groupe 2) :
      1. Renommage entrée `SafetyOk` → `EmergencyStopOk` + AJOUT au GATE
         (§1 ci-dessous) : elle ne servait auparavant qu'à être recopiée
         dans `AxisCmdX/Y.SafetyOk`, sans jamais neutraliser le FB — non
         conforme Partie3 §1 ("NOT EmergencyStopOk → sorties sûres").
      2. Retrait des affectations `.SafetyOk` sur `AxisCmdX/Y` : ce champ
         n'existe plus dans `ST_AxisCmd` (voir CODE/ST_AxisCmd.st) — cette
         info de contexte est désormais consommée directement par le FB
         de mouvement (FB_Winch), pas portée par la consigne d'axe.
      3. `Start` → `StartStop` (suit le renommage du champ ST_AxisCmd).
   ⚠️ CORRECTIFS (revue de code 2026-07-01) :
      4. Reset était sur NIVEAU (`Reset AND Error`), sans front ni vérif
         que la cause (calib hors plage) avait disparu — corrigé en
         front (`R_TRIG`) + cause vérifiée (Partie3 §5).
      5. `ErrorId := 16#0003` levait à tort 2 bits pour une seule cause
         (calibration) — corrigé en 1 seul bit (`16#0001`, Partie3 §3).
      6. `joystickOP` renommé `JoystickOP` (PascalCase, NAMING_CONVENTION.md).
   🔴 NON traité ici (hors périmètre, connu — voir Partie8 §6bis) :
      l'entrée `SafeStop` ci-dessous reste présente sur ce FB alors que
      Partie8 v1.1 §3 l'interdit (FB_Joystick n'est pas un FB de
      mouvement). Câblage stub GVL_DEBUG.DBG_False inchangé. À traiter
      dans une prochaine itération dédiée SAFETY/JOYSTICK.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Joystick) ===

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    Enable          : BOOL;       // Active la logique
    Reset           : BOOL;       // Acquittement défaut
    SafeStop        : BOOL;       // ⚠️ Vestige non conforme (Partie8 §6bis) — conservé tel quel, hors périmètre de ce lot
    EmergencyStopOk : BOOL;       // ✅ Renommé (était SafetyOk) — conditions globales OK (chaîne AU réarmée)
    BusCanOpenOP    : ST_DeviceDiag;       // État présence nœud CAN
    JoystickOP      : ST_DeviceDiag;       // Mode esclave CANopen actif
    RawX            : INT;        // Valeur brute axe X
    RawY            : INT;        // Valeur brute axe Y
    RawButton       : BOOL;       // État brut bouton
    Calibrate       : BOOL;       // Demande de recalage neutre
    InvertX         : BOOL := FALSE;
    InvertY         : BOOL := FALSE;
    Deadband        : REAL := 5.0;
    FilterTime      : TIME := TIME#100ms;
    AccelRate       : REAL := 50.0;
    DecelRate       : REAL := 150.0;
END_VAR
VAR_OUTPUT
    Ready           : BOOL;       // Prêt à commuter
    Busy            : BOOL;       // Traitement en cours
    Done            : BOOL;       // Données valides dispo
    Error           : BOOL;       // Présence anomalie
    ErrorId         : WORD;       // Code d'erreur
    AxisCmdX        : ST_AxisCmd; // Sortie normalisée X
    AxisCmdY        : ST_AxisCmd; // Sortie normalisée Y
    Button          : BOOL;       // Bouton filtré
    NeutralXAct     : INT;        // Point neutre X actuel pour IHM/Test
    NeutralYAct     : INT;        // Point neutre Y actuel pour IHM/Test
END_VAR
VAR RETAIN
    NeutralXMem     : INT := 5000; // Mémoire persistante X
    NeutralYMem     : INT := 5000; // Mémoire persistante Y
END_VAR
VAR
    CycleTimeCalc   : FB_CycleTime;
    ScaleX          : FB_AxisScale;
    ScaleY          : FB_AxisScale;
    FilterX         : FB_Filter_PT1;
    FilterY         : FB_Filter_PT1;
    RampX           : FB_Ramp;
    RampY           : FB_Ramp;
    LastCalibrate   : BOOL;
    ResetEdge       : R_TRIG;   // 🔧 AJOUT (revue de code 2026-07-01) — Reset doit être un front, pas un niveau
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Joystick) ===

// 🛑 1. GATE (Sécurités et coupures prioritaires)
IF NOT Enable OR SafeStop OR NOT EmergencyStopOk OR NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedRef := 0.0; AxisCmdX.Direction := 0;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedRef := 0.0; AxisCmdY.Direction := 0;
    Button := FALSE;
    NeutralXAct := NeutralXMem;
    NeutralYAct := NeutralYMem;
    RETURN;
END_IF;

Ready := TRUE; Busy := TRUE;

// 🔑 2. RESET DÉFAUT (front uniquement + cause disparue, Partie3 §5)
// ⚠️ CORRECTIF (revue de code 2026-07-01) : l'ancienne version effaçait le défaut sur simple
// niveau `Reset AND Error`, sans front ET sans vérifier que la cause (calib hors plage) avait
// disparu — un Reset maintenu (bouton IHM bloqué) effaçait le défaut en boucle même si RawX/Y
// restaient hors plage. Non conforme au guardrail Reset (CLAUDE.md, Partie3 §5).
ResetEdge(CLK := Reset);
IF ResetEdge.Q AND (RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000) THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📥 3. ACQUISITION TIMING & BOUTON
CycleTimeCalc();
Button := RawButton;

// 🎯 4. CALIBRATION DYNAMIQUE (Zone RETAIN)
IF Calibrate AND NOT LastCalibrate THEN
    IF RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000 THEN
        NeutralXMem := RawX;
        NeutralYMem := RawY;
    ELSE
        // 🔧 CORRECTIF N7 (revue de code) : un seul bit pour une seule cause (Partie3 §3),
        // l'ancienne valeur 16#0003 levait à tort les bits 0 ET 1 pour un même défaut.
        ErrorId := ErrorId OR 16#0001;
    END_IF;
END_IF;
Error := (ErrorId <> 16#0000);
LastCalibrate := Calibrate;

// 🕹️ 5. PIPELINE TRAITEMENT — AXE X
ScaleX(RawIn := RawX, Neutral := NeutralXMem, Deadband := Deadband);

IF InvertX THEN
    FilterX(ValueIn := -ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterX(ValueIn := ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

RampX(Target := FilterX.ValueOut, AccelRate := AccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

// Mapping Sortie Standardisée Axe X
AxisCmdX.Enable := TRUE;
AxisCmdX.SpeedRef := ABS(RampX.Current);
AxisCmdX.StartStop := (AxisCmdX.SpeedRef > 0.1);

IF RampX.Current > 0.1 THEN     AxisCmdX.Direction := 1;
ELSIF RampX.Current < -0.1 THEN AxisCmdX.Direction := -1;
ELSE AxisCmdX.Direction := 0;   AxisCmdX.SpeedRef := 0.0;
END_IF;

// 🕹️ 6. PIPELINE TRAITEMENT — AXE Y
ScaleY(RawIn := RawY, Neutral := NeutralYMem, Deadband := Deadband);

IF InvertY THEN
    FilterY(ValueIn := -ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterY(ValueIn := ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

RampY(Target := FilterY.ValueOut, AccelRate := AccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

// Mapping Sortie Standardisée Axe Y
AxisCmdY.Enable := TRUE;
AxisCmdY.SpeedRef := ABS(RampY.Current);
AxisCmdY.StartStop := (AxisCmdY.SpeedRef > 0.1);

IF RampY.Current > 0.1 THEN     AxisCmdY.Direction := 1;
ELSIF RampY.Current < -0.1 THEN AxisCmdY.Direction := -1;
ELSE AxisCmdY.Direction := 0;   AxisCmdY.SpeedRef := 0.0;
END_IF;

// 📤 7. VALIDATION DES SORTIES ÉTAT
NeutralXAct := NeutralXMem;
NeutralYAct := NeutralYMem;
Done := NOT Error;
