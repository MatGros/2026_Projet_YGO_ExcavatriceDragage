(* =======================================================================
   🕹️ FB_Joystick — Acquisition & conditionnement du geste opérateur
   ───────────────────────────────────────────────────────────────
   🎯 Rôle : Acquisition 2 axes Hall + bouton homme-mort normatif.
              Pipeline par axe : FB_AxisScale -> Homme-Mort -> ST_fbJoystick_AxisCmd.
   🔒 Sécurité : Armement homme-mort par maintien au neutre.
                  Armement STRICTEMENT conditionné par ArmingPermit (permission
                  externe, vue joystick) ; FALSE = armement bloqué + warning.
                  Désarmement sur neutre prolongé ; le changement de mode / fin de
                  cycle benne est géré par l'externe via ArmingPermit (vue joystick).
   📤 Sorties : AxisCmdX/Y (struct = source unique : SpeedTgt NON signee % pour IHM + StepTgt palier 1..5 pour logique + bits sens
                + Direction -1/0/+1 et Deflection -100..+100 % pour anim IHM), Fault : ST_Fault
                (socle FB_FaultCore), AtNeutralXY (permis logique), NeutralXAct/YAct (miroirs IHM).
   🧬 Contrat : `standard` — pas de struct métier propre → `Fault : ST_Fault` à plat.
                Pas de `State` (aucune machine d'état), pas de `ST_Lifecycle` (FB synchrone).
   ⚙️ Réglages regroupés dans `Cfg : ST_fbJoystick_Cfg` (échange bloc IHM / persistant).
   📄 Doc métier : DOC/AF/AF_Partie-08_Fonction_Joystick_v2.5.md (F08.01, F08.03-F08.07)
   ===================================================================== *)

FUNCTION_BLOCK FB_Joystick
VAR_INPUT
    // === CONTRAT STANDARD (Enable + Reset) ===
    Enable                    : BOOL;       // --> [CMD]  Active la logique du bloc (TRUE=Autorise)
    Reset                     : BOOL;       // --> [CMD]  Acquittement defaut (front, jamais conditionne)

    // === PERMIS SECURITE ===
    ArmingPermit              : BOOL;       // --> [SAFE] Permission d'armement homme-mort ; FALSE = armement bloqué

    // === ACQUISITION MATERIELLE & DIAGNOSTIC ===
    BusCanOpenOP              : ST_Diag_Device; // --> [HW]   Etat presence noeud CAN
    JoystickOP                : ST_Diag_Device; // --> [HW]   Mode esclave CANopen actif
    RawX                      : INT;        // --> [HW]   Valeur brute axe X (0..10000)
    RawY                      : INT;        // --> [HW]   Valeur brute axe Y (0..10000)
    RawButton                 : BOOL;       // --> [HW]   Etat brut bouton homme-mort

    // === COMMANDES OPERATEUR & CALIBRATION ===
    Calibrate                 : BOOL;       // --> [CMD]  Front : lance la calibration (recalage du neutre)

    // === REGLAGES & CONFIGURATION ===
    Cfg                       : ST_fbJoystick_Cfg; // --> [CFG]  Réglages groupés (deadband, temporisations, marge ADC)
END_VAR
VAR_OUTPUT
    // === CONTRAT STANDARD (Ready + Fault) ===
    Ready                     : BOOL;       // <-- [STAT] FB pret a fonctionner (Enable + bus OK + pas de defaut late)
    Fault                     : ST_Fault;   // <-- [DIAG] Brique defaut socle (live + latche), remplie par FB_FaultCore

    // === CONSIGNES AXES NORMALISEES ===
    AxisCmdX                  : ST_fbJoystick_AxisCmd; // <-- [ACT]  Consigne axe X : SpeedTgt (non signee 0..100) + bits sens + Direction/Deflection (monitoring)
    AxisCmdY                  : ST_fbJoystick_AxisCmd; // <-- [ACT]  Consigne axe Y : SpeedTgt (non signee 0..100) + bits sens + Direction/Deflection (monitoring)

    // === HOMME-MORT ===
    DeadmanArmed              : BOOL;       // <-- [STAT] Geste arme (bouton maintenu + ArmingPermit) - IHM/diagnostic
    ArmingPermitDenied        : BOOL;       // <-- [DIAG] Appui homme-mort refuse (ArmingPermit=FALSE) - warning non latche (F08.08)

    // === ETAT LOGIQUE ===
    AtNeutralXY               : BOOL;       // <-- [STAT] Les 2 axes en zone morte BRUTE (ScaleX/Y.OutPct=0, AVANT homme-mort) - permis mouvement, LU EN LOGIQUE (PRG_03/04/07)

    // === MIROIRS IHM / TEST ===
    NeutralXAct               : INT;        // <-- [STAT] Point neutre X calibre courant
    NeutralYAct               : INT;        // <-- [STAT] Point neutre Y calibre courant
END_VAR
VAR_IN_OUT
    // === RETENTION & CALIBRATION PERSISTANTE ===
    NeutralXMem               : INT;        // <-> [BUS]  Point neutre X persistant global
    NeutralYMem               : INT;        // <-> [BUS]  Point neutre Y persistant global
END_VAR
VAR CONSTANT
    CST_DirectionQualificationThreshold_Pct : REAL := 0.1;  // Seuil % : axe actif (StartStop / bits sens / palier 0)
    CST_InversionFlipThreshold_Pct          : REAL := 10.0; // Seuil % : sens RETENU pour la détection d'inversion inter-scan.
                                                            // Large volontairement (>> bruit Hall, >> bord de deadband) :
                                                            // seule une déflexion franche opposée compte comme flip.
END_VAR
VAR
    // === SOUS-INSTANCES FB & TIMERS ===
    ScaleX                    : FB_AxisScale;        // * [INST] Normalisation et zone morte axe X
    ScaleY                    : FB_AxisScale;        // * [INST] Normalisation et zone morte axe Y
    DeadmanEdge               : R_TRIG;              // * [INST] Detecteur front montant bouton homme-mort
    NeutralXYEdge             : R_TRIG;              // * [INST] Front retour simultane X+Y au neutre (libere verrou inversion)
    NeutralHoldTimer          : TON;                 // * [INST] Temporisation maintien au neutre
    DeadmanArmTimer           : TON;                 // * [INST] Temporisation maintien bouton armement
    DeadmanArmGraceTimer      : TON;                 // * [INST] Temporisation delai de grace post-armement
    instFault                 : FB_FaultCore;        // * [INST] Socle de defaut (liste de causes -> ST_Fault)
    SpeedStepHyst1            : HYSTERESIS;          // * [INST] Decodage % -> palier, seuil 1 (logique FB_Winch §5)
    SpeedStepHyst2            : HYSTERESIS;          // * [INST] Decodage % -> palier, seuil 2
    SpeedStepHyst3            : HYSTERESIS;          // * [INST] Decodage % -> palier, seuil 3
    SpeedStepHyst4            : HYSTERESIS;          // * [INST] Decodage % -> palier, seuil 4

    // === VARIABLES LOCALES INTERNES ===
    CmdXVal                   : REAL;                // . [LOC]  Consigne axe X calculee apres filtrage/homme-mort
    CmdYVal                   : REAL;                // . [LOC]  Consigne axe Y calculee apres filtrage/homme-mort
    LastCalibrate             : BOOL;                // . [LOC]  Memorisation etat precedent commande Calibrate (front)
    DeadmanArmPending         : BOOL;                // . [LOC]  Armement en cours d'attente de la temporisation maintien
    InversionLockActive       : BOOL;                // . [LOC]  Verrou retour neutre apres inversion inter-scan directe
    PrevDirX                  : INT;                 // . [LOC]  Sens X qualifie au scan precedent (-1, 0, +1)
    PrevDirY                  : INT;                 // . [LOC]  Sens Y qualifie au scan precedent (-1, 0, +1)
    DirX                      : INT;                 // . [LOC]  Sens X qualifie au scan courant (-1, 0, +1)
    DirY                      : INT;                 // . [LOC]  Sens Y qualifie au scan courant (-1, 0, +1)
    FlipX                     : BOOL;                // . [LOC]  Inversion X directe sans echantillon neutre
    FlipY                     : BOOL;                // . [LOC]  Inversion Y directe sans echantillon neutre
    RawOutOfRange             : BOOL;                // . [LOC]  Surveillance capteur continue (AF08 §5bis) : RawX/RawY hors plage nominale+marge
    CalibFail                 : BOOL;                // . [LOC]  Echec calibration (front Calibrate hors zone) - cause a acquitter (latching)
    BusLost                   : BOOL;                // . [LOC]  Perte liaison bus / device non operationnel - cause live seulement
    instCauses                : ARRAY[0..15] OF ST_FaultCause;   // . [LOC] Liste des causes pour le socle FB_FaultCore
END_VAR

{region "§1 CAUSES + SOCLE (appele AVANT le gate)"}
// 🎯 CAUSES exprimées en CLAIR (liste ST_FaultCause) — plus de bitfield WORD.
//    - CalibFail : cause A ACQUITTER (Latching=TRUE) -> arme Fault.Latched.
//    - RawOutOfRange / BusLost : cause LIVE seulement (Latching=FALSE) -> Fault.Error, retombe seule.
//    Interlock sur la cause brute ; le socle gère latch/reset.
RawOutOfRange := (RawX < (0 - Cfg.RawOutOfRangeMargin))
              OR (RawX > (10000 + Cfg.RawOutOfRangeMargin))
              OR (RawY < (0 - Cfg.RawOutOfRangeMargin))
              OR (RawY > (10000 + Cfg.RawOutOfRangeMargin));
BusLost := (NOT BusCanOpenOP.Operational OR NOT JoystickOP.Operational);

// Calibration : un front (Calibrate) hors zone -> cause a acquitter. La cause reste active tant que
// les axes sont HORS zone valide [2000..8000] : Reset ne l'efface que si la cause a disparu
// (interlock socle sur la cause brute). Effacee par un Reset avec axes en zone.
IF Calibrate AND NOT LastCalibrate THEN
    IF RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000 THEN
        NeutralXMem := RawX;       // memorisation nouvelle position neutre X
        NeutralYMem := RawY;       // memorisation nouvelle position neutre Y
        CalibFail := FALSE;        // calibration valide : plus de cause
    ELSE
        CalibFail := TRUE;         // échec : cause a acquitter (persistante tant que hors zone)
    END_IF;
END_IF;
LastCalibrate := Calibrate;
// Ré-acquisition de la cause (front Reset + cause disparue) : n'efface la cause QUE si les
// axes sont revenus en zone valide. Reste latee tant que hors zone (interlock sur cause brute).
IF Reset AND (RawX >= 2000 AND RawX <= 8000 AND RawY >= 2000 AND RawY <= 8000) THEN
    CalibFail := FALSE;
END_IF;

// Remplissage de la LISTE de causes pour le socle (index 0..2)
// Cause en clair (Active/Latching/Texte) ; 3 causes fixes.
instCauses[0].Active := CalibFail;     instCauses[0].Latching := TRUE;
instCauses[0].Texte := 'Echec calibration joystick (RawX/Y hors zone)';
instCauses[1].Active := RawOutOfRange; instCauses[1].Latching := FALSE;
instCauses[1].Texte := 'Capteur joystick hors plage ADC';
instCauses[2].Active := BusLost;       instCauses[2].Latching := FALSE;
instCauses[2].Texte := 'Perte liaison bus CAN joystick';

// Appel du socle TOUJOURS (meme si le gate RETURN ensuite) : la cause bus doit etre vue.
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;     // source de verite = socle

// Disponibilite = Enable + bus OK + pas de defaut LATE. Une cause live (bus, capteur) ne latche pas
// -> elle n'entre pas dans Fault.Latched ; le bus est deja couvert par ...OP.Operational ci-dessous.
Ready := Enable AND BusCanOpenOP.Operational AND JoystickOP.Operational AND NOT Fault.Latched;
{endregion}

{region "§2 Gate securite (neutralisation pipeline, n efface pas le statut)"}
// 1. GATE — neutralise le pipeline si indisponible. Le statut a deja ete rempli (zone 0).
IF NOT Enable OR BusLost THEN
    AxisCmdX.Enable := FALSE; AxisCmdX.StartStop := FALSE; AxisCmdX.SpeedTgt := 0.0; AxisCmdX.StepTgt := 0;
    AxisCmdX.DirectionPositive := FALSE; AxisCmdX.DirectionNegative := FALSE; AxisCmdX.AtNeutral := TRUE;
    AxisCmdY.Enable := FALSE; AxisCmdY.StartStop := FALSE; AxisCmdY.SpeedTgt := 0.0; AxisCmdY.StepTgt := 0;
    AxisCmdY.DirectionPositive := FALSE; AxisCmdY.DirectionNegative := FALSE; AxisCmdY.AtNeutral := TRUE;
    AxisCmdX.Direction := 0; AxisCmdX.Deflection := 0;
    AxisCmdY.Direction := 0; AxisCmdY.Deflection := 0;
    AtNeutralXY := TRUE;
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;
    InversionLockActive := FALSE;
    PrevDirX := 0;
    PrevDirY := 0;
    ArmingPermitDenied := FALSE;
    NeutralXYEdge(CLK := FALSE);
    NeutralHoldTimer(IN := FALSE, PT := Cfg.NeutralHoldTime);
    DeadmanArmTimer(IN := FALSE, PT := Cfg.DeadmanArmHoldTime);
    DeadmanArmGraceTimer(IN := FALSE, PT := Cfg.DeadmanArmGraceTime);
    NeutralXAct := NeutralXMem;
    NeutralYAct := NeutralYMem;
    RETURN;
END_IF;
{endregion}

{region "§3 Acquisition + mise a l echelle"}
// Mise a l'echelle (deadband) - le neutre s'evalue sur les 2 axes
ScaleX(RawIn := RawX, Neutral := NeutralXMem, DeadbandRaw := Cfg.DeadbandRaw);
ScaleY(RawIn := RawY, Neutral := NeutralYMem, DeadbandRaw := Cfg.DeadbandRaw);
AtNeutralXY := (ScaleX.OutPct = 0.0) AND (ScaleY.OutPct = 0.0);   // les 2 axes en zone morte - permis mouvement
{endregion}

{region "§4 Armement homme mort"}
// 🔀 Inversion inter-scan : le sens n'est RETENU que si la déflexion dépasse
// CST_InversionFlipThreshold_Pct (>> bruit Hall / bord de deadband). Un aller-retour
// +1<->-1 sans échantillon 0 pose le verrou. Levé exclusivement au front AtNeutralXY.
// RawOutOfRange : lecture capteur non fiable -> aucun sens retenu (le geste est déjà forcé à 0
// par le SEL du pipeline). Une reprise capteur-défaut -> valide ne compte donc pas comme flip.
DirX := 0;
DirY := 0;
IF NOT RawOutOfRange THEN
    IF ScaleX.OutPct > CST_InversionFlipThreshold_Pct THEN
        DirX := 1;
    ELSIF ScaleX.OutPct < -CST_InversionFlipThreshold_Pct THEN
        DirX := -1;
    END_IF;
    IF ScaleY.OutPct > CST_InversionFlipThreshold_Pct THEN
        DirY := 1;
    ELSIF ScaleY.OutPct < -CST_InversionFlipThreshold_Pct THEN
        DirY := -1;
    END_IF;
END_IF;
FlipX := ((PrevDirX = 1) AND (DirX = -1)) OR ((PrevDirX = -1) AND (DirX = 1));
FlipY := ((PrevDirY = 1) AND (DirY = -1)) OR ((PrevDirY = -1) AND (DirY = 1));

NeutralXYEdge(CLK := AtNeutralXY);
IF NeutralXYEdge.Q THEN
    InversionLockActive := FALSE;
END_IF;

IF FlipX OR FlipY THEN
    InversionLockActive := TRUE;
    DeadmanArmed := FALSE;
    DeadmanArmPending := FALSE;
END_IF;

// Bouton homme-mort : armement par MAINTIEN (Cfg.DeadmanArmHoldTime), independant de la position.
// ⚠️ Un appui PENDANT le verrou d'inversion n'arme PAS de demande : le nouveau front conscient
//    doit survenir APRÈS le retour au neutre (sinon on "pré-charge" le réarmement stick inversé).
DeadmanEdge(CLK := RawButton);
IF DeadmanEdge.Q AND NOT InversionLockActive THEN DeadmanArmPending := TRUE; END_IF;
IF NOT RawButton THEN DeadmanArmPending := FALSE; END_IF;

// Securite : armage UNIQUEMENT si DeadmanArmPending ET ArmingPermit.
DeadmanArmTimer(IN := DeadmanArmPending AND NOT DeadmanArmed AND ArmingPermit AND NOT InversionLockActive, PT := Cfg.DeadmanArmHoldTime);
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
DeadmanArmGraceTimer(IN := DeadmanArmed, PT := Cfg.DeadmanArmGraceTime);
NeutralHoldTimer(IN := DeadmanArmed AND AtNeutralXY AND DeadmanArmGraceTimer.Q, PT := Cfg.NeutralHoldTime);
IF NeutralHoldTimer.Q THEN DeadmanArmed := FALSE; END_IF;
{endregion}

{region "§5 Pipeline axe X"}
CmdXVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleX.OutPct);

