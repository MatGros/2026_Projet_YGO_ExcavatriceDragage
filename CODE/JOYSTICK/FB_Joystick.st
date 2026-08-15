(* ═══════════════════════════════════════════════════════════════
   🕹️ FB_Joystick — Acquisition & traitement Hall (Homme-mort ISO 13850)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md
                   DOC/AF/AF_Partie-03_Contrats_Composants_v2.1.md
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
    DeadbandRaw     : INT := 300;      // Zone morte en points ADC bruts (0..10000)
    FilterTime      : TIME := TIME#0ms;// Filtrage premier ordre axe
    NeutralHoldTime : TIME := T#100MS; // Maintien continu au neutre avant désarmement
    DeadmanArmHoldTime  : TIME := T#100MS; // Appui continu bouton requis pour armer
    DeadmanArmGraceTime : TIME := T#3S;    // Délai de grâce post-armement avant application du désarmement neutre
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
    AtNeutral       : BOOL;       // 🆕 2026-08-07 : TRUE si les 2 axes sont en zone morte (position centrale) — IHM/diagnostic
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
    NeutralHoldTimer: TON;
    DeadmanArmTimer : TON;
    DeadmanArmPending : BOOL;
    DeadmanArmGraceTimer : TON;
    LastMode        : E_Mode;
    BenneBusyFallEdge : F_TRIG;
END_VAR

// === IMPLEMENTATION (à coller dans le corps ST du POU FB_Joystick) ===

{region "§1 Gate securite"}
// 🛑 1. GATE (Sécurités et coupures prioritaires)
IF NOT Enable OR NOT PowerContactorEngaged OR NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
    Ready := FALSE; Busy := FALSE; Done := FALSE;
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedRef := 0.0; AxisCmdX.Direction := 0;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedRef := 0.0; AxisCmdY.Direction := 0;
    SpeedXPct := 0.0; DirectionX := 0;
    SpeedYPct := 0.0; DirectionY := 0;
    Button := FALSE;
    AtNeutral := TRUE;
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;
    NeutralHoldTimer(IN := FALSE, PT := NeutralHoldTime);
    DeadmanArmTimer(IN := FALSE, PT := DeadmanArmHoldTime);
    DeadmanArmGraceTimer(IN := FALSE, PT := DeadmanArmGraceTime);
    NeutralXAct := NeutralXMem;
    NeutralYAct := NeutralYMem;
    LastMode := Mode;   // 🆕 REX 2026-07-08 — pas de faux changement détecté à la réactivation
    RETURN;
END_IF;

Ready := TRUE; Busy := TRUE;

{endregion}

{region "§2 Reset acquisition timing et bouton"}
// 🔑 2. RESET DÉFAUT (front + cause disparue, Partie3 §5)
ResetEdge(CLK := Reset);
IF ResetEdge.Q AND (RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000) THEN
    ErrorId := ErrorId AND 16#FFFE;
END_IF;

// 📥 3. ACQUISITION TIMING & BOUTON
CycleTimeCalc();
Button := RawButton;

{endregion}

{region "§3 Calibration et mise a echelle"}
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
ScaleX(RawIn := RawX, Neutral := NeutralXMem, DeadbandRaw := DeadbandRaw);
ScaleY(RawIn := RawY, Neutral := NeutralYMem, DeadbandRaw := DeadbandRaw);
AtNeutral := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);   // 🆕 2026-08-07 : IHM/diagnostic — position centrale (zone morte)

{endregion}

{region "§4 Desarmements changement mode et fin benne"}
// 4ter-bis. CHANGEMENT DE MODE : désarme le homme-mort dès que Mode change
// (MAINT_N1/N2/SEMI_AUTO/AUTO). Évite qu'une commande en cours traverse le changement
// de mode et soit réinterprétée soudainement. Repassage par le neutre + nouvel appui exigé.
IF Mode <> LastMode THEN
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;   // 🆕 2026-08-07 — nouvel appui exigé après changement de mode
END_IF;
LastMode := Mode;

// 4ter-ter. FIN DE CYCLE BENNE : désarmement général pour qu'une fermeture manuelle
// ne démarre jamais M1/M2 par surprise. Exception : ExtractionSequence garde l'armement
// pendant sa fermeture (enchaînement palier 1 sous ses propres interlocks synchro/position).
BenneBusyFallEdge(CLK := BenneBusy);
IF BenneBusyFallEdge.Q AND NOT PreserveArmingAfterBucket THEN
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;   // 🆕 2026-08-07 — nouvel appui exigé après fin de cycle benne
END_IF;

{endregion}

{region "§5 Armement homme mort"}
// 4ter. BOUTON HOMME-MORT — armement par MAINTIEN (DeadmanArmHoldTime), indépendant de la
// position des axes pendant l'appui.
// 🔧 2026-08-07 (retour terrain) : l'ancien armement ("front bouton" ET "axes strictement à
// 0.0 sur le MÊME scan") échouait dès que l'opérateur poussait le joystick quelques ms après
// avoir appuyé — trop contraignant en pratique (le geste naturel "j'appuie PUIS je pousse" ratait
// systématiquement la fenêtre d'un seul scan). Nouvelle séquence : appui (front) → maintien
// DeadmanArmHoldTime (100 ms) → armé, quelle que soit la position des axes durant ce maintien.
// Relâchement AVANT la fin du maintien = tentative annulée (DeadmanArmPending retombe), un
// nouvel appui (front) est requis — pas d'armement différé "surprise" sur un appui prolongé après
// un désarmement (mode/benne/neutre). Sûr même si le joystick est déjà hors zone morte à la fin
// du maintien : les rampes d'accel/décel restent gérées par les FB aval (FB_Winch/FB_Translation,
// cf. §"Rôle" en tête de fichier), donc pas de démarrage brutal possible côté ce FB.
DeadmanEdge(CLK := RawButton);
IF DeadmanEdge.Q THEN
    DeadmanArmPending := TRUE;
END_IF;
IF NOT RawButton THEN
    DeadmanArmPending := FALSE;
END_IF;

// 🛡️ SÉCURITÉ C4 (ISO 13849) : armement STRICTEMENT conditionné par DeadmanArmPending.
// Tout désarmement (changement de mode, fin de cycle benne, passage neutre prolongé)
// efface DeadmanArmPending et EXIGE un nouvel appui conscient (front montant de RawButton).
DeadmanArmTimer(IN := DeadmanArmPending AND NOT DeadmanArmed, PT := DeadmanArmHoldTime);
IF DeadmanArmTimer.Q THEN
    DeadmanArmed := TRUE;
    DeadmanArmPending := FALSE;
END_IF;

// ⏱️ 4bis. GESTION DU DÉSARMEMENT PAR MAINTIEN AU NEUTRE
DeadmanArmGraceTimer(IN := DeadmanArmed, PT := DeadmanArmGraceTime);
NeutralHoldTimer(IN := DeadmanArmed AND AtNeutral AND DeadmanArmGraceTimer.Q,
                 PT := NeutralHoldTime);
IF NeutralHoldTimer.Q THEN
    DeadmanArmed := FALSE;      // Neutre maintenu après la grâce = désarmement
END_IF;

{endregion}

{region "§6 Pipeline axe X"}
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

{endregion}

{region "§7 Pipeline axe Y et sorties"}
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

{endregion}
