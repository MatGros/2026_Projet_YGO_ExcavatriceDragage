(* ═══════════════════════════════════════════════════════════════
   ⚙️ FB_Translation — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔌 FB DE MOUVEMENT : porte StartStop + SafeStop en plus de l'interface
      standard. Précédence Enable > SafeStop > StartStop.
   Pilotage exclusivement ETHERCAT nominal (mot de commande, consigne fréquence).
   🔧 Interface plate → structs : configuration regroupée en `Cfg : ST_fbTranslation_Cfg`
      (pattern NC-110/G380, comme FB_Winch `Config : ST_fbWinch_Cfg`). Source unique
      GVL_PERSISTENT (câblée par PRG_05_Translation).
   🧩 Compose FB_Brake (réutilisé TEL QUEL depuis COMMUN).
   🎯 Invariant : toute inversion de sens force la cible de rampe à 0.0 tant que le
      changement de sens est en attente, pour garantir le croisement du seuil d'arrêt
      qui autorise l'interlock de changement de sens (§5).
   ═══════════════════════════════════════════════════════════════ *)

FUNCTION_BLOCK PUBLIC FB_Translation
VAR_INPUT
    Enable                      : BOOL;        // --> [CMD] Active le FB. FALSE = neutralisation totale (sorties coupées)
    Reset                       : BOOL;        // --> [CMD] Acquittement défaut (front)
    PowerContactorEngaged       : BOOL;        // --> [SAFE] Chaîne AU réarmée + conditions globales OK
    Mode                        : E_Mode;      // --> [CMD] Mode courant
    StartStop                   : BOOL;        // --> [CMD] TRUE = rampe accélération, FALSE = rampe décélération NORMALE
    SafeStop                    : BOOL;        // --> [SAFE] Sortie FB_Safety_Translation : TRUE = rampe décélération RAPIDE (Enable maintenu)
    Direction                   : INT;         // --> [CMD] -1 = Rev, 0 = Neutre, +1 = Fwd (source d'autorité du sens)
    SpeedTgt_Pct                : REAL;        // --> [CMD] Magnitude de la consigne (de 0 à 100%)
    PositionSensorTarget        : BOOL;        // --> [HW] Capteur position cible courante
    SlowdownSensorTremie        : BOOL;        // --> [HW] Capteur PV — ralentissement avant Trémie (Direction=1)
    SlowdownSensorMaintenance   : BOOL;        // --> [HW] Capteur P1 — ralentissement avant Maintenance (Direction=-1)
    SlowdownSensorP1            : BOOL;        // --> [HW] Capteur P2 — ralentissement avant P1 (Direction=-1)
    LimitSwitchFwd              : BOOL;        // --> [HW] Fin de course extrême avant
    LimitSwitchRev              : BOOL;        // --> [HW] Fin de course extrême arrière

    // 🔌 Spécifique ETHERCAT
    DriveStatusWord             : WORD;       // --> [HW] Mot d'état AC600 lu depuis l'image d'entrée EtherCAT
    DriveActualFreqHz           : REAL;       // --> [HW] Fréquence réelle mesurée (Hz)

    BypassContactorCheck        : BOOL;       // --> [TST] TRUE = désactive StuckClosed/StuckOpen pour le frein (simulation)
    BypassLimitSwitch           : BOOL;       // --> [TST] TRUE = ignore les fins de course extrêmes
    BrakeFeedback               : BOOL;       // --> [HW] Retour physique direct : TRUE = frein OUVERT (desserré)
    InvertDriveDirection        : BOOL;

    // 🔧 Configuration regroupée (pattern NC-110/G380 — un seul point d'interface)
    Cfg                         : ST_fbTranslation_Cfg; // --> [CFG] Rampe, vitesses d'approche, échelle, frein (source GVL_PERSISTENT)
END_VAR
VAR_OUTPUT
    Ready                       : BOOL;   // <-- [STAT] FB prêt (sortie libre, hors ST_Status)
    // 🧩 Statut transverse (forme cible ST_Fault)
    Fault                       : ST_Fault;
    TargetReached               : BOOL;       // <-- [STAT] Capteur position cible
    RequestedDriveControlWord   : WORD; // <-- [ACT] Demande métier AC600, arbitrée par FB_TranslationOutputInterlock
    RequestedDriveFreqHz        : REAL; // <-- [ACT] Demande métier fréquence, arbitrée par FB_TranslationOutputInterlock
    BrakeReleaseRequest         : BOOL; // <-- [ACT] Demande métier desserrage, issue de FB_Brake
    BrakeCommandOpenConfirmed   : BOOL; // <-- [STAT] TRUE = frein ouvert = commande ouverture confirmée (depuis FB_Brake)
    BrakeContactorCheck         : ST_ContactorCheck; // <-- [DIAG] Diag contacteur frein
