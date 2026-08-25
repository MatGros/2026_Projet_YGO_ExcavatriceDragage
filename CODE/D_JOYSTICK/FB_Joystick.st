(* =======================================================================
   🕹️ FB_Joystick — Acquisition & conditionnement du geste opérateur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Acquisition 2 axes Hall + bouton homme-mort normatif.
              Pipeline par axe : FB_AxisScale -> Homme-Mort -> ST_Joystick_AxisCmd.
   🔒 Sécurité : Armement homme-mort par maintien au neutre.
                  Armement STRICTEMENT conditionné par ArmingPermit (permission
                  externe, vue joystick) ; FALSE = armement bloqué + warning.
                  Désarmement sur neutre prolongé ; le changement de mode / fin de
                  cycle benne est géré par l'externe via ArmingPermit (vue joystick).
   📤 Sorties : AxisCmdX/Y, signaux de diagnostic et miroirs maintenance.
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.1.md (F08.01, F08.03-F08.07)
   ===================================================================== *)

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    // === PERMIS SÉCURITÉ & ETATS SYSTEME ===
    Enable                    : BOOL;       // --> [CMD]  Active la logique du bloc (TRUE=Autorise)
    Reset                     : BOOL;       // --> [CMD]  Acquittement defaut
    ArmingPermit              : BOOL;       // --> [SAFE] Permission d'armement homme-mort ; FALSE = armement bloqué

    // === ACQUISITION MATERIELLE & DIAGNOSTIC ===
    BusCanOpenOP              : ST_Diag_Device; // --> [HW]   Etat presence noeud CAN
    JoystickOP                : ST_Diag_Device; // --> [HW]   Mode esclave CANopen actif
    RawX                      : INT;        // --> [HW]   Valeur brute axe X (0..10000)
    RawY                      : INT;        // --> [HW]   Valeur brute axe Y (0..10000)
    RawButton                 : BOOL;       // --> [HW]   Etat brut bouton homme-mort

    // === COMMANDES OPÉRATEUR & CALIBRATION ===
    BtnCalibrate              : BOOL;       // --> [CMD]  Demande de recalage neutre

    // === REGLAGES & CONFIGURATION ===
    DeadbandRaw               : INT := 300;      // --> [CFG]  Zone morte en points ADC bruts (0..10000)
    NeutralHoldTime           : TIME := T#100MS; // --> [CFG]  Maintien continu au neutre avant desarmement
    DeadmanArmHoldTime        : TIME := T#100MS; // --> [CFG]  Appui continu bouton requis pour armer
    DeadmanArmGraceTime       : TIME := T#3S;    // --> [CFG]  Delai de grace post-armement avant desarmement neutre
    RawOutOfRangeMargin       : INT := 500;     // --> [CFG]  Marge tolerance ADC autour des bornes nominales [0..10000] avant defaut capteur (AF08 §5bis)
END_VAR
VAR_OUTPUT
    // === ETATS IEC & SYNOPTIQUE ===
    Ready                     : BOOL;       // <-- [STAT] FB pret a fonctionner (Enable + bus OK + pas de defaut)
    Button                    : BOOL;       // <-- [STAT] Bouton homme-mort filtre

    // === DIAGNOSTIC & ANOMALIES ===
    Error                     : BOOL;       // <-- [DIAG] Presence defaut (miroir Status.Error)
    ErrorId                   : WORD;       // <-- [DIAG] Identifiant defaut courant (reconstruit par le socle)
    ArmingPermitDenied        : BOOL;       // <-- [DIAG] Warning "armement non permis" : appui homme-mort mais ArmingPermit=FALSE (sortie dediee, AC2)
    Status                    : ST_FbStatus; // <-- [STAT] Statut standard complet (socle FB_FbStatus)

    // === CONSIGNES AXES NORMALISEES ===
    AxisCmdX                  : ST_Joystick_AxisCmd; // <-- [ACT]  Sortie normalisee axe X
    AxisCmdY                  : ST_Joystick_AxisCmd; // <-- [ACT]  Sortie normalisee axe Y

    // === MESURES & MIROIRS MAINTENANCE ===
    NeutralXAct               : INT;        // <-- [STAT] Point neutre X actuel pour IHM/Test
    NeutralYAct               : INT;        // <-- [STAT] Point neutre Y actuel pour IHM/Test
    SpeedXPct                 : REAL;       // <-- [STAT] Consigne vitesse axe X signee (-100..+100 %), miroir AxisCmdX.SpeedRef
    DirectionX                : INT;        // <-- [STAT] Sens axe X (-1=Rev/0=Neutre/+1=Fwd), derive des bits AxisCmdX.DirectionPositive/Negative
    SpeedYPct                 : REAL;       // <-- [STAT] Consigne vitesse axe Y signee (-100..+100 %), miroir AxisCmdY.SpeedRef
    DirectionY                : INT;        // <-- [STAT] Sens axe Y (-1=Rev/0=Neutre/+1=Fwd), derive des bits AxisCmdY.DirectionPositive/Negative
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
    DeadmanEdge               : R_TRIG;              // * [INST] Detecteur front montant bouton homme-mort
    NeutralHoldTimer          : TON;                 // * [INST] Temporisation maintien au neutre
    DeadmanArmTimer           : TON;                 // * [INST] Temporisation maintien bouton armement
    DeadmanArmGraceTimer      : TON;                 // * [INST] Temporisation delai de grace post-armement
    instFbStatus              : FB_FbStatus;         // * [INST] Socle de statut standard (liste de causes)

    // === VARIABLES LOCALES INTERNES ===
    CmdXVal                   : REAL;                // . [LOC]  Consigne axe X calculee apres filtrage/homme-mort
    CmdYVal                   : REAL;                // . [LOC]  Consigne axe Y calculee apres filtrage/homme-mort
    LastCalibrate             : BOOL;                // . [LOC]  Memorisation etat precedent bouton calibration
    DeadmanArmPending         : BOOL;                // . [LOC]  Armement en cours d'attente de la temporisation maintien
    RawOutOfRange             : BOOL;                // . [LOC]  Surveillance capteur continue (AF08 §5bis) : RawX/RawY hors plage nominale+marge
    CalibFail                 : BOOL;                // . [LOC]  Echec recalage neutre (front BtnCalibrate hors zone) - cause fault (liste)
    BusLost                   : BOOL;                // . [LOC]  Perte liaison bus / device non operationnel - cause warning (liste)
    instCauses                : ARRAY[0..15] OF ST_FbCause;   // . [LOC] Liste des causes pour le socle FB_FbStatus
