(* ═══════════════════════════════════════════════════════════════
   🕹️ FB_Joystick — Acquisition & traitement Hall (Homme-mort ISO 13850)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF_Partie-08_Fonction_Joystick_v2.0.md
                   DOC/AF_Partie-03_Contrats_Composants_v2.1.md
   🎯 Rôle : Acquisition 2 axes Hall + bouton homme-mort normatif.
      Pipeline par axe : FB_AxisScale → FB_Filter_PT1 → Homme-Mort → ST_Joystick_AxisCmd.
      Les rampes d'accélération/décélération sont gérées exclusivement par les
      FB de mouvement aval (FB_Winch, FB_Translation), hors de ce bloc.
    🔒 Bouton homme-mort :
       - Armement au neutre strict (ScaleX/Y.OutPct = 0.0).
       - Consentement au démarrage : mouvement libre SANS surveillance du bouton
         (défaut, DeadmanReconfEnable := FALSE). Optionnel : reconfirmation périodique
         en mouvement (délai DeadmanRearmTimeout) si DeadmanReconfEnable := TRUE.
       - Désarmement sur maintien au neutre (durée NeutralHoldTime) + gate/mode/fin benne.
   📤 Produit AxisCmdX, AxisCmdY, et signaux de diagnostic/miroir.
   ═══════════════════════════════════════════════════════════════ *)

// === DECLARATION (à coller dans la partie déclaration du POU FB_Joystick) ===

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    Enable          : BOOL;       // Active la logique
    Reset           : BOOL;       // Acquittement défaut
    PowerContactorEngaged : BOOL;       // Conditions globales OK (chaîne AU réarmée)
    Mode            : E_Mode;     // Changement de mode désarme le homme-mort
    BenneBusy       : BOOL;       // Fin de cycle benne (front descendant) désarme le homme-mort
    PreserveArmingAfterBucket : BOOL; // TRUE uniquement pendant fermeture ExtractionSequence : enchaînement palier 1 autorisé
    BusCanOpenOP    : ST_Diag_Device;       // État présence nœud CAN
    JoystickOP      : ST_Diag_Device;       // Mode esclave CANopen actif
    RawX            : INT;        // Valeur brute axe X
    RawY            : INT;        // Valeur brute axe Y
    RawButton       : BOOL;       // État brut bouton
    BtnCalibrate    : BOOL;       // Demande de recalage neutre
    InvertX         : BOOL := FALSE;
    InvertY         : BOOL := FALSE;
    Deadband        : REAL := 10.0;  // Zone morte en %
    FilterTime      : TIME := TIME#50ms;
    DeadmanRearmTimeout : TIME := T#10S; // Délai max entre 2 appuis en mouvement (si reconfirmation activée)
    NeutralHoldTime     : TIME := T#100MS; // Temps continu au neutre avant désarmement (100 ms)
    DeadmanReconfEnable : BOOL := FALSE; // 🆕 2026-08-03 : FALSE = bouton = consentement au démarrage (mouvement libre, défaut cible) ; TRUE = reconfirmation périodique en mouvement (comportement historique)
END_VAR
VAR_OUTPUT
    Ready           : BOOL;       // Prêt à commuter
    Busy            : BOOL;       // Traitement en cours
    Done            : BOOL;       // Données valides dispo
    Error           : BOOL;       // Présence anomalie
    ErrorId         : WORD;       // bit0: "Échec calibration Joystick" - Valeurs RawX/Y hors plage lors du recalage
    AxisCmdX        : ST_Joystick_AxisCmd; // Sortie normalisée X
    AxisCmdY        : ST_Joystick_AxisCmd; // Sortie normalisée Y
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
VAR_IN_OUT
    NeutralXMem     : INT; // Point neutre X persistant global
    NeutralYMem     : INT; // Point neutre Y persistant global
END_VAR
VAR
    CycleTimeCalc   : FB_CycleTime;
    ScaleX          : FB_AxisScale;
    ScaleY          : FB_AxisScale;
    FilterX         : FB_Filter_PT1;
    FilterY         : FB_Filter_PT1;
    CmdXVal         : REAL;
    CmdYVal         : REAL;
    LastCalibrate   : BOOL;
    ResetEdge       : R_TRIG;
    DeadmanEdge     : R_TRIG;
    DeadmanTimer    : TON;
    NeutralHoldTimer: TON;
    LastMode        : E_Mode;
    BenneBusyFallEdge : F_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Joystick) ===

