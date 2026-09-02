(* ═══════════════════════════════════════════════════════════════
   ⚙️ FB_Translation — Directeur de l'axe transversal M3 (variateur AC600)
   ───────────────────────────────────────────────────────────────
   📄 Doc métier : DOC/AF/AF_Partie-11_Fonction_Translation_v2.3.md
   🔌 FB DE MOUVEMENT : porte RunRequest + SafeStop en plus de l'interface
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
    RunRequest                  : BOOL;        // --> [CMD] Demande de marche maintenue (FALSE = décélération/arrêt)
    SafeStop                    : BOOL;        // --> [SAFE] Sortie FB_Safety_Translation : TRUE = rampe décélération RAPIDE (Enable maintenu)
    ReqTremie                   : BOOL;        // --> [CMD] Demande explicite vers Trémie
    ReqMaintenance              : BOOL;        // --> [CMD] Demande explicite vers Maintenance
    SpeedTgt_Pct                : REAL;        // --> [CMD] Magnitude de la consigne (de 0 à 100%)
    PositionSensorTarget        : BOOL;        // --> [HW] Capteur position cible courante
    SlowdownSensorTremie        : BOOL;        // --> [HW] Capteur PV — ralentissement avant Trémie (Direction=1)
    SlowdownSensorMaintenance   : BOOL;        // --> [HW] Capteur P1 — ralentissement avant Maintenance (Direction=-1)
    SlowdownSensorP1            : BOOL;        // --> [HW] Capteur P2 — ralentissement avant P1 (Direction=-1)
    LimitSwitchTremie           : BOOL;        // --> [HW] Fin de course extrême Trémie (ex-LimitSwitchFwd)
    LimitSwitchMaintenance      : BOOL;        // --> [HW] Fin de course extrême Maintenance (ex-LimitSwitchRev)

    // 🛡️ Permis directionnels canoniques M3 — gate de sens (TRUE = autorisé)
    EffectivePermitM3_Tremie    : BOOL := FALSE;  // --> [SAFE] Permis effectif vers Trémie
    EffectivePermitM3_Maintenance : BOOL := FALSE; // --> [SAFE] Permis effectif vers Maintenance/P1

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
    CommandedTremie             : BOOL;           // . [LOC] Sens Trémie réellement appliqué
    CommandedMaintenance        : BOOL;           // . [LOC] Sens Maintenance réellement appliqué
    DirectionChangePending      : BOOL;         // . [LOC] Force la rampe à 0 pendant une inversion de sens en attente
    PhysicalTremie               : BOOL;         // . [LOC] Sens physique Trémie après inversion câblage
    PhysicalMaintenance          : BOOL;         // . [LOC] Sens physique Maintenance après inversion câblage
    RampTargetPct               : REAL;   // . [LOC] Cible rampe en %
    CaptorDebounceTon           : TON;    // . [LOC] Debounce capteur cible
    ArrivalEdge                 : R_TRIG;   // . [LOC] Front arrivée sur capteur
    ArrivalWasTremie             : BOOL;  // . [LOC] Sens d'arrivée mémorisé
    ArrivalWasMaintenance        : BOOL;  // . [LOC] Sens d'arrivée mémorisé
    ArrivalLock                 : BOOL;        // . [LOC] Arrêt exact sur capteur cible
    MovementRequested           : BOOL;         // . [LOC] Pilote FB_Brake
    FirstScanDone               : BOOL;   // . [LOC] Initialisation premier scan
    TonBrakeRealFreqTimeout     : TON;
    EffectiveSafeStop           : BOOL;   // . [LOC] SafeStop effectif = SafeStop OR sens non permis (gate de sens)

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

IF NOT BypassLimitSwitch AND ((CommandedTremie AND LimitSwitchTremie) OR (CommandedMaintenance AND LimitSwitchMaintenance)) THEN
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
    CommandedTremie := FALSE;
    CommandedMaintenance := FALSE;
    DirectionChangePending := FALSE;
    ArrivalLock := FALSE;
    ArrivalWasTremie := FALSE;
    ArrivalWasMaintenance := FALSE;
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
    CommandedTremie := FALSE;
    CommandedMaintenance := FALSE;
END_IF;

CycleTimeCalc();
{endregion}

{region "§4 Arrivée sur cible et interlock direction"}
CaptorDebounceTon(IN := PositionSensorTarget, PT := Cfg.CaptorDebounce);
TargetReached := CaptorDebounceTon.Q;
ArrivalEdge(CLK := TargetReached);

IF ArrivalEdge.Q THEN
    ArrivalLock := TRUE;
    ArrivalWasTremie := CommandedTremie;
    ArrivalWasMaintenance := CommandedMaintenance;
END_IF;

IF ArrivalLock AND ((ReqTremie AND NOT ArrivalWasTremie) OR (ReqMaintenance AND NOT ArrivalWasMaintenance)) THEN
    ArrivalLock := FALSE;
END_IF;

DirectionChangeDelay(
    IN := (ReqTremie OR ReqMaintenance)
          AND ((ReqTremie AND NOT CommandedTremie) OR (ReqMaintenance AND NOT CommandedMaintenance))
          AND (ABS(SpeedRamp.Current) <= 0.1)
          AND (ABS(DriveActualFreqHz) <= 0.5),
    PT := Cfg.DirectionInterlockDelay
);

IF NOT (CommandedTremie OR CommandedMaintenance) AND (ReqTremie OR ReqMaintenance) THEN
    CommandedTremie := ReqTremie;
    CommandedMaintenance := ReqMaintenance;
    DirectionChangePending := FALSE;
ELSIF DirectionChangeDelay.Q THEN
    CommandedTremie := ReqTremie;
    CommandedMaintenance := ReqMaintenance;
    DirectionChangePending := FALSE;
ELSIF (ReqTremie OR ReqMaintenance)
      AND ((ReqTremie AND NOT CommandedTremie) OR (ReqMaintenance AND NOT CommandedMaintenance)) THEN
    DirectionChangePending := TRUE;
ELSE
    DirectionChangePending := FALSE;
END_IF;

IF NOT (ReqTremie OR ReqMaintenance) THEN
    CommandedTremie := FALSE;
    CommandedMaintenance := FALSE;
    DirectionChangePending := FALSE;
END_IF;
{endregion}

{region "§4bis Permis directionnels et EffectiveSafeStop"}
// 🛡️ 4bis. GATE DE SENS (permis directionnels SAFETY) — modèle treuils FB_Winch
// RampStopActive = SafeStop OR demande vers un sens non permis. Bloque la RAMPE
// (arrêt réel) vers un sens non autorisé sans fabriquer de sens numérique.
// Consommé dans la gate de rampe (§5) et le choix de décélération.
// Le permis Maintenance représente la possibilité de rejoindre P1/maintenance physique ;
// l'interdiction d'accès à la zone Maintenance est gérée séparément par la cible P1 et sa
// coupure dure, sans couper le déplacement légal jusqu'à P1.
EffectiveSafeStop := SafeStop
                      OR (ReqTremie AND NOT EffectivePermitM3_Tremie)
                      OR (ReqMaintenance AND NOT EffectivePermitM3_Maintenance)
                      OR (ReqTremie AND ReqMaintenance);
{endregion}

{region "§5 Consigne et rampe de vitesse"}
IF DirectionChangePending OR NOT (ReqTremie OR ReqMaintenance) OR ArrivalLock OR EffectiveSafeStop OR NOT RunRequest THEN
    RampTargetPct := 0.0;
ELSE
    RampTargetPct := LIMIT(0.0, SpeedTgt_Pct, 100.0);
END_IF;

SpeedRamp(
    Target := RampTargetPct,
    AccelRate := Cfg.CfgRampAccelRate,
    DecelRate := SEL(EffectiveSafeStop, Cfg.CfgRampDecelNormalRate, Cfg.CfgRampDecelFastRate),
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

PhysicalTremie := CommandedTremie;
PhysicalMaintenance := CommandedMaintenance;
IF InvertDriveDirection THEN
    PhysicalTremie := CommandedMaintenance;
    PhysicalMaintenance := CommandedTremie;
END_IF;

IF PhysicalTremie AND Brake.BrakeCmd THEN
    RequestedDriveControlWord := 1; // FWD
ELSIF PhysicalMaintenance AND Brake.BrakeCmd THEN
    RequestedDriveControlWord := 2; // REV
ELSE
    RequestedDriveControlWord := 0;
END_IF;

RequestedDriveFreqHz := (SpeedRamp.Current / 100.0) * Cfg.DriveFreqScaleMaxHz;

// Ralentissements d'approche
IF CommandedTremie AND SlowdownSensorTremie THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedTremieHz);
ELSIF CommandedMaintenance AND SlowdownSensorMaintenance THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedMaintenanceHz);
ELSIF CommandedMaintenance AND SlowdownSensorP1 THEN
    RequestedDriveFreqHz := MIN(RequestedDriveFreqHz, Cfg.ApproachSpeedP1Hz);
END_IF;

IF Fault.Error THEN
    RequestedDriveControlWord := 0;
    RequestedDriveFreqHz := 0.0;
    BrakeReleaseRequest := FALSE;
END_IF;
{endregion}

END_FUNCTION_BLOCK