END_VAR

{region "§1 CAUSES + SOCLE (appele AVANT le gate)"}
// 🎯 CAUSES exprimées en CLAIR (liste ST_FbCause) — plus de bitfield WORD.
//    - CalibFail : fault à acquitter (IsWarning=FALSE).
//    - RawOutOfRange / BusLost : warning auto-effacés (décision utilisateur).
//    Interlock sur la cause brute ; le socle gère latch/reset/textes.
RawOutOfRange := (RawX < (0 - RawOutOfRangeMargin))
              OR (RawX > (10000 + RawOutOfRangeMargin))
              OR (RawY < (0 - RawOutOfRangeMargin))
              OR (RawY > (10000 + RawOutOfRangeMargin));
BusLost := (NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational);

// Calibration : un front (BtnCalibrate) hors zone -> fault. La cause reste active tant que les
// axes sont HORS zone valide [2000..8000] : Reset ne l'acquitte que si la cause a disparu
// (interlock socle sur la cause brute). Effacée par un Reset avec axes en zone.
IF BtnCalibrate AND NOT LastCalibrate THEN
    IF RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000 THEN
        NeutralXMem := RawX;       // memorisation nouvelle position neutre X
        NeutralYMem := RawY;       // memorisation nouvelle position neutre Y
        CalibFail := FALSE;        // calibration valide : plus de cause
    ELSE
        CalibFail := TRUE;         // échec : cause fault (persistante tant que hors zone)
    END_IF;
END_IF;
LastCalibrate := BtnCalibrate;
// Ré-acquisition de la cause (front Reset + cause disparue) : n'efface la cause QUE si les
// axes sont revenus en zone valide. Reste laté tant que hors zone (interlock sur cause brute).
IF Reset AND (RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000) THEN
    CalibFail := FALSE;
END_IF;

// Remplissage de la LISTE de causes pour le socle (index 0..2)
// Cause en clair (Active/IsWarning/Texte) ; 3 causes fixes.
instCauses[0].Active := CalibFail;     instCauses[0].IsWarning := FALSE;
instCauses[0].Texte := 'Echec recalage neutre joystick (RawX/Y hors zone)';
instCauses[1].Active := RawOutOfRange; instCauses[1].IsWarning := TRUE;
instCauses[1].Texte := 'Capteur joystick hors plage ADC';
instCauses[2].Active := BusLost;       instCauses[2].IsWarning := TRUE;
instCauses[2].Texte := 'Perte liaison bus CAN joystick';

// Appel du socle TOUJOURS (meme si le gate RETURN ensuite) : la cause bus doit etre vue.
instFbStatus(Enable := Enable, Reset := Reset, Causes := instCauses);
Status := instFbStatus.Status;
Error := Status.Error;        // miroir (source de verite = socle)
ErrorId := Status.ErrorId;    // miroir

// Disponibilite = Enable + bus OK + pas de defaut. Un warning ne rend PAS indisponible.
Ready := Enable AND BusCanOpenOP.Operational AND JoystickOP.Operational AND NOT Error;
{endregion}

