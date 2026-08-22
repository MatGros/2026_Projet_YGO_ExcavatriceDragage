(* =======================================================================
   🕹️ FB_Joystick — Acquisition & conditionnement du geste opérateur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Acquisition 2 axes Hall + bouton homme-mort normatif.
             Pipeline par axe : FB_AxisScale -> Homme-Mort -> ST_Joystick_AxisCmd.
   🔒 Sécurité : Armement homme-mort par maintien au neutre.
                 Désarmement sur neutre prolongé, changement mode ou fin benne.
   📤 Sorties : AxisCmdX/Y, signaux de diagnostic et miroirs maintenance.
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.0.md
   ======================================================================= *)

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    // === PERMIS SÉCURITÉ & ETATS SYSTEME ===
    Enable                    : BOOL;       // --> [CMD]  Active la logique du bloc (TRUE=Autorise)
    Reset                     : BOOL;       // --> [CMD]  Acquittement defaut
    Mode                      : E_Mode;     // --> [SAFE] Changement de mode desarme l'homme-mort
    BenneBusy                 : BOOL;       // --> [SAFE] Fin de cycle benne (front descendant) desarme l'homme-mort
    PreserveArmingAfterBucket : BOOL;       // --> [SAFE] Maintien armement pendant fermeture ExtractionSequence

    // === ACQUISITION MATERIELLE & DIAGNOSTIC ===
    BusCanOpenOP              : ST_Diag_Device; // --> [HW]   Etat presence noeud CAN
    JoystickOP                : ST_Diag_Device; // --> [HW]   Mode esclave CANopen actif
    RawX                      : INT;        // --> [HW]   Valeur brute axe X (0..10000)
    RawY                      : INT;        // --> [HW]   Valeur brute axe Y (0..10000)
    RawButton                 : BOOL;       // --> [HW]   Etat brut bouton homme-mort

    // === COMMANDES OPÉRATEUR & CALIBRATION ===
    BtnCalibrate              : BOOL;       // --> [CMD]  Demande de recalage neutre

    // === REGLAGES & CONFIGURATION ===
    InvertX                   : BOOL := FALSE;   // --> [CFG]  Inversion sens de l'axe X
    InvertY                   : BOOL := FALSE;   // --> [CFG]  Inversion sens de l'axe Y
    DeadbandRaw               : INT := 300;      // --> [CFG]  Zone morte en points ADC bruts (0..10000)
    NeutralHoldTime           : TIME := T#100MS; // --> [CFG]  Maintien continu au neutre avant desarmement
    DeadmanArmHoldTime        : TIME := T#100MS; // --> [CFG]  Appui continu bouton requis pour armer
    DeadmanArmGraceTime       : TIME := T#3S;    // --> [CFG]  Delai de grace post-armement avant desarmement neutre
    RawOutOfRangeMargin       : INT := 500;      // --> [CFG]  Marge tolerance ADC autour des bornes nominales [0..10000] avant defaut capteur (AF08 §5bis)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                     : BOOL;       // <-- [STAT] FB pret a fonctionner
    Busy                      : BOOL;       // <-- [STAT] Traitement en cours
    Done                      : BOOL;       // <-- [STAT] Donnees valides disponibles
    Button                    : BOOL;       // <-- [STAT] Bouton homme-mort filtre

    // === DIAGNOSTIC & ANOMALIES ===
    Error                     : BOOL;       // <-- [DIAG] Presence anomalie (miroir Status.Error)
    ErrorId                   : WORD;       // <-- [DIAG] Bit0: Echec calibration Joystick (RawX/Y hors plage)
    Status                    : ST_FbStatus; // <-- [STAT] Statut standard complet (socle FB_FbStatus)

    // === CONSIGNES AXES NORMALISEES ===
    AxisCmdX                  : ST_Joystick_AxisCmd; // <-- [ACT]  Sortie normalisee axe X
    AxisCmdY                  : ST_Joystick_AxisCmd; // <-- [ACT]  Sortie normalisee axe Y

    // === MESURES & MIROIRS MAINTENANCE ===
    NeutralXAct               : INT;        // <-- [STAT] Point neutre X actuel pour IHM/Test
    NeutralYAct               : INT;        // <-- [STAT] Point neutre Y actuel pour IHM/Test
    SpeedXPct                 : REAL;       // <-- [STAT] Consigne vitesse axe X signee (-100..+100 %), miroir AxisCmdX.SpeedRef
    DirectionX                : INT;        // <-- [STAT] Sens axe X (-1=Rev/0=Neutre/+1=Fwd), miroir AxisCmdX.Direction
    SpeedYPct                 : REAL;       // <-- [STAT] Consigne vitesse axe Y signee (-100..+100 %), miroir AxisCmdY.SpeedRef
    DirectionY                : INT;        // <-- [STAT] Sens axe Y (-1=Rev/0=Neutre/+1=Fwd), miroir AxisCmdY.Direction
    DeadmanArmed              : BOOL;       // <-- [STAT] Geste arme (bouton appuye au neutre) - IHM/diagnostic
    AtNeutral                 : BOOL;       // <-- [STAT] TRUE si les 2 axes sont en zone morte (position centrale)