END_VAR
VAR
    Brake                       : FB_Brake;       // * [INST] Séquence frein
    CycleTimeCalc               : FB_CycleTime;   // * [INST] Mesure temps de cycle
    SpeedRamp                   : FB_Ramp;       // * [INST] Rampe de vitesse logicielle (PLC)
    ResetEdge                   : R_TRIG;   // . [LOC] Front Reset
    DirectionChangeDelay        : TON;            // . [LOC] Interlock changement de sens
    CommandedDirection          : INT;            // . [LOC] Sens réellement appliqué
    DirectionChangePending      : BOOL;         // . [LOC] Force la rampe à 0 pendant une inversion de sens en attente
    PhysicalDriveDirection      : INT;          // . [LOC] CommandedDirection compensé câblage
    RampTargetPct               : REAL;   // . [LOC] Cible rampe en %
    CaptorDebounceTon           : TON;    // . [LOC] Debounce capteur cible
    ArrivalEdge                 : R_TRIG;   // . [LOC] Front arrivée sur capteur
    DirectionAtArrival           : INT;    // . [LOC] Sens d'arrivée mémorisé
    ArrivalLock                 : BOOL;        // . [LOC] Arrêt exact sur capteur cible
    MovementRequested           : BOOL;         // . [LOC] Pilote FB_Brake
    FirstScanDone               : BOOL;   // . [LOC] Initialisation premier scan
    TonBrakeRealFreqTimeout     : TON;

    // Défauts
    DriveFaultLatching          : BOOL;   // . [LOC] Latch défaut variateur
    instFault                   : FB_FaultCore;                  // * [INST] Socle défaut transverse
    instCauses                  : ARRAY[0..15] OF ST_FaultCause; // . [LOC] Table des causes nommées
END_VAR

// === IMPLEMENTATION ===

{region "§1 Causes & Socle Défaut (évalué en continu)"}
// 🔑 1. RESET FRONT
ResetEdge(CLK := Reset);

IF ResetEdge.Q THEN
    DriveFaultLatching := FALSE;
END_IF;

IF DriveStatusWord.4 THEN
    DriveFaultLatching := TRUE;
END_IF;

instCauses[0].Active   := Brake.Fault.Error;
instCauses[0].Latching := FALSE;
instCauses[0].Texte    := 'Defaut sequence ou retour frein translation';

instCauses[3].Active   := DriveFaultLatching;
instCauses[3].Latching := TRUE;
instCauses[3].Texte    := 'Defaut variateur translation AC600';

IF NOT BypassLimitSwitch AND ((CommandedDirection = 1 AND LimitSwitchFwd) OR (CommandedDirection = -1 AND LimitSwitchRev)) THEN
    instCauses[6].Active := TRUE;
ELSE
    instCauses[6].Active := FALSE;
END_IF;
instCauses[6].Latching := FALSE;
instCauses[6].Texte    := 'Limite extreme translation atteinte';

// Appel du socle de défaut
instFault(Enable := Enable, Reset := Reset, Causes := instCauses);
Fault := instFault.Fault;
{endregion}

{region "§2 Gate neutralisation"}
// 🛑 2. GATE
IF NOT Enable THEN
    SpeedRamp(Target := 0.0, AccelRate := 0.0, DecelRate := 100000.0, CycleTimeS := 1.0);
    Brake(Enable := FALSE);
    RequestedDriveControlWord := 0;
    RequestedDriveFreqHz := 0.0;
    BrakeReleaseRequest := FALSE;
    BrakeCommandOpenConfirmed := FALSE;
    BrakeContactorCheck.Command := FALSE;
    BrakeContactorCheck.Feedback := BrakeFeedback;
    CommandedDirection := 0;
    DirectionChangePending := FALSE;
    ArrivalLock := FALSE;
    TargetReached := FALSE;
    DirectionChangeDelay(IN := FALSE);
    CaptorDebounceTon(IN := FALSE);
    TonBrakeRealFreqTimeout(IN := FALSE);
    Ready := FALSE;
    RETURN;
END_IF;

Ready := Enable AND NOT Fault.Latched;
{endregion}

{region "§3 Premier scan et temps de cycle"}
IF NOT FirstScanDone THEN
    FirstScanDone := TRUE;
    CommandedDirection := Direction;