AxisCmdX.Enable := NOT RawOutOfRange AND ArmingPermit;
AxisCmdX.SpeedTgt := ABS(CmdXVal);   // NON signee (le sens = bits DirectionPositive/Negative + AxisCmdX.Direction)
AxisCmdX.StartStop := (ABS(CmdXVal) > CST_DirectionQualificationThreshold_Pct);

AxisCmdX.DirectionPositive := (CmdXVal > CST_DirectionQualificationThreshold_Pct);
AxisCmdX.DirectionNegative := (CmdXVal < -CST_DirectionQualificationThreshold_Pct);
AxisCmdX.AtNeutral := NOT AxisCmdX.DirectionPositive AND NOT AxisCmdX.DirectionNegative;
IF AxisCmdX.AtNeutral THEN AxisCmdX.SpeedTgt := 0.0; END_IF;

// Projections monitoring dans le struct (les bits restent la source logique)
IF AxisCmdX.DirectionPositive THEN AxisCmdX.Direction := 1;
ELSIF AxisCmdX.DirectionNegative THEN AxisCmdX.Direction := -1;
ELSE AxisCmdX.Direction := 0; END_IF;
AxisCmdX.Deflection := REAL_TO_INT(CmdXVal);   // deflexion signee -100..+100 % (anim IHM)
{endregion}

