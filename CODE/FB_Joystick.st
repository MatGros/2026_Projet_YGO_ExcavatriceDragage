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
   🆕 AJOUT (2026-07-02, demande utilisateur — maintenance) : `SpeedXPct`/
      `DirectionX`/`SpeedYPct`/`DirectionY` en sortie DIRECTE (miroir des
      champs déjà présents dans `AxisCmdX/Y`), pour lecture immédiate en
      vue instance CODESYS sans devoir déplier la structure `ST_AxisCmd`.
      `ST_AxisCmd` reste inchangé et reste la sortie consommée par
      `FB_Winch`/`FB_Chariot` (Partie2 §8) — purement additif, pas
      de nouvelle logique métier.
   🆕 AJOUT (2026-07-02, demande utilisateur) :
      1. `Deadband` par défaut 5.0 → 10.0 (% autour du neutre).
      2. `AxisCmdX/Y.SpeedRef` (et ses miroirs `SpeedXPct`/`SpeedYPct`) sont
         désormais SIGNÉS (-100..+100 %, le signe porte le sens) au lieu de
         toujours positifs — affichage plus simple pour l'IHM/maintenance
         (une seule valeur lisible au lieu de 2 champs à recouper). Le champ
         `Direction` (-1/0/+1) est CONSERVÉ tel quel en plus (redondant mais
         explicite) — rien ne change dans son calcul.
      ⚠️ IMPACT AVAL : `FB_Winch`/`FB_Chariot` consomment `SpeedRefPct`
      en supposant une magnitude non signée (0..100) pour leur rampe interne
      — ils ont été adaptés en conséquence (voir CODE/FB_Winch.st §3 et
      CODE/FB_Chariot.st §4/§5bis, `ABS(SpeedRefPct)` ajouté à la
      frontière d'entrée). Le sens réellement appliqué au treuil/chariot
      reste piloté par `Direction` (interlock déjà validé terrain, inchangé)
      — la magnitude signée n'est PAS (encore) utilisée comme source de
      sens côté treuil, uniquement affichée pour la maintenance.
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
    Deadband        : REAL := 10.0;  // 🔧 2026-07-02 (demande utilisateur) : 5.0 → 10.0 %
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
    // 🆕 Miroirs directs (maintenance) — mêmes valeurs que AxisCmdX/Y.SpeedRef/.Direction,
    // exposés à plat pour lecture immédiate en vue instance CODESYS (pas de dépliage struct).
    SpeedXPct       : REAL;       // Consigne vitesse axe X en % SIGNÉE (-100..+100), miroir AxisCmdX.SpeedRef
    DirectionX      : INT;        // Sens axe X (-1=Rev/0=Neutre/+1=Fwd), miroir AxisCmdX.Direction
    SpeedYPct       : REAL;       // Consigne vitesse axe Y en % SIGNÉE (-100..+100), miroir AxisCmdY.SpeedRef
    DirectionY      : INT;        // Sens axe Y (-1=Rev/0=Neutre/+1=Fwd), miroir AxisCmdY.Direction
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
    SpeedXPct := 0.0; DirectionX := 0;
    SpeedYPct := 0.0; DirectionY := 0;
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
// 🔧 2026-07-02 : SpeedRef désormais SIGNÉ (plus de ABS) — le signe porte le sens, cohérent
// avec Direction ci-dessous (même seuil 0.1, même variable RampX.Current). StartStop reste
// calculé sur la MAGNITUDE (indépendant du signe) : sinon un mouvement négatif (< -0.1) serait
// à tort interprété comme "pas de mouvement" (StartStop=FALSE) par le test `> 0.1` direct.
AxisCmdX.Enable := TRUE;
AxisCmdX.SpeedRef := RampX.Current;
AxisCmdX.StartStop := (ABS(RampX.Current) > 0.1);

IF RampX.Current > 0.1 THEN     AxisCmdX.Direction := 1;
ELSIF RampX.Current < -0.1 THEN AxisCmdX.Direction := -1;
ELSE AxisCmdX.Direction := 0;   AxisCmdX.SpeedRef := 0.0;
END_IF;

// 🆕 Miroirs maintenance (voir en-tête) — mêmes valeurs, à plat
SpeedXPct := AxisCmdX.SpeedRef;
DirectionX := AxisCmdX.Direction;

// 🕹️ 6. PIPELINE TRAITEMENT — AXE Y
ScaleY(RawIn := RawY, Neutral := NeutralYMem, Deadband := Deadband);

IF InvertY THEN
    FilterY(ValueIn := -ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterY(ValueIn := ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

RampY(Target := FilterY.ValueOut, AccelRate := AccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

// Mapping Sortie Standardisée Axe Y
// 🔧 2026-07-02 : voir note axe X ci-dessus (même principe, SpeedRef signé + StartStop sur magnitude)
AxisCmdY.Enable := TRUE;
AxisCmdY.SpeedRef := RampY.Current;
AxisCmdY.StartStop := (ABS(RampY.Current) > 0.1);

IF RampY.Current > 0.1 THEN     AxisCmdY.Direction := 1;
ELSIF RampY.Current < -0.1 THEN AxisCmdY.Direction := -1;
ELSE AxisCmdY.Direction := 0;   AxisCmdY.SpeedRef := 0.0;
END_IF;

// 🆕 Miroirs maintenance (voir en-tête) — mêmes valeurs, à plat
SpeedYPct := AxisCmdY.SpeedRef;
DirectionY := AxisCmdY.Direction;

// 📤 7. VALIDATION DES SORTIES ÉTAT
NeutralXAct := NeutralXMem;
NeutralYAct := NeutralYMem;
Done := NOT Error;