// 🛑 1. GATE (Sécurités et coupures prioritaires)
IF NOT Enable OR NOT PowerContactorEngaged OR NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedRef := 0.0; AxisCmdX.Direction := 0;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedRef := 0.0; AxisCmdY.Direction := 0;
    SpeedXPct := 0.0; DirectionX := 0;
    SpeedYPct := 0.0; DirectionY := 0;
    Button := FALSE;
    DeadmanArmed := FALSE;   // 🆕 Désarmé sur toute neutralisation — nouvel appui au neutre exigé
    DeadmanTimer(IN := FALSE, PT := DeadmanRearmTimeout);   // 🆕 2026-07-03decies — pas d'accumulation à froid
    NeutralHoldTimer(IN := FALSE, PT := NeutralHoldTime);   // 🆕 2026-07-03duodecies — idem
    NeutralXAct := NeutralXMem;
    NeutralYAct := NeutralYMem;
    LastMode := Mode;   // 🆕 REX 2026-07-08 — pas de faux changement détecté à la réactivation
    RETURN;
END_IF;

Ready := TRUE; Busy := TRUE;

// 🔑 2. RESET DÉFAUT (front + cause disparue, Partie3 §5)
ResetEdge(CLK := Reset);
IF ResetEdge.Q AND (RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000) THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📥 3. ACQUISITION TIMING & BOUTON
CycleTimeCalc();
Button := RawButton;

// 🎯 4. CALIBRATION DYNAMIQUE (Zone RETAIN)
IF BtnCalibrate AND NOT LastCalibrate THEN
    IF RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000 THEN
        NeutralXMem := RawX;
        NeutralYMem := RawY;
    ELSE
        // Un seul bit pour une seule cause (Partie3 §3)
        ErrorId := ErrorId OR 16#0001;
    END_IF;