{region "§6 Pipeline axe Y et sorties"}
CmdYVal := SEL(DeadmanArmed AND NOT RawOutOfRange, 0.0, ScaleY.OutPct);

AxisCmdY.Enable := NOT RawOutOfRange AND ArmingPermit;
AxisCmdY.SpeedTgt := ABS(CmdYVal);   // NON signee (le sens = bits DirectionPositive/Negative + AxisCmdY.Direction)
AxisCmdY.StartStop := (ABS(CmdYVal) > CST_DirectionQualificationThreshold_Pct);

AxisCmdY.DirectionPositive := (CmdYVal > CST_DirectionQualificationThreshold_Pct);
AxisCmdY.DirectionNegative := (CmdYVal < -CST_DirectionQualificationThreshold_Pct);
AxisCmdY.AtNeutral := NOT AxisCmdY.DirectionPositive AND NOT AxisCmdY.DirectionNegative;
IF AxisCmdY.AtNeutral THEN AxisCmdY.SpeedTgt := 0.0; END_IF;

// 🪜 Decodage consigne % -> palier (logique FB_Winch §5, deplacee au joystick).
//    AxisCmdY.SpeedTgt (%) reste pour l'IHM ; AxisCmdY.StepTgt (1..5, 0=arret) pour la logique/limitations.
SpeedStepHyst1(IN := REAL_TO_INT(AxisCmdY.SpeedTgt), HIGH := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[1] + Cfg.SpeedStepHystMargin), LOW := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[1] - Cfg.SpeedStepHystMargin));
SpeedStepHyst2(IN := REAL_TO_INT(AxisCmdY.SpeedTgt), HIGH := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[2] + Cfg.SpeedStepHystMargin), LOW := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[2] - Cfg.SpeedStepHystMargin));
SpeedStepHyst3(IN := REAL_TO_INT(AxisCmdY.SpeedTgt), HIGH := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[3] + Cfg.SpeedStepHystMargin), LOW := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[3] - Cfg.SpeedStepHystMargin));
SpeedStepHyst4(IN := REAL_TO_INT(AxisCmdY.SpeedTgt), HIGH := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[4] + Cfg.SpeedStepHystMargin), LOW := REAL_TO_INT(Cfg.SpeedStepTable.StepThreshold_Pct[4] - Cfg.SpeedStepHystMargin));