END_VAR
VAR_IN_OUT
    // === RETENTION & CALIBRATION PERSISTANTE ===
    NeutralXMem               : INT;        // <-> [BUS]  Point neutre X persistant global
    NeutralYMem               : INT;        // <-> [BUS]  Point neutre Y persistant global
END_VAR
VAR
    // === SOUS-INSTANCES FB & TIMERS ===
    ScaleX                    : FB_AxisScale;        // * [INST] Normalisation et zone morte axe X
    ScaleY                    : FB_AxisScale;        // * [INST] Normalisation et zone morte axe Y
    ResetEdge                 : R_TRIG;              // * [INST] Detecteur front montant Reset
    DeadmanEdge               : R_TRIG;              // * [INST] Detecteur front montant Bouton homme-mort
    NeutralHoldTimer          : TON;                 // * [INST] Temporisation maintien au neutre
    DeadmanArmTimer           : TON;                 // * [INST] Temporisation maintien bouton armement
    DeadmanArmGraceTimer      : TON;                 // * [INST] Temporisation delai de grace post-armement
    BenneBusyFallEdge         : F_TRIG;              // * [INST] Detecteur front descendant Fin de cycle benne

    // === VARIABLES LOCALES INTERNES ===
    CmdXVal                   : REAL;                // . [LOC]  Consigne axe X calculee apres filtrage/homme-mort
    CmdYVal                   : REAL;                // . [LOC]  Consigne axe Y calculee apres filtrage/homme-mort
    LastCalibrate             : BOOL;                // . [LOC]  Memorisation etat precedent bouton calibration
    DeadmanArmPending         : BOOL;                // . [LOC]  Armement en cours d'attente de la tempo maintien
    LastMode                  : E_Mode;              // . [LOC]  Memorisation mode scan precedent pour detection changement
    RawOutOfRange             : BOOL;                // . [LOC]  Surveillance capteur continue (AF08 §5bis) : RawX/RawY hors plage nominale+marge
    ErrorIdCause              : WORD;                // . [LOC]  Cause brute agrégée alimentant le socle FB_FbStatus
    WarningMask               : WORD;                // . [LOC]  Masque des erreurs classées WARNING (bit=1) ; bit=0 -> FAULT à acquitter
    instFbStatus              : FB_FbStatus;         // * [INST] Socle de statut standard (forme cible)
    JoystickErrorTexts        : ARRAY[0..15] OF STRING;  // . [LOC] Textes IHM des erreurs joystick (par bit)
    JoystickWarningTexts      : ARRAY[0..15] OF STRING;  // . [LOC] Textes IHM des warnings joystick (par bit)
END_VAR

{region "§1 Gate securite"}
// 🛑 1. GATE (Sécurités et coupures prioritaires)
IF NOT Enable OR NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
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
    LastMode := Mode;   // Pas de faux changement détecté à la réactivation
    // 🔎 AF08 §3 : perte bus CAN / device non-opérationnel -> ErrorId bit2 (16#0004),
    // Info/Warning auto-effacé dès le retour (pas un Fault à acquitter).
    // Distingué du gate générique (Enable/PowerContactor) qui, lui, ne lève pas d'erreur.
    IF NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational THEN
        ErrorId := ErrorId OR 16#0004;
        Error := TRUE;   // le gate RETURN avant le calcul "Error := (ErrorId<>0)" -> forçage explicite
    END_IF;
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
Button := RawButton;

// 🔎 AF08 §3 : dès le retour du bus CAN / device opérationnel, le bit2 (perte HW/bus)
// s'auto-efface (Info/Warning, pas un Fault à acquitter). Ne touche pas aux autres bits.
IF BusCanOpenOP.Operational AND JoystickOP.Operational THEN
    ErrorId := ErrorId AND 16#FFFB;
END_IF;

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
AtNeutral := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);   // IHM/diagnostic — position centrale (zone morte)

// 🛡️ 4ter. SURVEILLANCE CAPTEUR CONTINUE (AF08 §5bis) — défaut hors plage ADC.
// Évaluée à CHAQUE scan (pas seulement au front BtnCalibrate). Si RawX OU RawY sort de la
// plage nominale [0..10000] + marge de tolérance, confiance perdue dans TOUT le geste :
// neutralisation des 2 axes + ErrorId bit1 (16#0002). Cause brute évaluée en continu
// (interlock toujours sur la cause, jamais sur l'acquittement) → ré-alarme auto si persistante.
RawOutOfRange := (RawX < (0 - RawOutOfRangeMargin))
              OR (RawX > (10000 + RawOutOfRangeMargin))
              OR (RawY < (0 - RawOutOfRangeMargin))
              OR (RawY > (10000 + RawOutOfRangeMargin));