{region "§2 Gate securite (neutralisation pipeline, n efface pas le statut)"}
// 1. GATE — neutralise le pipeline si indisponible. Le statut a deja ete rempli (zone 0).
IF NOT Enable OR BusLost THEN
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedRef := 0.0;
    AxisCmdX.DirectionPositive := FALSE; AxisCmdX.DirectionNegative := FALSE; AxisCmdX.AtNeutral := TRUE;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedRef := 0.0;
    AxisCmdY.DirectionPositive := FALSE; AxisCmdY.DirectionNegative := FALSE; AxisCmdY.AtNeutral := TRUE;
    SpeedXPct := 0.0; DirectionX := 0;
    SpeedYPct := 0.0; DirectionY := 0;
    Button := FALSE;
    AtNeutral := TRUE;
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;
    ArmingPermitDenied := FALSE;
    NeutralHoldTimer(IN := FALSE, PT := NeutralHoldTime);
    DeadmanArmTimer(IN := FALSE, PT := DeadmanArmHoldTime);
    DeadmanArmGraceTimer(IN := FALSE, PT := DeadmanArmGraceTime);
    NeutralXAct := NeutralXMem;
    NeutralYAct := NeutralYMem;
    RETURN;
END_IF;
{endregion}

{region "§3 Acquisition bouton + mise a l echelle"}
Button := RawButton;

// Mise a l'echelle (deadband) - le neutre s'evalue sur les 2 axes
ScaleX(RawIn := RawX, Neutral := NeutralXMem, DeadbandRaw := DeadbandRaw);
ScaleY(RawIn := RawY, Neutral := NeutralYMem, DeadbandRaw := DeadbandRaw);
AtNeutral := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);   // IHM/diagnostic - position centrale
{endregion}

{region "§4 Armement homme mort"}
// Bouton homme-mort : armement par MAINTIEN (DeadmanArmHoldTime), independant de la position.
DeadmanEdge(CLK := RawButton);
IF DeadmanEdge.Q THEN DeadmanArmPending := TRUE; END_IF;
IF NOT RawButton THEN DeadmanArmPending := FALSE; END_IF;

// Securite : armage UNIQUEMENT si DeadmanArmPending ET ArmingPermit.
DeadmanArmTimer(IN := DeadmanArmPending AND NOT DeadmanArmed AND ArmingPermit, PT := DeadmanArmHoldTime);
IF DeadmanArmTimer.Q THEN
    DeadmanArmed := TRUE;
    DeadmanArmPending := FALSE;
END_IF;

// Désarmement externe immédiat : le retrait d'ArmingPermit (changement de mode, fin de cycle
// benne) désarme TOUT DE SUITE le geste — pas d'armement résiduel "surprise" à la ré-acquisition.
IF NOT ArmingPermit THEN
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;
END_IF;

// Avertissement "armage non autorise" (niveau, pendant l'appui non autorise)
ArmingPermitDenied := RawButton AND NOT ArmingPermit;

// Desarmage par maintien au neutre (apres grace)
DeadmanArmGraceTimer(IN := DeadmanArmed, PT := DeadmanArmGraceTime);
NeutralHoldTimer(IN := DeadmanArmed AND AtNeutral AND DeadmanArmGraceTimer.Q, PT := NeutralHoldTime);
IF NeutralHoldTimer.Q THEN DeadmanArmed := FALSE; END_IF;
{endregion}

{region "§5 Pipeline axe X"}
CmdXVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleX.OutPct);

AxisCmdX.Enable := NOT RawOutOfRange AND ArmingPermit;
AxisCmdX.SpeedRef := CmdXVal;
AxisCmdX.StartStop := (ABS(CmdXVal) > 0.1);

AxisCmdX.DirectionPositive := (CmdXVal > 0.1);
AxisCmdX.DirectionNegative := (CmdXVal < -0.1);
AxisCmdX.AtNeutral := NOT AxisCmdX.DirectionPositive AND NOT AxisCmdX.DirectionNegative;
IF AxisCmdX.AtNeutral THEN AxisCmdX.SpeedRef := 0.0; END_IF;

// Miroirs
SpeedXPct := AxisCmdX.SpeedRef;
IF AxisCmdX.DirectionPositive THEN DirectionX := 1;
ELSIF AxisCmdX.DirectionNegative THEN DirectionX := -1;
ELSE DirectionX := 0; END_IF;
{endregion}

{region "§6 Pipeline axe Y et sorties"}
CmdYVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleY.OutPct);

AxisCmdY.Enable := NOT RawOutOfRange AND ArmingPermit;
AxisCmdY.SpeedRef := CmdYVal;
AxisCmdY.StartStop := (ABS(CmdYVal) > 0.1);

AxisCmdY.DirectionPositive := (CmdYVal > 0.1);
AxisCmdY.DirectionNegative := (CmdYVal < -0.1);
AxisCmdY.AtNeutral := NOT AxisCmdY.DirectionPositive AND NOT AxisCmdY.DirectionNegative;
IF AxisCmdY.AtNeutral THEN AxisCmdY.SpeedRef := 0.0; END_IF;

// Miroirs
SpeedYPct := AxisCmdY.SpeedRef;
IF AxisCmdY.DirectionPositive THEN DirectionY := 1;
ELSIF AxisCmdY.DirectionNegative THEN DirectionY := -1;
ELSE DirectionY := 0; END_IF;

// Validation des sorties etat
NeutralXAct := NeutralXMem;
NeutralYAct := NeutralYMem;
{endregion}

END_FUNCTION_BLOCK