END_IF;

CycleTimeCalc();
{endregion}

{region "§4 Arrivée sur cible et interlock direction"}
CaptorDebounceTon(IN := PositionSensorTarget, PT := Cfg.CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;
ArrivalEdge(CLK := TargetReached);

IF ArrivalEdge.Q THEN
    ArrivalLock := TRUE;
    DirectionAtArrival := CommandedDirection;
END_IF;

IF ArrivalLock AND (Direction <> 0) AND (Direction <> DirectionAtArrival) THEN
    ArrivalLock := FALSE;
END_IF;

DirectionChangeDelay(
    IN := (Direction <> 0) AND (Direction <> CommandedDirection) AND (ABS(SpeedRamp.Current) <= 0.1) AND (ABS(DriveActualFreqHz) <= 0.5),
    PT := Cfg.DirectionInterlockDelay
);

IF (CommandedDirection = 0) AND (Direction <> 0) THEN
    CommandedDirection := Direction;
    DirectionChangePending := FALSE;
ELSIF DirectionChangeDelay.Q THEN
    CommandedDirection := Direction;
    DirectionChangePending := FALSE;
ELSIF (Direction <> 0) AND (Direction <> CommandedDirection) THEN
    DirectionChangePending := TRUE;
ELSE
    DirectionChangePending := FALSE;
END_IF;

IF Direction = 0 THEN
    CommandedDirection := 0;
    DirectionChangePending := FALSE;
END_IF;
{endregion}

{region "§5 Consigne et rampe de vitesse"}
IF DirectionChangePending OR (Direction = 0) OR ArrivalLock OR SafeStop OR NOT StartStop THEN
    RampTargetPct := 0.0;
ELSE
    RampTargetPct := LIMIT(0.0, SpeedTgt_Pct, 100.0);
END_IF;

SpeedRamp(
    Target := RampTargetPct,
    AccelRate := Cfg.CfgRampAccelRate,
    DecelRate := SEL(SafeStop, Cfg.CfgRampDecelNormalRate, Cfg.CfgRampDecelFastRate),
    CycleTimeS := CycleTimeCalc.CycleTimeS
);
{endregion}

{region "§6 Commande variateur et frein"}
TonBrakeRealFreqTimeout(
    IN := (RampTargetPct <= 0.1) AND (ABS(SpeedRamp.Current) <= 0.1),
    PT := T#2S
);

MovementRequested := (ABS(SpeedRamp.Current) > 0.1)
                  OR ((ABS(DriveActualFreqHz) > 0.5) AND NOT TonBrakeRealFreqTimeout.Q);

Brake(
    Enable := Enable,
    Reset := Reset,
    MovementRequested := MovementRequested,
    ContactorFeedback := BrakeFeedback,
    BypassContactorCheck := BypassContactorCheck,
    DelayContactClose := Cfg.BrakeDelayContactClose,
    DelayMagnetise := Cfg.BrakeDelayMagnetise,
    DelayMotorDecel := Cfg.BrakeDelayMotorDecel,
    FeedbackTimeout := Cfg.BrakeFeedbackTimeout
);

BrakeReleaseRequest := Brake.BrakeCmd;
BrakeCommandOpenConfirmed := Brake.BrakeCommandOpenConfirmed;
BrakeContactorCheck := Brake.ContactorCheck;

IF InvertDriveDirection THEN
    PhysicalDriveDirection := -CommandedDirection;
ELSE
    PhysicalDriveDirection := CommandedDirection;
END_IF;

IF (PhysicalDriveDirection = 1) AND Brake.BrakeCmd THEN
    RequestedDriveControlWord := 1; // FWD
ELSIF (PhysicalDriveDirection = -1) AND Brake.BrakeCmd THEN
    RequestedDriveControlWord := 2; // REV
ELSE
    RequestedDriveControlWord := 0;
END_IF;

RequestedDriveFreqHz := (SpeedRamp.Current / 100.0) * Cfg.DriveFreqScaleMaxHz;

// Ralentissements d'approche
IF (CommandedDirection = 1) AND SlowdownSensorTremie THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedTremieHz);
ELSIF (CommandedDirection = -1) AND SlowdownSensorMaintenance THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedMaintenanceHz);
ELSIF (CommandedDirection = -1) AND SlowdownSensorP1 THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedP1Hz);
END_IF;

IF Fault.Error THEN
    RequestedDriveControlWord := 0;
    RequestedDriveFreqHz := 0.0;
    BrakeReleaseRequest := FALSE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