IF RawOutOfRange THEN
    ErrorId := ErrorId OR 16#0002;
ELSE
    ErrorId := ErrorId AND 16#FFFD;
END_IF;
Error := (ErrorId <> 16#0000);

{endregion}

{region "§4 Desarmements changement mode et fin benne"}
// 4ter-bis. CHANGEMENT DE MODE : désarme le homme-mort dès que Mode change
// (MAINT_N1/N2/SEMI_AUTO/AUTO). Évite qu'une commande en cours traverse le changement
// de mode et soit réinterprétée soudainement. Repassage par le neutre + nouvel appui exigé.
IF Mode <> LastMode THEN
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;   // Nouvel appui exigé après changement de mode
END_IF;
LastMode := Mode;

// 4ter-ter. FIN DE CYCLE BENNE : désarmement général pour qu'une fermeture manuelle
// ne démarre jamais M1/M2 par surprise. Exception : ExtractionSequence garde l'armement
// pendant sa fermeture (enchaînement palier 1 sous ses propres interlocks synchro/position).
BenneBusyFallEdge(CLK := BenneBusy);
IF BenneBusyFallEdge.Q AND NOT PreserveArmingAfterBucket THEN
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;   // Nouvel appui exigé après fin de cycle benne
END_IF;

{endregion}

{region "§5 Armement homme mort"}
// 4ter. BOUTON HOMME-MORT — armement par MAINTIEN (DeadmanArmHoldTime), indépendant de la
// position des axes pendant l'appui.
// Armement par MAINTIEN (DeadmanArmHoldTime), indépendant de la position des axes pendant
// l'appui : appui (front) → maintien 100 ms → armé, quelle que soit la position des axes durant
// ce maintien. Relâchement AVANT la fin du maintien = tentative annulée (DeadmanArmPending
// retombe), un nouvel appui (front) est requis — pas d'armement différé "surprise" sur un appui
// prolongé après un désarmement (mode/benne/neutre). Sûr même si le joystick est déjà hors zone
// morte à la fin du maintien : les rampes d'accel/décel restent gérées par les FB aval
// (FB_Winch/FB_Translation), donc pas de démarrage brutal possible côté ce FB.
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
// Pas de filtre : le joystick est stable et ne doit pas être ralenti (décision 2026-08-22).
// Inversion de sens appliquée directement sur la sortie normalisée.
// Consigne forcée à 0.0 tant que le geste n'est pas armé (homme-mort)
// OU si le capteur est hors plage (RawOutOfRange) : confiance perdue dans tout le geste.
IF InvertX THEN
    CmdXVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, -ScaleX.OutPct);
ELSE
    CmdXVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleX.OutPct);
END_IF;

// Mapping Sortie Standardisée Axe X
AxisCmdX.Enable := NOT RawOutOfRange;
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
// Pas de filtre : le joystick est stable et ne doit pas être ralenti (décision 2026-08-22).
// Inversion de sens appliquée directement sur la sortie normalisée.
// Consigne forcée à 0.0 tant que le geste n'est pas armé (homme-mort)
// OU si le capteur est hors plage (RawOutOfRange) : confiance perdue dans tout le geste.
IF InvertY THEN
    CmdYVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, -ScaleY.OutPct);
ELSE
    CmdYVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleY.OutPct);
END_IF;

// Mapping Sortie Standardisée Axe Y
AxisCmdY.Enable := NOT RawOutOfRange;
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

// 🧩 SOCLE DE STATUT STANDARD (forme cible) — remplit Status : ST_FbStatus
// Le joystick produit ErrorId (bit0 calib, bit1 capteur, bit2 bus). On le passe au socle
// qui classe : WarningMask bit=1 → warning auto, bit=0 → fault à acquitter.
// Joystick : bit0 (calib) = FAULT à acquitter ; bit1 (capteur) + bit2 (bus) = WARNING auto.
WarningMask := 16#0006;   // bits 1+2 = warning (auto-effacés) ; bit0 = fault
ErrorIdCause := ErrorId;

// Textes IHM (par bit) — stockés dans des tableaux locaux
JoystickErrorTexts[0] := 'Echec calibration joystick (RawX/Y hors zone)';
JoystickErrorTexts[1] := 'Capteur joystick hors plage ADC';
JoystickErrorTexts[2] := 'Perte liaison bus CAN joystick';
JoystickWarningTexts[1] := 'Capteur joystick hors plage ADC (warning)';
JoystickWarningTexts[2] := 'Perte liaison bus CAN joystick (warning)';

instFbStatus(Enable := Enable, Reset := Reset,
             ErrorIdCause := ErrorIdCause, WarningMask := WarningMask,
             ErrorTexts := JoystickErrorTexts, WarningTexts := JoystickWarningTexts,
             RotatePeriod := T#1S);
Status := instFbStatus.Status;
Error := Status.Error;      // miroir (source de vérité = socle)
ErrorId := Status.ErrorId;    // miroir
Ready := NOT Error;

{endregion}