// ⚠️ HYSTERESIS (Util CODESYS) est un hystérésis BAS : OUT=TRUE quand IN<LOW, OUT=FALSE
//    quand IN>HIGH. Pour un décodage ASCENDANT (petite déflexion → palier bas, grande →
//    palier haut) on teste donc `NOT OUT` : palier supérieur seulement une fois IN au-dessus
//    du seuil (bande d'hystérésis LOW..HIGH autour de StepThreshold_Pct[n]).
IF AxisCmdY.SpeedTgt <= CST_DirectionQualificationThreshold_Pct THEN
    AxisCmdY.StepTgt := 0;
ELSE
    AxisCmdY.StepTgt := 1;
    IF NOT SpeedStepHyst1.OUT THEN AxisCmdY.StepTgt := 2; END_IF;
    IF NOT SpeedStepHyst2.OUT THEN AxisCmdY.StepTgt := 3; END_IF;
    IF NOT SpeedStepHyst3.OUT THEN AxisCmdY.StepTgt := 4; END_IF;
    IF NOT SpeedStepHyst4.OUT THEN AxisCmdY.StepTgt := 5; END_IF;
END_IF;

// Projections monitoring dans le struct (les bits restent la source logique)
IF AxisCmdY.DirectionPositive THEN AxisCmdY.Direction := 1;
ELSIF AxisCmdY.DirectionNegative THEN AxisCmdY.Direction := -1;
ELSE AxisCmdY.Direction := 0; END_IF;
AxisCmdY.Deflection := REAL_TO_INT(CmdYVal);   // deflexion signee -100..+100 % (anim IHM)

// Memorisation apres traitement : l'inversion suivante compare deux scans qualifies successifs.
PrevDirX := DirX;
PrevDirY := DirY;

// Miroirs point neutre courant
NeutralXAct := NeutralXMem;
NeutralYAct := NeutralYMem;
{endregion}

END_FUNCTION_BLOCK
