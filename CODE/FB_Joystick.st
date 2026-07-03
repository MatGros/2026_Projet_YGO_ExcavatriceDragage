(* ═══════════════════════════════════════════════════════════════
   🕹️ FB_Joystick — Acquisition + traitement Hall (bouton = homme-mort EN 574/ISO 13850)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie8_Fonction_Joystick_v1.1.md (historique détaillé des
      correctifs : AUDIT D34/D35/D49/D51/D53-D59)
   🔧 CORRECTIF (2026-07-03septdecies, AUDIT D69) : `SafeStop` RETIRÉ — Partie8 v1.1 §3
      l'interdit (`FB_Joystick` n'est pas un FB de mouvement, Partie3 §1bis). Agissait de
      plus comme un second `Enable` dans le GATE (coupure immédiate), pas comme la rampe
      rapide attendue d'un `SafeStop` — confusion précisément visée par la règle.
   🔴 Bouton homme-mort — comportement actuel (détail §4ter/§4quater ci-dessous) :
      - ARMEMENT : appui bouton PENDANT que le manche est AU NEUTRE (ScaleX/Y.OutPct = 0.0).
      - RECONFIRMATION périodique en mouvement : bouton maintenu OU réappuyé avant
        `DeadmanRearmTimeout` (10s) — sinon désarmement (rampe forcée à 0, pas d'arrêt brutal).
      - DÉSARMEMENT sur retour neutre : seulement si le neutre est TENU `NeutralHoldTime`
        (500ms, ⚠️ hypothèse à valider empiriquement — `ScaleX/Y.OutPct` n'est pas filtré/
        rampé), pas sur simple traversée (inversion de sens). `LeftNeutralSinceArm` évite un
        désarmement prématuré si l'opérateur hésite après l'armement sans avoir bougé.
      Défend contre un calage AVANT et APRÈS armement (présence continue exigée).
   🔴 BYPASS TEST BANC (2026-07-03octodecies, AUDIT D70) : `GVL_DEBUG.DBG_DeadmanBypass_TEST`
      force `DeadmanArmed` en permanence (comportement en investigation, pas encore déboguable
      dans l'immédiat). ⚠️ TOUJOURS FALSE en exploitation réelle — à restreindre par Mode
      (ex. MAINT_N1 seul) dès que l'arbitrage IHM sera précisé.
   🆕 `SpeedXPct`/`DirectionX`/`SpeedYPct`/`DirectionY` : miroirs directs de `AxisCmdX/Y`
      (lecture instance CODESYS sans déplier `ST_AxisCmd`). `SpeedRef` est SIGNÉ
      (-100..+100%, signe = sens) ; `Direction` (-1/0/+1) reste la source de vérité pour
      `FB_Winch`/`FB_Chariot` (`ABS(SpeedRefPct)` à leur frontière d'entrée).
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Joystick) ===

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    Enable          : BOOL;       // Active la logique
    Reset           : BOOL;       // Acquittement défaut
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
    DeadmanRearmTimeout : TIME := T#10S; // 🔧 2026-07-03duodecies (était 3s) — délai max entre 2 appuis en mouvement
    NeutralHoldTime     : TIME := T#500MS; // 🆕 2026-07-03duodecies — temps continu au neutre avant désarmement
                                            // (filtre les traversées rapides du neutre en inversion de sens)
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
    DeadmanArmed    : BOOL;       // 🆕 Geste armé (bouton appuyé au neutre) — IHM/diagnostic
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
    DeadmanEdge     : R_TRIG;   // 🆕 Front bouton homme-mort (2026-07-03octies)
    DeadmanTimer    : TON;      // 🆕 2026-07-03decies — délai max entre 2 appuis en mouvement (reconfirmation)
    NeutralHoldTimer: TON;      // 🆕 2026-07-03duodecies — filtre les traversées rapides du neutre (inversion)
    LeftNeutralSinceArm : BOOL; // 🔧 2026-07-03terdecies — a réellement quitté le neutre depuis l'armement
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Joystick) ===

// 🛑 1. GATE (Sécurités et coupures prioritaires)
IF NOT Enable OR NOT EmergencyStopOk OR NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedRef := 0.0; AxisCmdX.Direction := 0;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedRef := 0.0; AxisCmdY.Direction := 0;
    SpeedXPct := 0.0; DirectionX := 0;
    SpeedYPct := 0.0; DirectionY := 0;
    Button := FALSE;
    DeadmanArmed := FALSE;   // 🆕 Désarmé sur toute neutralisation — nouvel appui au neutre exigé
    LeftNeutralSinceArm := FALSE;   // 🔧 2026-07-03terdecies — repart propre au prochain armement
    DeadmanTimer(IN := FALSE, PT := DeadmanRearmTimeout);   // 🆕 2026-07-03decies — pas d'accumulation à froid
    NeutralHoldTimer(IN := FALSE, PT := NeutralHoldTime);   // 🆕 2026-07-03duodecies — idem
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

// 🧮 4bis. MISE À L'ÉCHELLE (avant homme-mort — le neutre s'évalue sur les 2 axes déjà deadbandés)
ScaleX(RawIn := RawX, Neutral := NeutralXMem, Deadband := Deadband);
ScaleY(RawIn := RawY, Neutral := NeutralYMem, Deadband := Deadband);

// 🔴 4ter. BOUTON HOMME-MORT (2026-07-03octies + renforcé decies/duodecies/terdecies — voir en-tête)
DeadmanEdge(CLK := RawButton);

// 🔧 2026-07-03terdecies (CORRECTIF review) : `LeftNeutralSinceArm` distingue "vient d'armer,
// n'a pas encore bougé" (NE DOIT PAS désarmer, même après NeutralHoldTime — l'opérateur a le
// temps qu'il veut pour démarrer son geste après l'appui) de "a bougé, PUIS est revenu au
// neutre" (là, `NeutralHoldTime` s'applique normalement, voir plus bas). Sans ce garde-fou, un
// opérateur qui arme puis hésite plus de NeutralHoldTime avant de bouger se faisait désarmer
// silencieusement (fail-safe, mais contredisait l'intention D57).
IF NOT DeadmanArmed THEN
    LeftNeutralSinceArm := FALSE;   // Repos/désarmé : prêt pour le prochain armement
ELSIF NOT ((ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0)) THEN
    LeftNeutralSinceArm := TRUE;    // Armé et a quitté le neutre au moins une fois : geste réellement démarré
END_IF;

// Le neutre doit être TENU `NeutralHoldTime` avant de désarmer (pas juste traversé) — sinon une
// inversion de sens rapide (Fwd→Rev) désarmerait à tort au passage par le neutre. Ne s'applique
// QU'APRÈS un geste réellement démarré (`LeftNeutralSinceArm`), jamais juste après l'armement.
NeutralHoldTimer(IN := DeadmanArmed AND LeftNeutralSinceArm AND (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0),
                 PT := NeutralHoldTime);
IF NeutralHoldTimer.Q THEN
    DeadmanArmed := FALSE;      // Neutre tenu assez longtemps APRÈS un geste démarré = fin réelle
END_IF;
IF DeadmanEdge.Q AND (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0) THEN
    DeadmanArmed := TRUE;       // Appui bouton AU NEUTRE = armement
END_IF;

// 🆕 4quater. RECONFIRMATION PÉRIODIQUE (2026-07-03decies, CORRIGÉ undecies suite review) — tant
// qu'armé ET en mouvement (hors neutre), le bouton doit être soit MAINTENU, soit ré-appuyé, avant
// DeadmanRearmTimeout. ⚠️ CORRECTIF : le 1er jet ne détectait qu'un FRONT (`DeadmanEdge.Q`) — un
// opérateur qui MAINTIENT le bouton enfoncé en continu (réflexe naturel homme-mort) ne générait
// plus jamais de front après le 1er appui → désarmement surprise au bout de 3s MALGRÉ la présence
// continue. Corrigé : `NOT RawButton` (niveau, pas front) — maintenir OU réappuyer dans le délai
// remettent tous les deux `IN` à FALSE (TON.ET repart de 0), seul un RELÂCHEMENT PROLONGÉ désarme.
DeadmanTimer(IN := DeadmanArmed AND NOT ((ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0)) AND NOT RawButton,
             PT := DeadmanRearmTimeout);
IF DeadmanTimer.Q THEN
    DeadmanArmed := FALSE;      // Pas de reconfirmation dans le délai → désarmement (décélération sûre)
END_IF;

// 🔴 BYPASS TEST BANC (2026-07-03octodecies, demande utilisateur) — TOUJOURS FALSE en
// exploitation réelle. Homme-mort en investigation (comportement jugé gênant en essai) ;
// pas le temps de déboguer dans l'immédiat. Force l'armement en permanence : bouton plus
// nécessaire pour bouger le joystick. À restreindre par Mode (ex. MAINT_N1 seul) dès que
// l'arbitrage voulu par IHM sera précisé — pour l'instant, un seul flag global, comme les
// autres bypass (DBG_EmergencyStopOkBypass_TEST/DBG_TopPositionSensorBypass_TEST).
IF GVL_DEBUG.DBG_DeadmanBypass_TEST THEN
    DeadmanArmed := TRUE;
END_IF;

// 🕹️ 5. PIPELINE TRAITEMENT — AXE X
IF InvertX THEN
    FilterX(ValueIn := -ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterX(ValueIn := ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

// 🔴 Cible rampe forcée à 0 tant que le geste n'est pas armé (homme-mort, voir §4ter)
RampX(Target := SEL(DeadmanArmed, 0.0, FilterX.ValueOut), AccelRate := AccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

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

// 🕹️ 6. PIPELINE TRAITEMENT — AXE Y (ScaleY déjà calculé en §4bis, avant homme-mort)
IF InvertY THEN
    FilterY(ValueIn := -ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterY(ValueIn := ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

// 🔴 Cible rampe forcée à 0 tant que le geste n'est pas armé (homme-mort, voir §4ter)
RampY(Target := SEL(DeadmanArmed, 0.0, FilterY.ValueOut), AccelRate := AccelRate, DecelRate := DecelRate, CycleTimeS := CycleTimeCalc.CycleTimeS);

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