END_IF;
Error := (ErrorId <> 16#0000);
LastCalibrate := BtnCalibrate;

// 🧮 4bis. MISE À L'ÉCHELLE (avant homme-mort — le neutre s'évalue sur les 2 axes déjà deadbandés)
ScaleX(RawIn := RawX, Neutral := NeutralXMem, Deadband := Deadband);
ScaleY(RawIn := RawY, Neutral := NeutralYMem, Deadband := Deadband);

// 4ter-bis. CHANGEMENT DE MODE : désarme le homme-mort dès que Mode change
// (MAINT_N1/N2/SEMI_AUTO/AUTO). Évite qu'une commande en cours traverse le changement
// de mode et soit réinterprétée soudainement. Repassage par le neutre + nouvel appui exigé.
IF Mode <> LastMode THEN
    DeadmanArmed := FALSE;
END_IF;
LastMode := Mode;

// 4ter-ter. FIN DE CYCLE BENNE : désarmement général pour qu'une fermeture manuelle
// ne démarre jamais M1/M2 par surprise. Exception : ExtractionSequence garde l'armement
// pendant sa fermeture (enchaînement palier 1 sous ses propres interlocks synchro/position).
BenneBusyFallEdge(CLK := BenneBusy);
IF BenneBusyFallEdge.Q AND NOT PreserveArmingAfterBucket THEN
    DeadmanArmed := FALSE;
END_IF;

// 4ter. BOUTON HOMME-MORT
DeadmanEdge(CLK := RawButton);

// 🔧 2026-08-06 (retour terrain) : décision 2026-08-03 ("l'opérateur a le temps qu'il veut
// pour démarrer après armement") ANNULÉE explicitement — un armement resté au neutre sans
// mouvement démarré ne désarmait JAMAIS (LeftNeutralSinceArm restait FALSE indéfiniment),
// laissant DeadmanArmed collé à TRUE d'une session à l'autre. Neutre tenu NeutralHoldTime
// désarme désormais TOUJOURS, qu'un mouvement ait été démarré ou non depuis l'armement.
NeutralHoldTimer(IN := DeadmanArmed AND (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0),
                 PT := NeutralHoldTime);
IF NeutralHoldTimer.Q THEN
    DeadmanArmed := FALSE;      // Neutre tenu assez longtemps = désarmement
END_IF;
IF DeadmanEdge.Q AND (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0) THEN
    DeadmanArmed := TRUE;       // Appui bouton au neutre = armement
END_IF;

// 4quater. RECONFIRMATION PÉRIODIQUE (optionnelle) — activée uniquement si DeadmanReconfEnable := TRUE.
// 🆕 2026-08-03 : par défaut FALSE → bouton = CONSENTEMENT AU DÉMARRAGE : une fois armé, le mouvement
// est libre SANS surveillance du bouton ; seuls gate/mode/fin benne/neutre 500ms désarment.
// ⚠️ CORRECTIF (garde-fou si réactivé) : le 1er jet ne détectait qu'un FRONT (`DeadmanEdge.Q`) — un
// opérateur qui MAINTIENT le bouton enfoncé en continu (réflexe naturel homme-mort) ne générait
// plus jamais de front après le 1er appui → désarmement surprise au bout de 3s MALGRÉ la présence
// continue. Corrigé : `NOT RawButton` (niveau, pas front) — maintenir OU réappuyer dans le délai
// remettent tous les deux `IN` à FALSE (TON.ET repart de 0), seul un RELÂCHEMENT PROLONGÉ désarme.
DeadmanTimer(IN := DeadmanReconfEnable AND DeadmanArmed
                   AND NOT ((ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0)) AND NOT RawButton,
             PT := DeadmanRearmTimeout);
IF DeadmanTimer.Q THEN
    DeadmanArmed := FALSE;      // Pas de reconfirmation dans le délai → désarmement (décélération sûre)
END_IF;

// 🕹️ 5. PIPELINE TRAITEMENT — AXE X
IF InvertX THEN
    FilterX(ValueIn := -ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterX(ValueIn := ScaleX.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

// Consigne forcée à 0.0 tant que le geste n'est pas armé (homme-mort)
CmdXVal := SEL(DeadmanArmed, 0.0, FilterX.ValueOut);

// Mapping Sortie Standardisée Axe X
AxisCmdX.Enable := TRUE;
AxisCmdX.SpeedRef := CmdXVal;
AxisCmdX.StartStop := (ABS(CmdXVal) > 0.1);

IF CmdXVal > 0.1 THEN
    AxisCmdX.Direction := 1;
ELSIF CmdXVal < -0.1 THEN
    AxisCmdX.Direction := -1;
ELSE
    AxisCmdX.Direction := 0;
    AxisCmdX.SpeedRef := 0.0;
END_IF;

// Miroirs maintenance
SpeedXPct := AxisCmdX.SpeedRef;
DirectionX := AxisCmdX.Direction;

// 🕹️ 6. PIPELINE TRAITEMENT — AXE Y
IF InvertY THEN
    FilterY(ValueIn := -ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
ELSE
    FilterY(ValueIn := ScaleY.OutPct, TimeConst := FilterTime, CycleTimeS := CycleTimeCalc.CycleTimeS);
END_IF;

// Consigne forcée à 0.0 tant que le geste n'est pas armé (homme-mort)
CmdYVal := SEL(DeadmanArmed, 0.0, FilterY.ValueOut);

// Mapping Sortie Standardisée Axe Y
AxisCmdY.Enable := TRUE;
AxisCmdY.SpeedRef := CmdYVal;
AxisCmdY.StartStop := (ABS(CmdYVal) > 0.1);

IF CmdYVal > 0.1 THEN
    AxisCmdY.Direction := 1;
ELSIF CmdYVal < -0.1 THEN
    AxisCmdY.Direction := -1;
ELSE
    AxisCmdY.Direction := 0;
    AxisCmdY.SpeedRef := 0.0;
END_IF;

// Miroirs maintenance
SpeedYPct := AxisCmdY.SpeedRef;
DirectionY := AxisCmdY.Direction;

// 📤 7. VALIDATION DES SORTIES ÉTAT
NeutralXAct := NeutralXMem;
NeutralYAct := NeutralYMem;
Done := NOT Error;
